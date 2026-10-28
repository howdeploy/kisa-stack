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
