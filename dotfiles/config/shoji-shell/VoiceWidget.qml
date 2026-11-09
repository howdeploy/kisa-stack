pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 18
    property bool active: false
    readonly property var sessionOptions: [{ label: "Без Codex", value: "" }].concat(
        VoiceSystem.threads.map(t => ({ label: VoiceSystem.threadName(t.id), value: t.id })))
    Connections {
        target: VoiceSystem
        function onAvailableChanged(): void { if (root.active && VoiceSystem.available) VoiceSystem.loadThreads(); }
    }
    onActiveChanged: {
        if (active) {
            VoiceSystem.refresh();
            VoiceSystem.loadThreads();
        } else sessionPicker.popup.close();
    }
    HomeServiceList { Layout.fillWidth: true; showSubscription: true }
    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.1) }
    RowLayout {
        Layout.fillWidth: true
        UiText { text: "Ввод"; Layout.fillWidth: true; font.pixelSize: 16; font.weight: Font.Medium }
        VoiceInputModes {}
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            UiText { text: "Сессия Codex"; Layout.fillWidth: true; font.pixelSize: 16; font.weight: Font.Medium }
            ActionButton {
                icon.source: Qt.resolvedUrl("icons/home-reboot.svg")
                hint: "Обновить последние семь сессий"
                implicitWidth: 36; implicitHeight: 36; padding: 8
                enabled: VoiceSystem.available && !VoiceSystem.listing && !VoiceSystem.busy
                onClicked: VoiceSystem.loadThreads()
            }
        }
        SettingsChoice {
            id: sessionPicker
            Layout.fillWidth: true
            implicitHeight: 44
            font.pixelSize: 15
            model: root.sessionOptions
            hint: "Сессия Codex"
            currentIndex: model.findIndex(row => row.value === VoiceSystem.threadId)
            displayText: VoiceSystem.threadName(VoiceSystem.threadId)
            enabled: VoiceSystem.available && !VoiceSystem.busy
            onActivated: VoiceSystem.selectThread(currentValue)
        }
    }
    UiText {
        Layout.fillWidth: true
        visible: !!VoiceSystem.threadsError || !!VoiceSystem.actionError
        text: VoiceSystem.actionError || VoiceSystem.threadsError
        font.pixelSize: 14; color: Theme.danger
        wrapMode: Text.Wrap; elide: Text.ElideNone
    }
}
