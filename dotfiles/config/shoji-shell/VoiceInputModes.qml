pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    spacing: 6
    Repeater {
        model: [
            { mode: "codex", icon: "session-codex", label: "Ввод в агента" },
            { mode: "window", icon: "settings-monitor", label: "Ввод в активное окно" }
        ]
        delegate: ActionButton {
            required property var modelData
            implicitWidth: 46; implicitHeight: 40
            padding: 9
            display: AbstractButton.IconOnly
            icon.source: Qt.resolvedUrl("icons/" + modelData.icon + ".svg")
            icon.width: 22; icon.height: 22
            icon.color: highlighted ? Theme.surface : Theme.muted
            hint: modelData.label
            highlighted: VoiceSystem.mode === modelData.mode
            enabled: VoiceSystem.available && !VoiceSystem.busy
            Accessible.role: Accessible.RadioButton
            Accessible.checkable: true
            Accessible.checked: highlighted
            onClicked: VoiceSystem.setMode(modelData.mode)
        }
    }
}
