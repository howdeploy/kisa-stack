pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    property bool showSubscription: false
    spacing: 6
    Repeater {
        model: [
            { key: "ha", title: "Home Assistant" },
            { key: "speaker", title: "Яндекс Станция" },
            { key: "input", title: "GigaAM" },
            { key: "speech", title: "Синтез речи" },
            { key: "codex", title: "Codex" }
        ].concat(root.showSubscription ? [{ key: "speechCodex", title: "Ответы Codex" }] : [])
        delegate: RowLayout {
            id: service
            required property var modelData
            readonly property var health: VoiceSystem.item(modelData.key)
            Layout.fillWidth: true
            Layout.minimumHeight: 34
            spacing: 12
            UiText { Layout.fillWidth: true; text: service.modelData.title; font.pixelSize: 16 }
            HomeStatusIcon { status: service.health.state; description: service.modelData.title + ". " + service.health.detail }
        }
    }
}
