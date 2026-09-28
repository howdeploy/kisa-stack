import QtQuick

Column {
    id: meter
    property string label
    property string reading
    property real fraction: 0
    spacing: 8
    Row {
        width: parent.width
        UiText { text: meter.label; width: parent.width * 0.43; color: Theme.muted; font.pixelSize: 12 }
        UiText { text: meter.reading; width: parent.width * 0.57; horizontalAlignment: Text.AlignRight; font.weight: Font.DemiBold }
    }
    Rectangle {
        width: parent.width; height: 3; radius: 1.5
        color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.09)
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, meter.fraction))
            height: parent.height; radius: parent.radius; color: Theme.accent
        }
    }
}
