# Installation

## Prerequisites

Use a working Linux Wayland/DRM system with a login manager, systemd user services,
PipeWire, NetworkManager and BlueZ. The reference environment is recorded in
[`sources.json`](../sources.json). Quickshell **0.3.1** modules, including
`Quickshell.WindowManager` and `Quickshell.Services.Pam`, are required; an older
distribution package may not work. Native animated icons use Qt 6.10+ Shapes
path trimming. The lock controller uses the distribution's PAM service `login`.
Qt Shader Tools must match the Qt runtime closely enough to produce usable `.qsb` files.

The reference dependency list is [`dependencies/arch.txt`](../dependencies/arch.txt).
Review it before installing; it includes optional tools used by panel buttons.
The [software inventory](../dependencies/README.md) separates core dependencies,
wallpaper build dependencies, optional account adapters and the author's recorded
repository/foreign/Flatpak applications. Reference inventories are not install scripts.
On Arch/Manjaro, after updating your system normally:

```bash
git clone https://github.com/howdeploy/kisa-stack.git
cd kisa-stack
grep -v '^#' dotfiles/dependencies/arch.txt | xargs sudo pacman -S --needed
rustup toolchain install 1.94.0
```

Do not use a partial system upgrade to obtain individual Qt libraries. Distribution
package availability can differ. This installer does not configure GPU drivers,
change permissions on input devices, or replace your display manager.

Install [Elephant](https://github.com/abenz1267/elephant) and its `desktopapplications`,
`files` and `providerlist` providers separately. The reference AUR packages are
`elephant-bin`, `elephant-desktopapplications-bin`, `elephant-files-bin` and
`elephant-providerlist-bin`, version 2.22.1. Review those packages and use your
normal AUR installation method. Ensure its
`elephant.service` user unit exists. Stock Walker can coexist with `walker-shoji`,
but cannot drive the extra controls in this theme.

For other distributions, use the fork's
[installation prerequisites](https://github.com/howdeploy/ShojiWM/blob/2c767129e5a900310b4d53df9f5952a30f6b5953/docs/docs/getting-started/installation.md)
and the package list as a capability checklist. Install native development headers,
GTK4/layer-shell, Poppler GLib and Protocol Buffers for Walker. Do not expect the
Arch package names or KDE polkit executable path to be universal.

## 1. Build and install the compositor fork

From the `kisa-stack` repository root:

```bash
./dotfiles/scripts/build-shojiwm.sh
```

This clones the public integration branch into an ignored `.build/` directory,
checks out the exact revision and runs a locked Rust build. It prints the next
command; inspect the pinned fork's `dist/install.sh`, then run that command:

```bash
# In the checkout printed by the build script:
./dist/install.sh --no-build --no-config
```

The upstream installer requests sudo, installs system binaries/runtime under `/usr`,
the Wayland session entry and the ShojiWM portal. It replaces an existing system
ShojiWM installation. `--no-config` keeps this separate from your user dotfiles.
Do not run the user installer below with sudo.

## 2. Build the launcher and Qt shaders

```bash
# Back in the kisa-stack root:
./dotfiles/scripts/build-walker.sh
./dotfiles/scripts/build-shaders.sh
```

Walker is fetched at an exact revision, patched, built with `--locked`, then installed
as `~/.local/bin/walker-shoji`. An existing binary is backed up. The retained checkout
contains the complete modified GPL source; the patch is in `patches/walker/`.
The script does not change a system Walker binary or start a GUI.

The shader script compiles every `.frag` into a matching `.frag.qsb` beside its source.
These generated files are ignored by Git but copied during installation. The
compositor's `src/effect/*.frag` files are compiled by ShojiWM at runtime and must
**not** be passed to `qsb`. If needed, set `QSB=/path/to/qt6/bin/qsb`.

## 3. Build the animated wallpaper runtime, if wanted

For animated wallpapers, install the additional dependencies and build the
complete private engine, CEF resources and patched mpv:

```bash
grep -v '^#' dotfiles/dependencies/arch-wallpaper.txt | xargs sudo pacman -S --needed
./dotfiles/scripts/build-wallpaper-engine.sh
```

Review the result and run the exact `install.py --component wallpaper-engine
--wallpaper-bundle ... --apply` command it prints. This uses user-private paths
and backs up an existing engine directory; it installs no system engine package
and restarts nothing. See [wallpaper build details](wallpaper-engine.md).
Static-only installations can skip this step.

MateEngine's optional lock screensaver also needs the matching application
bridge; see [its pinned source setup](mateengine.md).

## 4. Preview and install user files

```bash
python3 dotfiles/scripts/install.py
python3 dotfiles/scripts/install.py --apply
```

Without `--apply`, no files are written. Use repeated `--component` options to select
only parts (`shojiwm`, `shoji-shell`, `walker`, `elephant`, `ghostty`, `portals`, `icons`,
`bin`). The complete appearance requires the complete stack.
The private engine is a separate `wallpaper-engine` component requiring
`--wallpaper-bundle`; it is not included in the default config copy.

Before moving existing configs, installation checks required commands, Python
NumPy/Pillow, compiled Qt shaders and the installed SDK's generic lock API.
This catches missing setup steps, not every possible runtime/driver mismatch.
The installer does not install dependency packages or authenticate any CLI.

Targets follow `XDG_CONFIG_HOME`, `XDG_DATA_HOME` and `XDG_STATE_HOME`; binaries use
`~/.local/bin`. Add that directory to your session PATH. The installer copies files;
it does not symlink your live configs into the checkout. It creates the required
`shojiwm/node_modules/shoji_wm` runtime link and renders the home-specific Elephant
and Ghostty paths only in the installed copies.

Existing component directories are moved to a private backup beneath
`$XDG_STATE_HOME/kisa-dotfiles/backups/` (default `~/.local/state`). The printed
`manifest.json` maps every target to its backup. Upgrades preserve an existing
shell `integrations.env`, `wallpapers.json` and `system-settings.json`; review
those local files yourself.
Other local component changes remain in the backup, not merged into the new copy.

For an isolated staging installation, use `--target-home /absolute/temporary/directory`.
That option ignores XDG overrides, but still requires the compositor runtime to
exist when installing the `shojiwm` component. It does not log into that staged desktop.

## 5. Start the desktop

Save your work and select **ShojiWM** in your login manager. No session reload,
service restart or logout is triggered by the dotfiles installer.

`Super+Return` opens Ghostty; `Super+Space` opens Walker; `Super+W` opens the wallpaper
and layout picker. Put your own pictures in `~/Pictures/Wallpapers`. Configure the
primary output and optional widgets as described in [configuration](configuration.md)
and [widgets](widgets.md).

`Super+I` opens system settings and `Super+L` locks the session. Review the
[lock-screen limitations](configuration.md#lock-screen) before the first lock.
Live wallpapers use the private runtime from step 3 when present. Without it,
an independently installed system engine is only a compatibility fallback and
is not guaranteed to include these fixes. No precompiled engine binary is shipped.

The session refreshes D-Bus activation variables and restarts portal services so
applications do not inherit a previous desktop's display. Polkit uses the Arch KDE
agent path in `src/index.tsx`; adapt it if using another distribution. Wi-Fi secrets
require your own NetworkManager secret agent (for example KDE's networkmanagement
module or nm-applet). No previous KWallet configuration or saved network is installed.

## Restore or remove

From another working desktop or TTY, stop using ShojiWM before replacing its live
configuration. Read the install's `manifest.json`; move the new target somewhere
safe, then move its numbered backup back to the recorded target. A `null` backup
means that target did not exist before this install. Keep the manifest and backups
until satisfied. No automatic removal command deletes your current configuration.

Restoring user files does not downgrade system ShojiWM or undo dependency packages.
Keep your previous system package if you need that rollback; the fork's system
installer and your package manager own those files.
