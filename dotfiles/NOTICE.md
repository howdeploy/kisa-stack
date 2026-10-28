# Attribution and licensing

The repository's MIT license covers original KISA configuration, documentation,
scripts and effects. It does not replace licenses or other notices attached to
third-party material. Modified upstream code retains its upstream terms.

| Material | Source and terms |
| --- | --- |
| ShojiWM configuration/API ancestry | [bea4dev/ShojiWM](https://github.com/bea4dev/ShojiWM), MIT; license in `licenses/ShojiWM-MIT` |
| Walker patch and bundled base CSS | [abenz1267/walker](https://github.com/abenz1267/walker) at `sources.json` revision; GPL-3.0, full license in `licenses/Walker-GPL-3.0` |
| Dock/Media QML ancestry | [bea4dev/shoji-bar-3](https://github.com/bea4dev/shoji-bar-3/tree/1f9ca9309e6dbdec0a785bd6a86926a6406b4171); adapted `Dock.qml` and `Media.qml`. `Lock.qml` also credits that project; its exact source revision was not recorded. No standalone upstream LICENSE was found during packaging; no new license grant for the upstream portions is asserted here. |
| Native control geometry and motion | SL UI Library 1.2.1 by SLtowl, MIT; component IDs in `config/shoji-shell/SL-UI-SOURCES.md`, license in `config/shoji-shell/LICENSE-SL-UI` |
| Wallpaper engine patches | [Almamu/linux-wallpaperengine](https://github.com/Almamu/linux-wallpaperengine) at `sources.json` revision, GPL-3.0; GPL-3.0 text in `licenses/Walker-GPL-3.0` also applies to these modified portions |
| MateEngine lock bridge patch | Modification of [Mate Engine Plus](https://github.com/howdeploy/Mate-Engine-Plus), originally by Johnson Jason / Shiny and contributors; retain its MateEngine Pro License v2.0 and additional notices in `licenses/MateEngine-LICENSE`. Current corresponding source is the pinned public repository. The archival `patches/mateengine/session-lock.patch` applies to earlier revision `211ba1d`; no assets or player binaries are included. This is an independent modification, not an official endorsement. |
| mpv OpenGL patch | [mpv-player/mpv](https://github.com/mpv-player/mpv) at `sources.json` revision; modified `context.c` is LGPL-2.1-or-later. Texts in `licenses/mpv-LGPL-2.1` and `licenses/mpv-GPL-2.0`; complete builds may include GPL components |
| Control icons | Lucide, ISC; exact source revision and license beside the SVGs in both icon directories |
| Session icons | Lobe Icons, MIT; source links and license in `config/shoji-shell/icons/` |
| Provider icons | LobeHub, MIT; retained `config/shoji-shell/icons/provider-icons-LICENSE` |
| Home clock mascots | Locally generated pixel-art sprite sheets, shared as clock-widget artwork; no MateEngine models or screenshots |
| MateEngine fallback icon | Original neutral SVG, not copied Steam artwork |
| AI limits protocol adaptation | howdeploy/CanvasTTY, MIT notice retained in `ai-limits.mjs` |
| Palette | [Catppuccin Mocha](https://catppuccin.com/palette/) color values |
| App icon theme | Papirus installed separately; only a small inheritance index is distributed here |

The Walker patch marks local changes dated 2026-09-28: favorites, result labels,
application icon handling and footer/focus behavior. Building the patched launcher
produces a GPL-covered application; retain its corresponding source and notices
when redistributing binaries. No Walker or compositor binary is shipped here.

The two grain PNGs and the clock sprite sheets are generated visual assets, not desktop screenshots.
The fallback wallpaper is a newly written SVG. Personal wallpaper images, music,
fonts, cursor artwork and application-brand icon packs are not redistributed.
