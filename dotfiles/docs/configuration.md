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
| `Super+W` | Wallpaper and widget preset picker |
| `Super+Shift+S` | Screenshot editor on the current monitor |
| `Super+Q` | Close focused window |
| `Super+S` | Toggle tiling for the current workspace |
| `Super+F` | Fullscreen with client chrome |
| `Super+M` | Maximize/restore |
| `Super+Left/Right` | Focus previous/next window |
| `Super+Shift+Left/Right` | Reorder windows |
| `Super+Ctrl+Up/Down` | Switch workspace |
| `Super+Shift+R` | Reload compositor configuration |
| `Super+Shift+Q` | End compositor session (save your work first) |

Keyboard layouts are `us,ru`, toggled with Alt+Shift. Change the input configuration
for your languages and pointer/trackpad preferences. The public setup does not
autostart a VPN or reference the author's application profiles.

## Monitors, wallpaper and presets

The compositor discovers connected outputs, extends them automatically, chooses
their best mode and uses scale 1. Change `COMPOSITOR.output.configure` for different
scaling, ordering or modes. The shell defaults to the first available output for
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
| Default / Текущая раскладка | Limits top-left, sessions mid-left, Vast bottom-left, GitHub top-right, Hermes top-center, music and Neko bottom-right |
| Bottom HUD / Hermes снизу | Hermes above the dock with chats opening upward; limits bottom-right with music above; GitHub top-right; sessions bottom-left; no Vast or Neko |

These are different widget **sets**, not only different coordinates. Placement is
defined in `WidgetLayouts.qml`. Changes animate through the wallpaper transition
and `WidgetWaveLoader`; a moving widget keeps an outgoing snapshot while its new
position appears. Preserve this lifecycle when adding presets.

The optional weather panel is separate from the preset widget maps and is hidden
for the empty preset. It requires two user-configured locations.

## Appearance and icons

`shoji-shell/Theme.qml` owns the Mocha palette, mauve accent and Noto Sans UI font.
Walker has a matching CSS palette and the same fixed grain tile. The public Ghostty
configuration uses `monospace`; select an installed font there if desired. The
cursor uses `XCURSOR_THEME` or Adwaita; personal cursor assets are not bundled.

The `Shoji` icon theme inherits Papirus Dark. Add custom flat SVG app icons under
`$XDG_DATA_HOME/icons/Shoji/scalable/apps/`, named for the application's `Icon=` value.
Only the theme index is supplied; no installed application desktop files are copied.
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
The screenshot helper needs Flameshot, grim, Qt's `qtdiag6` and the portal setup.
Brightness uses DDC/CI and `ddcutil`; grant access through your distribution's
normal device rules if needed. It does not silently change permissions.

## Known interaction issue: GPU Screen Recorder

The fullscreen GSR overlay can hold X11 pointer/keyboard grabs while still open
under this compositor. Authme's contents recovered when the recorder was terminated;
changing Authme's rendering flags had not helped. Hide the overlay when returning
to applications. If input remains captured, finish recording and exit the recorder.
No Authme workaround or recorder autostart is installed by this bundle.
