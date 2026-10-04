pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets

Item {
    id: root
    required property var shell
    implicitWidth: 1468
    implicitHeight: 420
    width: implicitWidth
    height: implicitHeight
    SystemClock { id: clock; precision: SystemClock.Seconds }
    readonly property bool statsFresh: shell.statsAt > 0 && clock.date.getTime() - shell.statsAt < 10000
    readonly property var stats: statsFresh ? shell.stats : ({})
    readonly property bool gameFresh: shell.gameAt > 0 && clock.date.getTime() - shell.gameAt < 6000
    readonly property var game: gameFresh ? shell.game : ({})
    readonly property bool hasFps: typeof game.fps === "number" && isFinite(game.fps) && game.fps >= 0

    function metricValue(id) {
        if (id === "cpu") return stats.cpu;
        if (id === "gpu") return stats.gpu ? stats.gpu.load : null;
        if (id === "ram") return stats.ramTotal ? stats.ramUsed / stats.ramTotal * 100 : null;
        return stats.gpu && stats.gpu.total ? stats.gpu.used / stats.gpu.total * 100 : null;
    }
    function metricDetail(id) {
        if (id === "cpu") return typeof stats.cpuTemperature === "number"
            ? Math.round(stats.cpuTemperature) + " °C" : "Процессор";
        if (id === "gpu") return stats.gpu ? stats.gpu.temperature + " °C" : "Видеокарта";
        if (id === "ram") return stats.ramTotal ? (stats.ramUsed / 1073741824).toFixed(1)
            + " / " + (stats.ramTotal / 1073741824).toFixed(0) + " GiB" : "Память";
        return stats.gpu ? (stats.gpu.used / 1024).toFixed(1)
            + " / " + (stats.gpu.total / 1024).toFixed(0) + " GiB" : "Видеопамять";
    }

    Item {
        width: 700; height: root.height
        Accessible.role: Accessible.Clock
        Accessible.name: Qt.formatDateTime(clock.date, "hh:mm:ss") + ", "
            + clock.date.toLocaleDateString(Qt.locale("ru_RU"), "dddd, d MMMM yyyy")
        Column {
            anchors.centerIn: parent
            width: parent.width - 64
            spacing: 14
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true; shadowColor: "#080810"; shadowOpacity: 1
                shadowVerticalOffset: 3; shadowBlur: 0.8; blurMax: 12
            }
            Item {
                width: parent.width; height: 170
                Row {
                    anchors.centerIn: parent
                    spacing: 12
                    Text {
                        id: hours
                        text: Qt.formatDateTime(clock.date, "hh:mm")
                        color: "white"; font.family: Theme.font
                        font.pixelSize: 144; font.weight: Font.Light
                    }
                    Text {
                        y: hours.height - height - 16
                        text: Qt.formatDateTime(clock.date, ":ss")
                        color: Theme.ink; font.family: Theme.font
                        font.pixelSize: 56; font.weight: Font.Light
                    }
                }
            }
            UiText {
                width: parent.width
                text: clock.date.toLocaleDateString(Qt.locale("ru_RU"), "dddd, d MMMM yyyy")
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 24; color: Theme.ink
            }
        }
    }
    ClippingRectangle {
        x: 724; width: 320; height: 180
        radius: 10
        color: Qt.darker(Theme.surface, 1.12)
        Image {
            id: artwork
            anchors.fill: parent
            source: root.game.art || ""
            asynchronous: true
            sourceSize: Qt.size(640, 360)
            fillMode: root.game.artKind === "logo" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
        }
        Rectangle {
            anchors.fill: parent
            visible: root.hasFps
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: "#99080810" }
            }
        }
        WidgetSurface { anchors.fill: parent; color: "transparent" }
        PanelIcon {
            anchors.centerIn: parent
            width: 40; height: 40; name: "image"; tint: Theme.muted
            visible: artwork.status !== Image.Ready && !root.hasFps
        }
        Column {
            anchors { right: parent.right; bottom: parent.bottom; margins: 16 }
            visible: root.hasFps
            spacing: -6
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true; shadowColor: "#080810"; shadowOpacity: 1
                shadowVerticalOffset: 3; shadowBlur: 0.8; blurMax: 12
            }
            Text {
                anchors.right: parent.right
                text: root.hasFps ? Math.round(root.game.fps) : ""
                font.family: Theme.font; font.pixelSize: 64; font.weight: Font.Bold
                color: "white"; style: Text.Outline; styleColor: "#11111b"
            }
            Text {
                anchors.right: parent.right
                text: "FPS"
                font.family: Theme.font; font.pixelSize: 12; font.letterSpacing: 2
                color: "white"; style: Text.Outline; styleColor: "#11111b"
            }
        }
        Accessible.role: Accessible.Indicator
        Accessible.name: (root.game.name || "Steam") + ": "
            + (root.hasFps ? Math.round(root.game.fps) + " FPS" : "нет данных FPS")
    }
    Repeater {
        model: [
            { id: "cpu", label: "CPU", icon: "home-cpu", accent: "#f5c2e7" },
            { id: "gpu", label: "GPU", icon: "home-gpu", accent: "#fab387" },
            { id: "ram", label: "RAM", icon: "home-memory", accent: "#89b4fa" },
            { id: "vram", label: "VRAM", icon: "home-vram", accent: Theme.accent }
        ]
        WidgetSurface {
            id: metric
            required property int index
            required property var modelData
            readonly property var value: root.metricValue(modelData.id)
            readonly property bool known: typeof value === "number" && isFinite(value)
            x: 724 + (index % 2) * 166
            y: 192 + Math.floor(index / 2) * 120
            width: 154; height: 108
            PanelIcon {
                x: 14; y: 12; width: 20; height: 20
                name: metric.modelData.icon; tint: metric.modelData.accent
            }
            UiText {
                x: 42; y: 14
                text: metric.modelData.label
                font.pixelSize: 10; font.letterSpacing: 1; color: metric.modelData.accent
            }
            UiText {
                x: 14; y: 34
                text: metric.known ? Math.round(metric.value) + "%" : "—"
                font.pixelSize: 30; font.weight: Font.DemiBold; color: Theme.ink
            }
            UiText {
                x: 14; y: 73; width: parent.width - 28
                text: root.metricDetail(metric.modelData.id)
                font.pixelSize: 9; color: Theme.muted
            }
            Rectangle {
                x: 14; y: 94; width: 126; height: 3; radius: 1.5
                color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.09)
                Rectangle {
                    width: parent.width * (metric.known ? Math.max(0, Math.min(100, metric.value)) / 100 : 0)
                    height: parent.height; radius: parent.radius; color: metric.modelData.accent
                }
            }
            Accessible.role: Accessible.Indicator
            Accessible.name: modelData.label + ": "
                + (known ? Math.round(value) + "% " + root.metricDetail(modelData.id) : "нет свежих данных")
        }
    }
    GamingProcessList {
        id: processList
        x: 1068; y: (root.height - height) / 2; width: 400; height: implicitHeight
        processes: root.stats.processes || ({})
        gameAppId: String(root.game.appId || "")
        gameName: root.game.name || ""
        gameArtwork: root.game.art || ""
    }
}
