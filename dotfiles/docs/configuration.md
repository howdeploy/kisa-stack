# Configure the desktop

Edit the **installed copy** under `$XDG_CONFIG_HOME` (default `~/.config`). The
repository is the publication source, not a live config symlink. Keep personal
integration settings outside the checkout.

## Keys and window management

Bindings live in `shojiwm/src/index.tsx`; behavior lives in `src/window-manager.ts`.

| Key | Action |
| --- | --- |
| `Super+Return` | Ghostty |
| `Super+Space` | Walker |
| `Super+E` | Dolphin |
| `Super+I` | System settings on the output under the pointer |
| `Super+L` | Lock the session |
| `Super+W` | Wallpaper and widget preset picker |
| `Super+Shift+S` | Frozen-frame picker: Flameshot, active window or OCR |
| `Super+MouseForward` | Screenshot editor on the current monitor; requires the pinned compositor's side-button support |
| `Super+Q` | Close focused window |
| `Super+S` | Toggle tiling for the current workspace |
| `Super+F` | Fullscreen with client chrome |
| `Super+M` | Maximize/restore |
| `Super+Left/Right` | Focus previous/next window |
| `Super+Shift+Left/Right` | Reorder windows |
| `Super+Shift+Right mouse button` | Resize a window; in tiling, move shared boundaries |
| `Super+Ctrl+Up/Down` | Switch workspace |
| `Super+Shift+R` | Reload compositor configuration |
| `Super+Shift+Q` | End compositor session (save your work first) |

Keyboard layouts are `us,ru`, toggled with Alt+Shift. Change the input configuration
for your languages and pointer/trackpad preferences. The public setup does not
autostart a VPN or reference the author's application profiles.

Drag an internal tiled window edge to redistribute width between neighbours in
the same row, or height between adjacent rows. Corner drags adjust both axes.
Client size limits constrain the split. Proportions survive a config reload;
incompatible row/column weights reset when the grid shape changes.

Moving a tile to a floating workspace restores its previous floating size. Without
a valid saved size, it uses 60% of the target viewport width and 70% of its height,
bounded by the output and client constraints. On close, neighbours reflow alongside
the dissolving window over 700 ms with smooth acceleration and deceleration.

Focusing another ordinary window on the same workspace exits the previous fullscreen.
Dialogs, PiP, pinned windows and MateEngine keep their above-fullscreen behaviour.
An independent fullscreen on another output is preserved. Switching floating/tiling
also exits fullscreen before applying the new layout; minimized windows stay hidden.

## Monitors, wallpaper and presets

The compositor discovers connected outputs, extends them automatically, chooses
their best mode and uses scale 1. `Super+I` opens monitor, keyboard, pointer,
audio, connection, wallpaper and lock settings. Monitor changes require confirmation
within 20 seconds or revert. Defaults and validation live in `src/system-settings.ts`;
the shell saves settings in private `shoji-shell/system-settings.json`.
The shell defaults to the first available output for
the panel and desktop controls. Set `SHOJI_PRIMARY_OUTPUT` in the installed
`shoji-shell/integrations.env` to select a specific output.

The wallpaper library defaults to `~/Pictures/Wallpapers`; `SHOJI_WALLPAPERS` can
override it. Your wallpaper collection is not part of this repository. A neutral
SVG is used when no wallpaper has been selected. The picker reads common raster
image formats and uses Pillow to cache thumbnails.

`Super+W` applies **both** the selected wallpaper and the selected widget preset,
regardless of which row currently has keyboard focus. Preset cards include small
layout previews; disabled integrations are filtered out. State is written to the
installed `shoji-shell/wallpapers.json`, not to the repository.

| Preset | Widget set and position (when integrations are enabled) |
| --- | --- |
| Empty / Без виджетов | No widgets; first in the picker and first-run default |
| Home Zone | Animated clock mascots, calendar, local system profile and account tiles behind the existing opt-in flags |
| Gaming Home Zone | Home dashboard and game/process telemetry on the rightmost output |
| Voice input / Ввод и голос | Voice service indicators and dictation-mode controls, gated by `SHOJI_ENABLE_VOICE=1` |
| Default / Текущая раскладка | Limits top-left, sessions mid-left, Vast bottom-left, GitHub top-right, Hermes top-center, music and Neko bottom-right |
| Bottom HUD / Hermes снизу | Hermes above the dock with chats opening upward; limits bottom-right with music above; GitHub top-right; sessions bottom-left; no Vast or Neko |

These are different widget **sets**, not only different coordinates. Placement is
defined in `WidgetLayouts.qml`. Changes animate through the wallpaper transition
and `WidgetWaveLoader`; a moving widget keeps an outgoing snapshot while its new
position appears. Preserve this lifecycle when adding presets.

The optional weather panel is separate from the preset widget maps and is hidden
for the empty preset. It requires two user-configured locations.

Recognized Steam, Minecraft and OpenMW game windows initially use the leftmost
output; edit `shojiwm/src/game-placement.ts` to change this policy or add other
app IDs. Minecraft fullscreen reserves 80 logical pixels for the dock.

## Notifications

Settings → Notifications stores the common receive switch and per-application
exceptions in local `shoji-shell/notification-policy.json`. Disabling reception
blocks new notification cards/history; explicit exceptions still pass. The patched
server reports caller-specific `Inhibited` for clients that respect system DND.
In-app sounds/overlays outside that protocol retain their application settings.
The compositor also filters known standalone Steam notification windows.
See [the required Quickshell build](notifications.md). The policy file is ignored,
excluded from publication and preserved by the installer.

## Lock screen

`Super+L` uses Quickshell's Wayland session lock and PAM service `login` for the
current user. Lock settings include a preview, per-output wallpaper, an idle-lock
timer (10 minutes by default) and screen-power timeout while locked (5 minutes).
Automatic locking requires the fork's DPMS API; manual locking remains available.
The preview uses a separate mock controller and does not authenticate.

The optional native lock-scene integration draws the current animated wallpaper
and MateEngine's enabled Big Screen screensaver underneath the password UI.
After PAM success, a 680ms wave replaces the captured lock scene with the live
desktop on available outputs. It requires the pinned compositor with its generic
lock API and, for MateEngine, the [matching bridge rebuild](mateengine.md);
it is not enabled by copying QML alone. See
[lock-scene integration and rollout limits](lock-scene.md).

The public copy has not been exercised for password authentication, unlock or
DPMS recovery. PAM policies differ between distributions; keep an independent
working session available for the first deliberate lock/unlock check.

Live wallpapers require a separate engine and locally owned content; see
[wallpaper engine patches](wallpaper-engine.md). The helper's private-library
lookup does not build or install those libraries automatically.

## Appearance and icons

`shoji-shell/Theme.qml` owns the Mocha palette, mauve accent and Noto Sans UI font.
Walker has a matching CSS palette and the same fixed grain tile. The public Ghostty
configuration uses `monospace`; select an installed font there if desired. The
cursor uses `XCURSOR_THEME` or Adwaita; personal cursor assets are not bundled.

The `Shoji` icon theme inherits Papirus Dark. Add custom flat SVG app icons under
`$XDG_DATA_HOME/icons/Shoji/scalable/apps/`, named for the application's `Icon=` value.
Only the theme index is supplied; no installed application desktop files are copied.
The default dock pins Ghostty and Dolphin. Missing desktop entries are hidden.
Add optional app IDs locally after installing those applications; the reference
software inventory is in [dependencies](../dependencies/README.md).
Lucide remains the separate monochrome set for system controls.

Quickshell chooses Shoji via its pragma. For GTK/Walker, select Shoji in your theme
settings, or merge `gtk-icon-theme-name=Shoji` into the `[Settings]` section of your
GTK settings files. On a desktop using GNOME interface settings:

```bash
gsettings set org.gnome.desktop.interface icon-theme Shoji
```

If an already-running shell retains missing-icon textures after installing a theme,
restart that shell when convenient. The dock maps GSR's `gsr-ui` app ID to its
`gpu-screen-recorder` desktop entry. Other apps use native desktop-entry lookup.

## Launcher, terminal and optional tools

Walker favorites live in `walker/favorites.toml`. Each item has `label`, optional
`icon`, and exactly one of `desktop` or `command`. `terminal=true` runs a command in
Ghostty through interactive Bash. Commands are trusted local code; do not paste
credentials into them. Favorites are rows with explicit application/script tags,
slightly stronger tints than ordinary results, and no hover tooltips.

Safe defaults include Terminal and Files. Commented examples cover Telegram,
Brave and `codex-resume-ghostty`; install the corresponding applications first.
The author's Bluetooth recovery alias is not shipped because its exact device
and privileged recovery actions are machine-specific.

Ghostty's config retains the Mocha styling and physical-key EN/RU shortcuts. It
expects zsh; change `command` and `shell-integration` together for another shell.
The screenshot helpers need Flameshot, grim, Qt's `qtdiag6` and the portal setup.
`Super+Shift+S` captures one cursor-free monitor frame before the picker takes focus,
preserving open application menus. The frame stays behind the external selector
until Flameshot maps its editor or the selected capture command exits. Escape or an
outside click cancels the picker; arrows/Tab and Enter choose an action.
The window action saves the visible desktop crop at the active window's bounds;
menus extending beyond those bounds require region selection instead.
OCR uses slurp, Pillow, Tesseract and the installed `rus`/`eng` language data, then
copies text locally with wl-copy. It does not upload the image or save a temporary PNG.
`Super+MouseForward` still opens Flameshot directly.
Brightness uses DDC/CI and `ddcutil`; grant access through your distribution's
normal device rules if needed. It does not silently change permissions.

## Known interaction issue: GPU Screen Recorder

The fullscreen GSR overlay can hold X11 pointer/keyboard grabs while still open
under this compositor. Authme's contents recovered when the recorder was terminated;
changing Authme's rendering flags had not helped. Hide the overlay when returning
to applications. If input remains captured, finish recording and exit the recorder.
No Authme workaround or recorder autostart is installed by this bundle.
