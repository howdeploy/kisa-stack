pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

WidgetSurface {
    id: root
    implicitWidth: 264; implicitHeight: 168
    signal settingsRequested()
    property string displayName: Quickshell.env("USER")
    property string avatarUrl: ""
    property string pending: ""
    property string error: ""
    readonly property string sessionId: Quickshell.env("XDG_SESSION_ID")
    readonly property var actionLabels: ({ logout: "Выйти из сессии?", reboot: "Перезагрузить компьютер?", poweroff: "Выключить компьютер?" })
    onEnabledChanged: { if (!enabled) pending = ""; }
    Process {
        running: true
        command: ["python3", decodeURIComponent(Qt.resolvedUrl("system-profile.py").toString().replace("file://", ""))]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const value = JSON.parse(data);
                    if (typeof value.name !== "string" || !value.name.trim() || typeof value.avatar !== "string" || !value.avatar.startsWith("file:///")) return;
                    root.displayName = value.name; root.avatarUrl = value.avatar;
                } catch (error) { console.warn("Could not read Home Zone profile"); }
            }
        }
    }
    Process {
        id: action
        onExited: exitCode => { if (exitCode !== 0) root.error = "Система не разрешила действие"; }
    }
    function requestAction(name) {
        error = "";
        if (name === "logout" && !sessionId) { error = "Не удалось определить сессию"; return; }
        pending = name;
    }
    function confirm() {
        if (action.running || !pending) return;
        if (pending === "logout" && sessionId) action.command = ["loginctl", "terminate-session", sessionId];
        else if (pending === "reboot" || pending === "poweroff") action.command = ["systemctl", pending];
        else return;
        pending = "";
        action.running = true;
    }
    ClippingRectangle {
        id: avatar
        x: 16; y: 16; width: 56; height: 56
        radius: 28; border.width: 2; border.color: Theme.accent; color: Theme.raised
        Image { id: portrait; anchors.fill: parent; source: root.avatarUrl; sourceSize: Qt.size(112, 112); fillMode: Image.PreserveAspectCrop; asynchronous: true }
        UiText { anchors.centerIn: parent; visible: portrait.status !== Image.Ready; text: root.displayName.slice(0, 1).toUpperCase(); font.pixelSize: 22; color: Theme.accent }
    }
    UiText { x: 84; y: 21; width: parent.width - 100; text: root.displayName; font.pixelSize: 17; font.weight: Font.DemiBold }
    UiText { x: 84; y: 48; width: parent.width - 100; text: "@" + Quickshell.env("USER"); font.pixelSize: 11; color: Theme.muted }
    Row {
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 92 }
        spacing: 10
        visible: !root.pending
        Repeater {
            model: [
                { id: "settings", icon: "home-settings", name: "Настройки", accent: "#cba6f7" },
                { id: "logout", icon: "home-logout", name: "Выйти из сессии", accent: "#89b4fa" },
                { id: "reboot", icon: "home-reboot", name: "Перезагрузка", accent: "#fab387" },
                { id: "poweroff", icon: "home-power", name: "Выключить компьютер", accent: "#f38ba8" }
            ]
            ActionButton {
                id: systemButton
                required property var modelData
                readonly property color accent: modelData.accent
                implicitWidth: 42; implicitHeight: 38; padding: 10
                icon.source: Qt.resolvedUrl("icons/" + modelData.icon + ".svg")
                icon.color: accent
                background: Rectangle {
                    radius: 12
                    color: Qt.tint(Theme.surface, Qt.rgba(systemButton.accent.r, systemButton.accent.g, systemButton.accent.b,
                        systemButton.down ? 0.34 : systemButton.hovered ? 0.26 : 0.16))
                    border.width: systemButton.visualFocus ? 2 : 1
                    border.color: Qt.rgba(systemButton.accent.r, systemButton.accent.g, systemButton.accent.b, systemButton.visualFocus ? 1 : 0.24)
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                hint: modelData.name
                enabled: !action.running
                onClicked: {
                    if (modelData.id === "settings") root.settingsRequested();
                    else root.requestAction(modelData.id);
                }
            }
        }
    }
    Column {
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16; topMargin: 84 }
        spacing: 6; visible: !!root.pending
        UiText { width: parent.width; text: root.actionLabels[root.pending] || ""; font.pixelSize: 11; color: Theme.accent; horizontalAlignment: Text.AlignHCenter }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            ActionButton { text: "Отмена"; implicitHeight: 30; onClicked: root.pending = "" }
            ActionButton { text: "Подтвердить"; implicitHeight: 30; highlighted: true; enabled: !action.running; onClicked: root.confirm() }
        }
    }
    UiText {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
        text: root.error; visible: !!text; color: Theme.danger; font.pixelSize: 10
        horizontalAlignment: Text.AlignHCenter
    }
}
