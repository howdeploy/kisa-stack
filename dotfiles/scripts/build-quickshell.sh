#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
for tool in git python3 cmake ninja pkg-config; do
    command -v "$tool" >/dev/null || { echo "Missing build tool: $tool. See docs/notifications.md." >&2; exit 1; }
done
jobs="${CMAKE_BUILD_PARALLEL_LEVEL:-2}"
[[ "$jobs" =~ ^[1-9][0-9]*$ ]] || { echo 'CMAKE_BUILD_PARALLEL_LEVEL must be a positive integer.' >&2; exit 1; }
pin() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["quickshell"][sys.argv[2]])' "$root/sources.json" "$1"; }
mkdir -p "$root/.build"
work="$(mktemp -d "$root/.build/quickshell.XXXXXX")"
prefix="${XDG_DATA_HOME:-$HOME/.local/share}/shoji-shell/quickshell"
git clone "$(pin repository)" "$work/source"
git -C "$work/source" checkout --detach "$(pin revision)"
git -C "$work/source" apply "$root/$(pin patch)"
cmake -S "$work/source" -B "$work/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DCRASH_HANDLER=OFF \
    -DDISTRIBUTOR=KISA-Stack -DCRASHREPORT_URL=https://github.com/howdeploy/kisa-stack/issues/new \
    -DINSTALL_QML_PREFIX=lib/qt6/qml -DCMAKE_INSTALL_PREFIX="$prefix"
cmake --build "$work/build" --parallel "$jobs"
echo 'Patched Quickshell built; no installed files or running services were changed.'
echo 'Review and install into your private user prefix, then install the desktop config:'
printf 'cmake --install %q\n' "$work/build"
