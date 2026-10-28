import QtQuick
import QtQuick.Layouts

ActionButton {
    id: tile
    property string subtitle
    property string glyph
    property bool connected: false
    property bool expanded: false
    implicitHeight: 64
    padding: 12
    hoverEnabled: true
    Accessible.name: text + ": " + subtitle
    background: Rectangle {
        radius: Theme.surfaceRadius
        color: tile.connected ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
            : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, tile.hovered ? 0.08 : 0.035)
        border.width: 1
        border.color: tile.visualFocus ? Theme.accent : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.07)
        Behavior on color { ColorAnimation { duration: Theme.duration(300) } }
        Behavior on border.color { ColorAnimation { duration: Theme.duration(300) } }
    }
    contentItem: RowLayout {
        spacing: 9
        PanelIcon { name: tile.glyph === "wifi" && !tile.connected ? "wifi-off" : tile.glyph; tint: tile.connected ? Theme.accent : Theme.ink }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 2
            UiText { text: tile.text; font.weight: Font.Medium; color: Theme.ink; Layout.fillWidth: true }
            UiText { text: tile.subtitle; font.pixelSize: 10; color: Theme.muted; Layout.fillWidth: true }
        }
        PanelIcon {
            name: "chevron-right"; implicitWidth: 16; implicitHeight: 16; tint: Theme.muted
            rotation: tile.expanded ? 90 : 0
            Behavior on rotation { NumberAnimation { duration: Theme.duration(220); easing.type: Easing.OutCubic } }
        }
    }
}
