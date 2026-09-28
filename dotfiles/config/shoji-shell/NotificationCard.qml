pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

Rectangle {
    id: card
    required property var notification
    color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.035)
    radius: 8
    border.width: 1
    border.color: notification && notification.urgency === NotificationUrgency.Critical
        ? Theme.danger : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.07)
    implicitHeight: contents.implicitHeight + 28
    ColumnLayout {
        id: contents
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Rectangle {
                implicitWidth: 32; implicitHeight: 32; radius: 6
                color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.05)
                Image {
                    id: appIcon
                    anchors { fill: parent; margins: 6 }
                    source: {
                        if (!card.notification) return "";
                        const entry = Dock.lookup(card.notification.desktopEntry);
                        const icon = card.notification.appIcon || (entry ? entry.icon : "");
                        if (!icon) return "";
                        return icon.startsWith("/") || icon.includes("://") ? icon : Quickshell.iconPath(icon, true);
                    }
                    sourceSize.width: 24; sourceSize.height: 24; fillMode: Image.PreserveAspectFit
                }
                PanelIcon { anchors.centerIn: parent; name: "bell"; tint: Theme.accent; visible: appIcon.status !== Image.Ready }
            }
            UiText { text: card.notification ? card.notification.appName || "Уведомление" : ""; color: Theme.muted; font.pixelSize: 11; Layout.fillWidth: true }
            ActionButton { icon.source: Qt.resolvedUrl("icons/close.svg"); hint: "Удалить уведомление"; implicitWidth: 28; implicitHeight: 28; padding: 4; onClicked: card.notification.dismiss() }
        }
        UiText { text: card.notification ? card.notification.summary : ""; font.weight: Font.Medium; wrapMode: Text.Wrap; Layout.fillWidth: true }
        UiText { text: card.notification ? card.notification.body : ""; wrapMode: Text.Wrap; Layout.fillWidth: true; visible: text !== ""; maximumLineCount: 7 }
        Image {
            Layout.fillWidth: true; Layout.preferredHeight: Math.min(160, implicitHeight)
            source: card.notification ? card.notification.image : ""
            visible: status === Image.Ready
            fillMode: Image.PreserveAspectFit; sourceSize.width: 640
        }
        Flow {
            Layout.fillWidth: true
            visible: !!card.notification && card.notification.actions.length > 0
            spacing: 6
            Repeater {
                model: card.notification ? card.notification.actions : []
                ActionButton {
                    required property var modelData
                    text: modelData.text || "Открыть"
                    onClicked: modelData.invoke()
                }
            }
        }
    }
}
