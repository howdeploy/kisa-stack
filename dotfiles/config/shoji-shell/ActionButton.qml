import QtQuick
import QtQuick.Controls

Button {
    id: control
    property string hint: text
    property bool translucent: false
    implicitHeight: 36
    font.family: Theme.font
    font.pixelSize: 13
    palette.buttonText: highlighted && !translucent ? Theme.surface : Theme.ink
    icon.color: highlighted && !translucent ? Theme.surface : Theme.ink
    icon.width: 18
    icon.height: 18
    padding: 10
    hoverEnabled: true
    opacity: enabled ? 1 : 0.45
    property real feedbackScale: Theme.reducedMotion ? 1 : down ? 0.98 : 1
    property real feedbackLift: Theme.reducedMotion ? 0 : down ? 1 : hovered ? -1 : 0
    transform: [
        Scale { origin.x: control.width / 2; origin.y: control.height / 2; xScale: control.feedbackScale; yScale: xScale },
        Translate { y: control.feedbackLift }
    ]
    Behavior on feedbackScale { NumberAnimation { duration: Theme.duration(control.down ? 100 : 340); easing.type: Easing.OutCubic } }
    Behavior on feedbackLift { NumberAnimation { duration: Theme.duration(control.down ? 100 : 220); easing.type: Easing.OutCubic } }
    background: Rectangle {
        radius: Theme.surfaceRadius
        color: control.translucent ? (control.highlighted ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, control.hovered ? 0.22 : 0.14)
            : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, control.hovered ? 0.09 : 0.035))
            : control.highlighted ? Theme.accent : control.hovered ? Theme.hover : Theme.raised
        border.width: control.visualFocus ? 2 : control.translucent ? 1 : 0
        border.color: control.visualFocus ? Theme.accent : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, control.highlighted ? 0.18 : 0.09)
        Behavior on color { ColorAnimation { duration: Theme.duration(220) } }
        Behavior on border.color { ColorAnimation { duration: Theme.duration(180) } }
    }
    Accessible.name: hint
}
