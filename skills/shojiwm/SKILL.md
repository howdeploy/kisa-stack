---
name: shojiwm
description: Configure and troubleshoot the KISA ShojiWM desktop, including TSX window management, Quickshell panels, widget presets, Walker and installation. Use for ShojiWM desktop work; not for unrelated window managers or virtual machines.
metadata:
  hermes:
    tags: [desktop, linux, wayland]
---

# KISA ShojiWM desktop

Locate the user's installed config and/or the `howdeploy/kisa-stack` checkout
before changing files. Public reference:
https://github.com/howdeploy/kisa-stack/tree/main/dotfiles . Read its `README.md`,
`AGENTS.md`, `sources.json` and the docs relevant to the request. This skill does
not require the author's filesystem, Wiki, accounts or other installed skills.

## Source map

Installed files are under `${XDG_CONFIG_HOME:-$HOME/.config}`; published sources
are under `dotfiles/config/` in kisa-stack. Installation copies them, rather than
linking live state into Git.

| Concern | Relative path under the config root |
| --- | --- |
| Composition, effects, bindings, outputs, processes, IPC | `shojiwm/src/index.tsx` |
| Tiling, floating, focus, workspaces, geometry, minimize/fullscreen | `shojiwm/src/window-manager.ts` |
| Compositor shader modules and GLSL | `shojiwm/src/effect/` |
| Shell entry, top panel/dock/tray | `shoji-shell/shell.qml`, `ScreenShell.qml`, `Dock.qml` |
| Palette and opt-in gates | `shoji-shell/Theme.qml`, `Settings.qml` |
| Wallpaper and widget sets | `Wallpapers.qml`, `WidgetLayouts.qml`, `WallpaperPicker.qml` under `shoji-shell/` |
| Widget transition lifetime | `WidgetWaveLoader.qml`, `WidgetWaveSnapshot.qml`, `WidgetWaveMask.qml` |
| Launcher data and appearance | `walker/favorites.toml`, `walker/themes/shoji/`, `elephant/` |

## Compositor contract

The pinned fork is https://github.com/howdeploy/ShojiWM on `howdeploy/stack`,
revision recorded in `dotfiles/sources.json`. Fork `main` is not the integration
branch. Contributions include keyboard layout status/LEDs, cursor scaling,
full-window subsurfaces and native workspace waves; `dotfiles/docs/fork.md` links
their independent upstream PRs. Check versions before assuming those APIs exist.

This is a custom TSX renderer with signals, not React/DOM. Keep one `ManagedWindow`
and its `ClientWindow`, preserve CSD/SSD/fullscreen branches, state persistence,
enable/disable cleanup, usable-area handling and IPC. Use the pinned fork's local
docs (`docs/docs/configuration/`) and `packages/shoji_wm/src/` types when available.

Processes have different lifetimes: `once` with `once-per-session` is startup;
`service` supervises the shell; `spawn` handles user actions. Do not accidentally
restart applications on every config reload. Environment from an agent process
can belong to an older desktop: confirm the running session from process/log data.

The shell uses Wayland protocols for workspaces/toplevels and the custom socket
`${XDG_RUNTIME_DIR}/shojiwm-${WAYLAND_DISPLAY}.sock` for dock/activation information.
Its own wallpaper IPC is a different interface. Do not substitute a Hyprland API.

## Preserve the user's desktop

Read the existing implementation and callers before editing. State what will
change. Keep unrelated user changes. A wallpaper/preset selection applies both
choices regardless of the active picker row. Presets own different widget sets;
the empty preset stays first. Movement between presets needs the outgoing snapshot
as well as the destination. Register new QML types in `qmldir` where applicable.

Account integrations are off by default. Never enable them, copy local auth/state,
or replace sanitized examples with machine data merely to make a demo look populated.
The optional local `integrations.env` is trusted shell code outside the repository.
The installer creates backups; preserve them. The custom Walker layout requires
its pinned source patch, not only CSS/XML.

For shader work read the public `dotfiles/docs/shaders.md` or use `shoji-shaders`
if installed. For setup read `docs/install.md`; for adapters read `docs/widgets.md`.
Request permission for builds, installations, reloads and GUI tests when the user's
session instructions require it; existing explicit authorization carries forward.
Report exact changed files and distinguish static checks from live GPU verification.
