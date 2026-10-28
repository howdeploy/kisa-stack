pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

// Native adaptation of SL UI SVGs and motion; see SL-UI-SOURCES.md and LICENSE-SL-UI.
Item {
    id: icon
    required property string kind
    property bool active: true
    property real level: 1
    property color tint: Theme.ink
    property bool ready: false
    property real ringAngle: 0
    implicitWidth: 20
    implicitHeight: 20
    readonly property bool animate: ready && !Theme.reducedMotion
    Component.onCompleted: ready = true
    function pulse() {
        if (kind === "bell" && animate && active) ring.restart();
    }
    onActiveChanged: { if (ready && !active) { ring.stop(); ringAngle = 0; } }
    SequentialAnimation {
        id: ring
        NumberAnimation { target: icon; property: "ringAngle"; from: 0; to: -12; duration: 164; easing.type: Easing.InOutSine }
        NumberAnimation { target: icon; property: "ringAngle"; to: 9; duration: 189; easing.type: Easing.InOutSine }
        NumberAnimation { target: icon; property: "ringAngle"; to: -5; duration: 180; easing.type: Easing.InOutSine }
        NumberAnimation { target: icon; property: "ringAngle"; to: 2; duration: 148; easing.type: Easing.InOutSine }
        NumberAnimation { target: icon; property: "ringAngle"; to: 0; duration: 139; easing.type: Easing.InOutSine }
    }
    Connections {
        target: Theme
        function onReducedMotionChanged(): void { if (Theme.reducedMotion) { ring.stop(); icon.ringAngle = 0; } }
    }
    Item {
        id: viewBox
        anchors.centerIn: parent
        width: icon.kind === "wifi" || icon.kind === "eyes" ? 32 : 24
        height: icon.kind === "eyes" ? 24 : width
        scale: Math.min(icon.width / width, icon.height / height)
        Loader {
            anchors.fill: parent
            sourceComponent: icon.kind === "bell" ? bell : icon.kind === "wifi" ? wifi
                : icon.kind === "volume" ? volume : icon.kind === "brightness" ? sun
                : icon.kind === "eyes" ? eyes : icon.kind === "playback" ? playback : null
        }
    }
    component Stroke: Shape {
        id: stroke
        required property string path
        property real weight: 1.7
        property real progress: 1
        width: 32; height: 32
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        visible: progress > 0
        ShapePath {
            strokeWidth: stroke.weight
            strokeColor: icon.tint
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            trim.end: stroke.progress
            PathSvg { path: stroke.path }
        }
    }
    Component {
        id: playback
        Item {
            id: player
            property real playing: icon.active ? 1 : 0
            Behavior on playing { enabled: icon.animate; NumberAnimation { duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.4, 0, 0.2, 1, 1, 1] } }
            Repeater {
                // Original clip-path vertices in percent of the 24×24 viewBox.
                model: [
                    [[[29.1667, 20.8333], [46, 31.5455], [46, 68.4545], [29.1667, 79.1667]],
                     [[25, 20.8333], [41.6667, 20.8333], [41.6667, 79.1667], [25, 79.1667]]],
                    [[[45.8333, 31.4394], [75, 50], [75, 50], [45.8333, 68.5606]],
                     [[58.3333, 20.8333], [75, 20.8333], [75, 79.1667], [58.3333, 79.1667]]]
                ]
                Shape {
                    id: piece
                    required property var modelData
                    width: 24; height: 24
                    antialiasing: true
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeWidth: -1; fillColor: icon.tint
                        PathPolyline {
                            path: piece.modelData[0].concat([piece.modelData[0][0]]).map((p, i) => {
                                const target = piece.modelData[1][i % 4];
                                return Qt.point((p[0] + (target[0] - p[0]) * player.playing) * 0.24,
                                    (p[1] + (target[1] - p[1]) * player.playing) * 0.24);
                            })
                        }
                    }
                }
            }
        }
    }
    Component {
        id: bell
        Item {
            Item {
                id: bellBody
                width: 24; height: 24
                property real settledAngle: icon.active ? 0 : -5
                Behavior on settledAngle { enabled: icon.animate; NumberAnimation { duration: 520; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1] } }
                transform: Rotation { origin.x: 12; origin.y: 5; angle: bellBody.settledAngle + icon.ringAngle }
                Stroke { path: "M6 16h12l-1.5-2.2V10a4.5 4.5 0 0 0-9 0v3.8Z" }
                Stroke { path: "M10 19h4" }
            }
            Stroke {
                path: "M4 4 20 20"
                opacity: icon.active ? 0 : 1
                transform: Scale { origin.x: 12; origin.y: 12; xScale: icon.active ? 0.65 : 1; yScale: xScale
                    Behavior on xScale { enabled: icon.animate; NumberAnimation { duration: 520; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1] } }
                }
                Behavior on opacity { enabled: icon.animate; NumberAnimation { duration: 220 } }
            }
        }
    }
    Component {
        id: wifi
        Item {
            Rectangle { x: 15; y: 24; width: 2; height: 2; radius: 1; color: icon.tint }
            Repeater {
                model: ["M12 20a6 6 0 0 1 8 0", "M8 15a12 12 0 0 1 16 0", "M4 10a18 18 0 0 1 24 0"]
                Stroke {
                    id: wifiArc
                    required property int index
                    required property string modelData
                    path: modelData
                    weight: 1.45
                    opacity: icon.active ? 1 : 0.16
                    transform: Scale {
                        origin.x: 16; origin.y: 25
                        xScale: icon.active ? 1 : 0.86
                        yScale: xScale
                        Behavior on xScale {
                            enabled: icon.animate
                            SequentialAnimation {
                                PauseAnimation { duration: icon.active ? wifiArc.index * 75 : 0 }
                                NumberAnimation { duration: 580; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.4, 0, 0.2, 1, 1, 1] }
                            }
                        }
                    }
                    Behavior on opacity {
                        enabled: icon.animate
                        SequentialAnimation {
                            PauseAnimation { duration: icon.active ? wifiArc.index * 75 : 0 }
                            NumberAnimation { duration: 420 }
                        }
                    }
                }
            }
        }
    }
    Component {
        id: volume
        Item {
            Stroke { weight: 1.4; path: "M3 9h4l5-4v14l-5-4H3V9Z" }
            Repeater {
                model: ["M14 9a5 5 0 0 1 0 6", "M17 6a9 9 0 0 1 0 12", "M19 3a13 13 0 0 1 0 18"]
                Stroke {
                    required property int index
                    required property string modelData
                    path: modelData
                    weight: 1.4
                    opacity: !icon.active || icon.level <= 0 ? 0
                        : index === 0 ? 1
                        : index === 1 ? (icon.level > 0.2 ? 1 : 0)
                        : icon.level < 0.5 ? 0 : 0.35 + 0.65 * Math.max(0, Math.min(1, (icon.level - 0.7) / 0.3))
                    Behavior on opacity { enabled: icon.animate; NumberAnimation { duration: 80 } }
                }
            }
            Stroke {
                path: "m3 3 18 18"; weight: 1.4
                opacity: !icon.active || icon.level <= 0 ? 1 : 0
                Behavior on opacity { enabled: icon.animate; NumberAnimation { duration: 80 } }
            }
        }
    }
    Component {
        id: sun
        Item {
            Shape {
                width: 24; height: 24
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: 1.4; strokeColor: icon.tint; fillColor: "transparent"
                    PathAngleArc { centerX: 12; centerY: 12; radiusX: 3.5; radiusY: 3.5; startAngle: 0; sweepAngle: 360 }
                }
            }
            Stroke {
                path: "M12 2v3m0 14v3M2 12h3m14 0h3M5 5l2 2m10 10 2 2M5 19l2-2M17 7l2-2"
                weight: 1.4
                opacity: 0.25 + Math.max(0, Math.min(1, icon.level)) * 0.75
                transform: Rotation {
                    origin.x: 12; origin.y: 12; angle: Math.max(0, Math.min(1, icon.level)) * 90
                    Behavior on angle { enabled: icon.animate; NumberAnimation { duration: 100 } }
                }
                Behavior on opacity { enabled: icon.animate; NumberAnimation { duration: 100 } }
            }
        }
    }
    Component {
        id: eyes
        Item {
            Item {
                width: 32; height: 24
                opacity: icon.active ? 1 : 0
                transform: Scale { origin.x: 16; origin.y: 12; yScale: icon.active ? 1 : 0.25
                    Behavior on yScale { enabled: icon.animate; NumberAnimation { duration: 440; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.4, 0, 0.2, 1, 1, 1] } }
                }
                Behavior on opacity {
                    enabled: icon.animate
                    SequentialAnimation {
                        PauseAnimation { duration: icon.active ? 120 : 0 }
                        NumberAnimation { duration: 220 }
                    }
                }
                Stroke { weight: 1.35; path: "M2.5 12s2.2-3.5 6-3.5 6 3.5 6 3.5-2.2 3.5-6 3.5-6-3.5-6-3.5Zm15 0s2.2-3.5 6-3.5 6 3.5 6 3.5-2.2 3.5-6 3.5-6-3.5-6-3.5Z" }
                Repeater {
                    model: [8.5, 23.5]
                    Rectangle {
                        required property real modelData
                        x: modelData - 1.5; y: 10.5; width: 3; height: 3; radius: 1.5; color: icon.tint
                        scale: icon.active ? 1 : 0.3
                        Behavior on scale {
                            enabled: icon.animate
                            SequentialAnimation {
                                PauseAnimation { duration: icon.active ? 180 : 0 }
                                NumberAnimation { duration: 380; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }
            }
            Stroke {
                weight: 1.35; path: "M2.5 12.5c1.7 2.7 4 3.7 6 3.7s4.3-1 6-3.7M17.5 12.5c1.7 2.7 4 3.7 6 3.7s4.3-1 6-3.7"
                opacity: icon.active ? 0 : 1
                transform: Scale { origin.x: 16; origin.y: 14; yScale: icon.active ? 0.2 : 1
                    Behavior on yScale { enabled: icon.animate; NumberAnimation { duration: 440; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.4, 0, 0.2, 1, 1, 1] } }
                }
                Behavior on opacity { enabled: icon.animate; NumberAnimation { duration: 220 } }
            }
        }
    }
}
