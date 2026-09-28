import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Button {
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
        radius: 8
        color: tile.connected ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
            : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, tile.hovered ? 0.08 : 0.035)
        border.width: 1
        border.color: tile.visualFocus ? Theme.accent : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.07)
    }
    contentItem: RowLayout {
        spacing: 9
        PanelIcon { name: tile.glyph; tint: tile.connected ? Theme.accent : Theme.ink }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 2
            UiText { text: tile.text; font.weight: Font.Medium; color: Theme.ink; Layout.fillWidth: true }
            UiText { text: tile.subtitle; font.pixelSize: 10; color: Theme.muted; Layout.fillWidth: true }
        }
        PanelIcon {
            name: "chevron-right"; implicitWidth: 16; implicitHeight: 16; tint: Theme.muted
            rotation: tile.expanded ? 90 : 0
            Behavior on rotation { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }
    }
}
