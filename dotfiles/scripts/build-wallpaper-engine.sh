#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
for tool in git python3 make meson ninja cmake pkg-config patchelf; do
    command -v "$tool" >/dev/null || { echo "Missing build tool: $tool. See dependencies/arch-wallpaper.txt." >&2; exit 1; }
done
jobs="${CMAKE_BUILD_PARALLEL_LEVEL:-2}"
[[ "$jobs" =~ ^[1-9][0-9]*$ ]] || { echo 'CMAKE_BUILD_PARALLEL_LEVEL must be a positive integer.' >&2; exit 1; }
pin() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["wallpaper_engine"][sys.argv[2]])' "$root/sources.json" "$1"; }
mkdir -p "$root/.build"
work="$(mktemp -d "$root/.build/wallpaper-engine.XXXXXX")"
clone() {
    git clone "$1" "$2"
    git -C "$2" checkout --detach "$3"
}
clone "$(pin nvcodec_headers_repository)" "$work/headers" "$(pin nvcodec_headers_revision)"
make -C "$work/headers" PREFIX="$work/headers-install" install
export PKG_CONFIG_PATH="$work/headers-install/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
clone "$(pin mpv_repository)" "$work/mpv" "$(pin mpv_revision)"
git -C "$work/mpv" apply "$root/patches/wallpaper-engine/mpv-opengl-fence.patch"
meson setup "$work/mpv/build" "$work/mpv" --prefix="$work/mpv-install" --libdir=lib \
    --buildtype=release -Dlibmpv=true -Dcplayer=false -Dtests=false
meson compile -C "$work/mpv/build" -j "$jobs"
meson install -C "$work/mpv/build" --no-rebuild

clone "$(pin repository)" "$work/engine" "$(pin revision)"
git -C "$work/engine" submodule update --init --recursive
git -C "$work/engine" apply "$root/patches/wallpaper-engine/existing-crop-upscale.patch"
git -C "$work/engine" apply "$root/patches/wallpaper-engine/engine-media-memory.patch"
export PKG_CONFIG_PATH="$work/mpv-install/lib/pkgconfig:$PKG_CONFIG_PATH"
cmake -S "$work/engine" -B "$work/engine/build" -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF \
    -DMPV_LIBRARY_mpv="$work/mpv-install/lib/libmpv.so" -DMPV_INCLUDE_DIR="$work/mpv-install/include"
# Installation also includes dependency tools, so build the complete installable set.
cmake --build "$work/engine/build" --parallel "$jobs"

bundle="$work/bundle"
mkdir -p "$bundle/lib"
cmake --install "$work/engine/build" --prefix "$bundle/runtime"
install -m755 "$(readlink -f "$work/mpv-install/lib/libmpv.so.2")" "$bundle/lib/libmpv.so.2"
# Remove build-tree paths; the helper also supplies this private runtime's library path.
patchelf --set-rpath '$ORIGIN' "$bundle/runtime/linux-wallpaperengine"
patchelf --set-rpath '$ORIGIN:$ORIGIN/../lib' "$bundle/runtime/liblinux-wallpaperengine-lib.so"
patchelf --remove-rpath "$bundle/lib/libmpv.so.2"
for file in runtime/linux-wallpaperengine runtime/liblinux-wallpaperengine-lib.so runtime/libcef.so lib/libmpv.so.2; do
    [[ -s "$bundle/$file" ]] || { echo "Incomplete build: $file" >&2; exit 1; }
done
cp "$root/sources.json" "$bundle/sources.json"
(cd "$root" && sha256sum patches/wallpaper-engine/*.patch) > "$bundle/patches.sha256"
echo "Private runtime built in $bundle; sources retained in $work"
echo 'No system libraries or running wallpapers were changed. Review, then install:'
printf 'python3 %q --component wallpaper-engine --wallpaper-bundle %q --apply\n' "$root/scripts/install.py" "$bundle"
