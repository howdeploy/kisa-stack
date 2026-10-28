import QtQuick
import QtQuick.Layouts

RowLayout {
    id: row
    property string label: ""
    property string description: ""
    spacing: 18
    Layout.fillWidth: true
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        UiText { text: row.label; Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 13 }
        UiText { text: row.description; visible: text !== ""; Layout.fillWidth: true; wrapMode: Text.Wrap; color: Theme.muted; font.pixelSize: 11 }
    }
}
