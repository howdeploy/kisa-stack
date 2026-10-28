pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

Item {
    id: preview
    required property var output
    required property url wallpaperSource
    property var wallpaperFrame: null
    property string stateName: "input"
    readonly property var faceItem: face
    readonly property int imageStatus: face.backgroundStatus
    implicitHeight: width * (output ? output.height / Math.max(1, output.width) : 9 / 16)
    clip: true
    SystemClock { id: clock; precision: SystemClock.Minutes; enabled: preview.visible }
    QtObject {
        id: model
        readonly property string time: Qt.formatDateTime(clock.date, "HH:mm")
        readonly property string date: Qt.formatDateTime(clock.date, "dddd, d MMMM")
        readonly property string user: Quickshell.env("USER") || "Пользователь"
        readonly property bool checking: preview.stateName === "checking"
        readonly property bool failed: preview.stateName === "error"
        readonly property bool locked: true
        readonly property int typed: 6
        readonly property real faceOpacity: 1
        readonly property string status: checking ? "Проверка пароля…" : failed ? "Неверный пароль" : ""
        function displayPassword(reveal) { return "●●●●●●"; }
    }
    LockFace {
        id: face
        output: preview.output
        controller: model
        previewMode: true
        wallpaperSource: preview.wallpaperSource
        wallpaperFrame: preview.wallpaperFrame
        width: preview.output ? preview.output.width : 1920
        height: preview.output ? preview.output.height : 1080
        scale: Math.min(preview.width / Math.max(1, width), preview.height / Math.max(1, height))
        transformOrigin: Item.TopLeft
        x: (preview.width - width * scale) / 2
        y: (preview.height - height * scale) / 2
    }
    // This layer is a display-only preview; no keyboard or pointer input reaches LockFace.
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
}
