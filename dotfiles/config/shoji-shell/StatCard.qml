pragma ComponentBehavior: Bound
import QtQuick

Rectangle {
    id: card
    property string label
    property string reading
    property string detail
    property real fraction: 0
    color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.035); radius: 8
    border.width: 1; border.color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.07)
    implicitHeight: 106
    Column {
        anchors { fill: parent; margins: 12 }
        spacing: 6
        UiText { width: parent.width; text: card.label; color: Theme.muted; font.pixelSize: 10; font.letterSpacing: 1 }
        UiText { width: parent.width; text: card.reading; font.pixelSize: 21; font.weight: Font.DemiBold }
        UiText { width: parent.width; text: card.detail; color: Theme.muted; font.pixelSize: 9 }
    }
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
        height: 3; radius: 1.5
        color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.09)
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, card.fraction))
            height: parent.height; radius: parent.radius; color: Theme.accent
        }
    }
}
