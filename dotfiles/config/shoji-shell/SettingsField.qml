import QtQuick
import QtQuick.Controls

TextField {
    id: control
    implicitHeight: 38
    color: Theme.ink
    placeholderTextColor: Theme.muted
    selectionColor: Theme.accent
    selectedTextColor: Theme.surface
    font.family: Theme.font
    font.pixelSize: 12
    leftPadding: 12; rightPadding: 12
    background: Rectangle {
        radius: Theme.surfaceRadius
        color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, control.activeFocus ? 0.06 : 0.025)
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? Theme.accent : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.08)
        Behavior on border.color { ColorAnimation { duration: Theme.duration(150) } }
        Behavior on color { ColorAnimation { duration: Theme.duration(180) } }
    }
}
