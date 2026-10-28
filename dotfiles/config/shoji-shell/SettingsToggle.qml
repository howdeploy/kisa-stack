import QtQuick

ActionButton {
    id: control
    property bool selected: false
    signal requested(bool selected)
    implicitWidth: 44; implicitHeight: 28
    padding: 0
    Accessible.role: Accessible.CheckBox
    Accessible.checkable: true
    Accessible.checked: selected
    onClicked: requested(!selected)
    contentItem: Item {}
    background: Rectangle {
        radius: 9
        color: control.selected ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2) : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.05)
        border.width: control.visualFocus ? 2 : 1
        border.color: control.visualFocus ? Theme.accent : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.1)
        Rectangle {
            width: 18; height: 18; radius: 6
            anchors.verticalCenter: parent.verticalCenter
            x: control.selected ? parent.width - width - 5 : 5
            color: control.selected ? Theme.accent : Theme.muted
            Behavior on x { NumberAnimation { duration: Theme.duration(180); easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Theme.duration(180) } }
        }
        Behavior on color { ColorAnimation { duration: Theme.duration(180) } }
    }
}
