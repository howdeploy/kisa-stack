import QtQuick
import QtQuick.Controls

Button {
    id: control
    property string hint: text
    implicitHeight: 36
    font.family: Theme.font
    font.pixelSize: 13
    palette.buttonText: highlighted ? Theme.surface : Theme.ink
    icon.color: highlighted ? Theme.surface : Theme.ink
    icon.width: 18
    icon.height: 18
    padding: 10
    hoverEnabled: true
    opacity: enabled ? 1 : 0.45
    background: Rectangle {
        radius: 12
        color: control.highlighted ? Theme.accent : control.hovered ? Theme.hover : Theme.raised
        border.width: control.visualFocus ? 2 : 0
        border.color: Theme.accent
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    Accessible.name: hint
}
