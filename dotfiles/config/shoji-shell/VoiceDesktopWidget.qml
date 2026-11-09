pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    required property var shell
    required property var output
    implicitWidth: 340
    implicitHeight: content.implicitHeight + 32
    width: implicitWidth
    height: implicitHeight

    WidgetSurface { anchors.fill: parent }
    ColumnLayout {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            UiText { text: "Ввод"; font.pixelSize: 16; Layout.fillWidth: true; color: Theme.muted }
            VoiceInputModes {}
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.1) }
        HomeServiceList { Layout.fillWidth: true }
    }
}
