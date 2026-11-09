# SL UI sources and native QML adaptation

The native controls adapt SVG geometry and motion from SL UI Library 1.2.1
by SLtowl, distributed under MIT; retain `LICENSE-SL-UI`.

| Component ID | Native adaptation |
| --- | --- |
| matte-password-input | Floating label, eye geometry, password reveal and focus behavior in `LockFace.qml` |
| matte-buttons-notifications-toggle-v11 | Bell, clapper and slash geometry; notification and button feedback |
| matte-wifi-toggle | Wi-Fi arcs, staggered reveal and switch-thumb transitions |
| matte-volume-slider | Speaker/mute geometry; adapted to three full arcs with volume thresholds |
| matte-brightness-slider | Sun geometry, ray rotation and round slider thumb |
| matte-playback | Two polygons morph between play and pause |

`MotionIcon.qml` uses QtQuick.Shapes, PathSvg and Qt 6.10+ ShapePath.trim.
Colors and typography use the host's Mocha/Mauve palette and Noto Sans.
These are native QML adaptations; no HTML runtime, preview wrappers, web fonts
or demo controllers are embedded. DOM-based component audits do not validate
these Qt scenes. No new graphical or authentication check was run for this export.

The three `icons/settings-*.svg` files are simple local outline drawings copied
with the settings source, separate from the pinned Lucide icon set.

## Voice service status icons

`HomeStatusIcon.qml` adapts the 1.2.4 components `matte-sweep-checkbox` /
`sweep-checkbox` and `matte-cross-circle-checkbox` / `cross-circle-checkbox`.
The 24×24 paths, 1.65 stroke, 23/30 internal scale, circle proportions,
cross rotation/scale and check settling retain the original geometry and motion.
The connecting arc and unknown dash remain separate service states. Reduced
motion stops transitions/spinning. No HTML controller or preview runtime ships.

Recorded source SHA-256 values:

| Source | SHA-256 |
| --- | --- |
| `sweep-checkbox/index.html` | `d708ddb30eeda621ac8c4c1d730b22932312669c450f053a5ad9f5cb0adf6701` |
| `cross-circle-checkbox/index.html` | `987d78c2329fe036cb983e60b8bd191b115c4957275bd75ef171c805705530c2` |
| Shared `buttons.css` | `e9ca9cbba17dec324b29c7063c0b749b1e732fcceb0cca2e32cef21fd2899339` |
| Shared `buttons.js` | `0d04c9c2faafbddf0ae1bc49fede7bfdd9a3d7b3bb54b5c4d2f06ac5ae46e5e6` |

These are native Qt adaptations under the existing SLtowl MIT notice; no new
visual check or HTML subtree audit is claimed by this publication.
