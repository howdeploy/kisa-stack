pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

// Native SL Circle check / Circle cross geometry and motion; see SL-UI-SOURCES.md.
Item {
    id: root
    property string status: "unknown"
    property string description: ""
    property bool initialized: false
    readonly property bool animate: initialized && !Theme.reducedMotion
    readonly property color tint: VoiceSystem.tint(status)
    implicitWidth: 26
    implicitHeight: 26
    Accessible.role: Accessible.Indicator
    Accessible.name: VoiceSystem.label(status) + (description ? ": " + description : "")
    Component.onCompleted: initialized = true

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: root.status === "connecting" ? "transparent" : root.tint
        Behavior on border.color { enabled: root.animate; ColorAnimation { duration: 350 } }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: root.tint
            Behavior on color { enabled: root.animate; ColorAnimation { duration: 350 } }
            opacity: root.status === "ready" || root.status === "unavailable" ? 1 : 0
            Behavior on opacity { enabled: root.animate; NumberAnimation { duration: 380 } }
        }
    }
    component Stroke: Shape {
        id: stroke
        required property string path
        property color ink: Theme.surface
        width: 24; height: 24
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 1.65
            strokeColor: stroke.ink
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: stroke.path }
        }
    }
    Item {
        width: 24; height: 24
        anchors.centerIn: parent
        scale: root.width / 30 * 23 / 24
        Stroke {
            path: "m5 12 4.5 4.5L19 7"
            opacity: root.status === "ready" ? 1 : 0
            scale: root.status === "ready" ? 1 : 0.9
            Behavior on opacity {
                enabled: root.animate
                SequentialAnimation {
                    PauseAnimation { duration: root.status === "ready" ? 20 : 0 }
                    NumberAnimation { duration: 180 }
                }
            }
            Behavior on scale {
                enabled: root.animate
                SequentialAnimation {
                    PauseAnimation { duration: root.status === "ready" ? 20 : 0 }
                    NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.22, 0.61, 0.36, 1, 1, 1] }
                }
            }
        }
        Item {
            width: 24; height: 24
            opacity: root.status === "unavailable" ? 1 : 0
            rotation: root.status === "unavailable" ? 0 : -35
            scale: root.status === "unavailable" ? 1 : 0.7
            Behavior on opacity { enabled: root.animate; NumberAnimation { duration: 240 } }
            Behavior on rotation {
                enabled: root.animate
                NumberAnimation { duration: 400; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.22, 0.61, 0.36, 1, 1, 1] }
            }
            Behavior on scale {
                enabled: root.animate
                NumberAnimation { duration: 400; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.22, 0.61, 0.36, 1, 1, 1] }
            }
            Stroke { path: "m7 7 10 10" }
            Stroke { path: "M17 7 7 17" }
        }
        Stroke {
            path: "M6 12h12"
            ink: Theme.muted
            opacity: root.status === "unknown" ? 1 : 0
            Behavior on opacity { enabled: root.animate; NumberAnimation { duration: 220 } }
        }
    }
    Shape {
        anchors.centerIn: parent
        width: 24; height: 24
        visible: root.status === "connecting"
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 1.65
            strokeColor: root.tint
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: 12; centerY: 12; radiusX: 10; radiusY: 10; startAngle: -90; sweepAngle: 250 }
        }
        NumberAnimation on rotation {
            from: 0; to: 360; duration: 1600; loops: Animation.Infinite
            running: root.visible && root.status === "connecting" && !Theme.reducedMotion
        }
    }
}
