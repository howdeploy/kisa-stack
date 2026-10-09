# Installation

## Prerequisites

Use a working Linux Wayland/DRM system with a login manager, systemd user services,
PipeWire, NetworkManager and BlueZ. The reference environment is recorded in
[`sources.json`](../sources.json). Quickshell **0.3.1** modules, including
`Quickshell.WindowManager`, are required; an older distribution package may not work.
Qt Shader Tools must match the Qt runtime closely enough to produce usable `.qsb` files.

The reference dependency list is [`dependencies/arch.txt`](../dependencies/arch.txt).
Review it before installing; it includes optional tools used by panel buttons.
On Arch/Manjaro, after updating your system normally:

```bash
git clone https://github.com/tab11pm/tab-stack.git
cd tab-stack
grep -v '^#' dotfiles/dependencies/arch.txt | xargs sudo pacman -S --needed
rustup toolchain install 1.94.0
```

Do not use a partial system upgrade to obtain individual Qt libraries. Distribution
package availability can differ. This installer does not configure GPU drivers,
change permissions on input devices, or replace your display manager.

Install [Elephant](https://github.com/abenz1267/elephant) and its `desktopapplications`,
`files` and `providerlist` providers separately (reference version 2.22.1; the
`elephant-bin` AUR package was used in the reference environment). Ensure its
`elephant.service` user unit exists. Stock Walker can coexist with `walker-shoji`,
but cannot drive the extra controls in this theme.

For other distributions, use the fork's
[installation prerequisites](https://github.com/howdeploy/ShojiWM/blob/2c767129e5a900310b4d53df9f5952a30f6b5953/docs/docs/getting-started/installation.md)
and the package list as a capability checklist. Install native development headers,
GTK4/layer-shell, Poppler GLib and Protocol Buffers for Walker. Do not expect the
Arch package names or KDE polkit executable path to be universal.

## 1. Build and install the compositor fork

From the `tab-stack` repository root:

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
# Back in the tab-stack root:
./dotfiles/scripts/build-walker.sh
./dotfiles/scripts/build-shaders.sh
```

Walker is fetched at an exact revision, patched, built with `--locked`, then installed
as `~/.local/bin/walker-shoji`. An existing binary is backed up. The retained checkout
contains the complete modified GPL source; the patch is in `patches/walker/`.
The script does not change a system Walker binary or start a GUI.

The shader script writes three `.frag.qsb` files beside the QML shader sources.
These generated files are ignored by Git but copied during installation. The
compositor's `src/effect/*.frag` files are compiled by ShojiWM at runtime and must
**not** be passed to `qsb`. If needed, set `QSB=/path/to/qt6/bin/qsb`.

## 3. Preview and install user files

```bash
python3 dotfiles/scripts/install.py
python3 dotfiles/scripts/install.py --apply
```

Without `--apply`, no files are written. Use repeated `--component` options to select
only parts (`shojiwm`, `shoji-shell`, `walker`, `elephant`, `ghostty`, `portals`, `icons`,
`bin`). The complete appearance requires the complete stack.

Targets follow `XDG_CONFIG_HOME`, `XDG_DATA_HOME` and `XDG_STATE_HOME`; binaries use
`~/.local/bin`. Add that directory to your session PATH. The installer copies files;
it does not symlink your live configs into the checkout. It creates the required
`shojiwm/node_modules/shoji_wm` runtime link and renders the home-specific Elephant
and Ghostty paths only in the installed copies.

Existing component directories are moved to a private backup beneath
`$XDG_STATE_HOME/tab-stack/backups/` (default `~/.local/state`). Existing backups
from the original installer remain in its previous directory. The printed
`manifest.json` maps every target to its backup. Upgrades preserve an existing
shell `integrations.env` and `wallpapers.json`; review those local files yourself.
Other local component changes remain in the backup, not merged into the new copy.

For an isolated staging installation, use `--target-home /absolute/temporary/directory`.
That option ignores XDG overrides, but still requires the compositor runtime to
exist when installing the `shojiwm` component. It does not log into that staged desktop.

## 4. Start the desktop

Save your work and select **ShojiWM** in your login manager. No session reload,
service restart or logout is triggered by the dotfiles installer.

`Super+Return` opens Ghostty; `Super+Space` opens Walker; `Super+W` opens the wallpaper
and layout picker. Put your own pictures in `~/Pictures/Wallpapers`. Configure the
primary output and optional widgets as described in [configuration](configuration.md)
and [widgets](widgets.md).

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
