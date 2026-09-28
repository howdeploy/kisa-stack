import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    spacing: 12
    Rectangle {
        Layout.fillWidth: true; implicitHeight: 72; radius: 8
        color: Notifications.quiet ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.10)
            : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.035)
        border.width: 1; border.color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.07)
        RowLayout {
            anchors { fill: parent; margins: 14 }
            spacing: 12
            PanelIcon { name: Notifications.quiet ? "bell-off" : "bell"; tint: Theme.accent; implicitWidth: 24; implicitHeight: 24 }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                UiText { text: "Не беспокоить"; font.weight: Font.Medium; color: Theme.ink; Layout.fillWidth: true }
                UiText { text: Notifications.quiet ? "Без всплывающих сообщений" : "Показывать новые сообщения"; font.pixelSize: 10; color: Theme.muted; Layout.fillWidth: true }
            }
            Switch {
                id: quietSwitch
                checked: Notifications.quiet
                Accessible.name: "Не беспокоить"
                onToggled: Notifications.quiet = checked
                padding: 0
                indicator: Rectangle {
                    implicitWidth: 38; implicitHeight: 22; radius: 11
                    color: quietSwitch.checked ? Theme.accent : Theme.line
                    border.width: quietSwitch.visualFocus ? 2 : 0; border.color: Theme.ink
                    Rectangle { x: quietSwitch.checked ? 19 : 3; y: 3; width: 16; height: 16; radius: 8; color: quietSwitch.checked ? Theme.surface : Theme.ink }
                }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true; Layout.topMargin: 4
        UiText { text: "Последние"; font.pixelSize: 11; font.weight: Font.Medium; color: Theme.muted; Layout.fillWidth: true }
        UiText { text: String(Notifications.count); color: Theme.muted; font.pixelSize: 11 }
        ActionButton {
            text: "Очистить"; icon.source: Qt.resolvedUrl("icons/clear.svg")
            hint: "Удалить все уведомления"; implicitHeight: 30; font.pixelSize: 11
            enabled: Notifications.count > 0
            onClicked: Notifications.clearAll()
        }
    }
    Rectangle {
        visible: Notifications.count === 0
        Layout.fillWidth: true; implicitHeight: 176; radius: 8
        color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.025)
        ColumnLayout {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 20 }
            spacing: 12
            Rectangle {
                Layout.alignment: Qt.AlignHCenter; implicitWidth: 40; implicitHeight: 40; radius: 8
                color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.05)
                PanelIcon { anchors.centerIn: parent; name: "bell"; tint: Theme.accent; implicitWidth: 28; implicitHeight: 28 }
            }
            UiText { text: "Пока ничего нового"; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
            UiText { text: "Новые уведомления появятся здесь"; font.pixelSize: 11; color: Theme.muted; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
        }
    }
    Repeater {
        model: Notifications.items.slice().reverse()
        NotificationCard { required property var modelData; notification: modelData; Layout.fillWidth: true }
    }
}
