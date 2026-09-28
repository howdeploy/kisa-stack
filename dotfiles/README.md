# KISA desktop dotfiles

A ShojiWM desktop with a Quickshell panel and dock, a customized Walker launcher,
Catppuccin Mocha colors, animated wallpaper/widget presets, and GPU window effects.
This directory contains the configuration sources, installation tools and a map
of how the parts fit together. It is a sanitized source distribution, not a disk
image or a backup of the author's home directory.

**Use the [howdeploy/ShojiWM fork](https://github.com/howdeploy/ShojiWM/tree/howdeploy/stack),
branch `howdeploy/stack`, at the revision in [sources.json](sources.json).** The
configuration depends on fixes and APIs contributed by howdeploy. Fork `main`
does not include them. See [fork and PR provenance](docs/fork.md).

## Start here

1. Read [installation](docs/install.md): dependencies, pinned builds, preview,
   installation, backups and recovery. Arch/Manjaro is the reference platform;
   other Linux distributions need equivalent recent libraries and manual setup.
2. Read [desktop configuration](docs/configuration.md): keys, monitors, wallpaper,
   presets, icons, launcher and terminal.
3. Enable only the [optional integrations](docs/widgets.md) you want, using your
   own local CLI logins. They are off by default, even if a CLI is already logged in.
4. For changes, use [architecture](docs/architecture.md), [shader guide](docs/shaders.md)
   and [AGENTS.md](AGENTS.md).

The first launch uses the **empty** preset and a bundled neutral SVG background.
`Super+W` opens the wallpaper/preset picker. The other two presets preserve the
original arrangements and widget sets; integrations stay absent until enabled.
The UI currently retains the original Russian labels. Documentation is in English.

## Categories

| Directory | Contents |
| --- | --- |
| `config/shojiwm/` | TSX compositor configuration, window management, GLSL effects, session scripts |
| `config/shoji-shell/` | QML panels, widgets, wallpaper picker, Qt shaders, data collectors |
| `config/walker/`, `patches/walker/` | Launcher theme, tagged favorites, source patch for custom controls |
| `config/elephant/` | Launcher providers and portable home-directory search |
| `config/ghostty/` | Terminal colors, GTK styling and layout-independent keyboard shortcuts |
| `config/xdg-desktop-portal/` | ShojiWM screen casting, wlr screenshots and GTK fallback |
| `data/icons/Shoji/` | Local SVG override theme inheriting Papirus Dark |
| `bin/` | Optional Codex session chooser in Ghostty |
| `scripts/` | Pinned builds, shader compilation, preview/install and publication checks |
| `docs/`, `dependencies/` | Setup, behavior, dependencies, privacy and provenance |

## AI-assisted customization

Two portable skills ship in the main skill catalog:

- [shojiwm](../skills/shojiwm/SKILL.md): understand and modify this desktop safely.
- [shoji-shaders](../skills/shoji-shaders/SKILL.md): translate references into effects,
  choose the correct shader pipeline and preserve animation lifecycle behavior.

Install them with the existing repository installer, from the repository root:

```bash
./install.sh shojiwm --codex
./install.sh shoji-shaders --codex
# --claude and --hermes are also supported by the installer.
```

## Privacy and validation

No credential stores, browser profiles, personal wallpapers, application launchers
with private flags, session databases, account caches or local integration settings
are shipped. No account is supplied by these dotfiles. Read [privacy](docs/privacy.md)
before contributing changes or publishing screenshots.

[Validation](docs/validation.md) distinguishes source checks from a complete clean-machine
desktop test. This is an experimental compositor stack; keep an existing working
desktop session available while setting it up. [Attribution and licensing](NOTICE.md)
apply to the individual components.
