import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Button {
    id: row
    property string subtitle: ""
    property string glyph: ""
    property bool selected: false
    property string trailingIcon: selected ? "check" : ""
    property real trailingRotation: 0
    property string hint: text + (subtitle ? ": " + subtitle : "")
    implicitHeight: subtitle ? 52 : 38
    padding: 10
    hoverEnabled: true
    opacity: enabled ? 1 : 0.45
    Accessible.name: hint
    background: Rectangle {
        radius: 6
        color: row.down ? Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.10)
            : row.hovered ? Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.06)
            : row.selected ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.06) : "transparent"
        border.width: row.visualFocus ? 1 : 0
        border.color: Theme.accent
        Behavior on color { ColorAnimation { duration: 100 } }
    }
    contentItem: RowLayout {
        spacing: 10
        PanelIcon {
            visible: row.glyph !== ""
            name: row.glyph || "volume"
            tint: row.selected ? Theme.accent : Theme.muted
            Layout.preferredWidth: 18; Layout.preferredHeight: 18
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            UiText { text: row.text; font.pixelSize: 12; Layout.fillWidth: true }
            UiText { text: row.subtitle; visible: text !== ""; color: Theme.muted; font.pixelSize: 10; Layout.fillWidth: true }
        }
        PanelIcon {
            visible: row.trailingIcon !== ""
            name: row.trailingIcon || "check"
            tint: row.selected ? Theme.accent : Theme.muted
            Layout.preferredWidth: 16; Layout.preferredHeight: 16
            rotation: row.trailingRotation
            Behavior on rotation { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }
    }
}
