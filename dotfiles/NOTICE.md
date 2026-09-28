# Attribution and licensing

The repository's MIT license covers original KISA configuration, documentation,
scripts and effects. It does not replace licenses or other notices attached to
third-party material. Modified upstream code retains its upstream terms.

| Material | Source and terms |
| --- | --- |
| ShojiWM configuration/API ancestry | [bea4dev/ShojiWM](https://github.com/bea4dev/ShojiWM), MIT; license in `licenses/ShojiWM-MIT` |
| Walker patch and bundled base CSS | [abenz1267/walker](https://github.com/abenz1267/walker) at `sources.json` revision; GPL-3.0, full license in `licenses/Walker-GPL-3.0` |
| Dock/Media QML ancestry | [bea4dev/shoji-bar-3](https://github.com/bea4dev/shoji-bar-3/tree/1f9ca9309e6dbdec0a785bd6a86926a6406b4171); adapted `Dock.qml` and `Media.qml`. No standalone upstream LICENSE was found during packaging; no new license grant for the upstream portions is asserted here. |
| Control icons | Lucide, ISC; exact source revision and license beside the SVGs in both icon directories |
| Session icons | Lobe Icons, MIT; source links and license in `config/shoji-shell/icons/` |
| AI limits protocol adaptation | howdeploy/CanvasTTY, MIT notice retained in `ai-limits.mjs` |
| Palette | [Catppuccin Mocha](https://catppuccin.com/palette/) color values |
| App icon theme | Papirus installed separately; only a small inheritance index is distributed here |

The Walker patch marks local changes dated 2026-09-28: favorites, result labels,
application icon handling and footer/focus behavior. Building the patched launcher
produces a GPL-covered application; retain its corresponding source and notices
when redistributing binaries. No Walker or compositor binary is shipped here.

The two grain PNGs are generated visual texture assets, not desktop screenshots.
The fallback wallpaper is a newly written SVG. Personal wallpaper images, music,
fonts, cursor artwork and application-brand icon packs are not redistributed.
