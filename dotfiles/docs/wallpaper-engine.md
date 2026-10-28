# Private animated wallpaper engine

Static wallpapers work without an external engine. Animated scenes/videos need
the installing user's own Wallpaper Engine assets and Workshop content. The
source build below supplies the renderer; it does not download Steam content.

## Pinned sources

`sources.json` records the engine base, mpv and NVIDIA codec-header revisions.
The engine media patch is exported from
[PR #711 revision afeb74d](https://github.com/Almamu/linux-wallpaperengine/commit/afeb74d8005549681c8543d2c25bde1916907135).
It includes asynchronous D-Bus requests, a 250 ms application deadline, bounded
dispatch, metadata retries and failed-player cooldown, plus regression cases.

| Patch | Purpose |
| --- | --- |
| `engine-media-memory.patch` | Actual polling intervals, resource cleanup and the asynchronous recovery path above |
| `existing-crop-upscale.patch` | Shell crop/zoom and bounded bicubic upscaling before slicing multi-output spans |
| `mpv-opengl-fence.patch` | Prevent undrained swapchain fences when the libmpv render API has no swap-buffers callback |

The mpv fix is already upstream in mpv-player/mpv#17303. It is retained here
because the reproducible source recipe uses the earlier pinned mpv revision.
Do not apply it again to a moving upstream checkout.

## Build, review, install

Install the core dependencies and the additional
[`arch-wallpaper.txt`](../dependencies/arch-wallpaper.txt) profile first.
For Arch/Manjaro, from the repository root:

```bash
grep -v '^#' dotfiles/dependencies/arch-wallpaper.txt | xargs sudo pacman -S --needed
./dotfiles/scripts/build-wallpaper-engine.sh
```

The script reads pins from `sources.json`, builds pinned codec headers into its
work directory, builds private mpv, applies the two engine patches, and builds
the full engine executable and CEF resources. CEF is downloaded by upstream's
CMake configuration. Default build parallelism is two; override it with a
positive `CMAKE_BUILD_PARALLEL_LEVEL` if needed. Native build libraries and disk
space for CEF are required. Hardware decoding still depends on the user's GPU
driver and FFmpeg capabilities.

The result is a bundle under an ignored `dotfiles/.build/wallpaper-engine.*/`
directory. The script prints the exact install command:

```bash
python3 dotfiles/scripts/install.py --component wallpaper-engine \
  --wallpaper-bundle /absolute/path/printed/by/the/build/bundle --apply
```

Omit `--apply` to preview. Installation verifies the expected artifacts and
source pins before moving existing files. It copies the complete runtime to
`${XDG_DATA_HOME:-$HOME/.local/share}/shoji-shell/wallpaper-engine/runtime`
and private mpv to the sibling `lib/`. Existing engine directories are backed
up using the same private manifest mechanism as desktop configs. Sources remain
in the build checkout. No system library, running engine or session is replaced.

## Launch and fallback

The published `live-wallpaper.py` starts the private executable directly with
its own runtime as working directory and its private library paths. This avoids
distribution shell wrappers that prepend a system engine library ahead of our
patched library. Other desktop applications keep their normal system mpv.

If no private executable exists, a separately installed `linux-wallpaperengine`
remains a compatibility fallback. Its version and patches are outside this
bundle; the helper records that fallback in its local log. Use the private build
for the reference patched behavior. A partial private runtime is rejected,
rather than silently replaced with a stock engine.

Install the desktop configs separately, then deliberately select your own live
wallpaper with Super+W. A renderer failure is reported by the helper; static
wallpapers and the neutral background remain available. Backups can be restored
using their manifest from another working session after stopping the renderer.

## Validation boundary

The earlier synchronous repair had a local build, 32 mpv tests, an ASan D-Bus
harness and NVIDIA/NVDEC 4K playback observations. Those results do **not**
validate the subsequent asynchronous revision or this new bundle builder.

The current source recipe, installer changes and launch-path regression tests
have not been built or run. A clean-machine build, deliberate playback and memory
observation remain outstanding. Optional checks after prerequisites are ready:

```bash
python3 dotfiles/scripts/test-live-wallpaper.py
python3 dotfiles/scripts/check-install.py
# In a separately configured engine BUILD_TESTING build:
dbus-run-session -- env LWE_TEST_PRIVATE_BUS=1 ./build/tests "[dbus-media]"
```

Retain upstream licenses when sharing modified source or binaries; see
[NOTICE](../NOTICE.md). These dotfiles distribute source patches, not renderer,
CEF, mpv or Steam binaries.
