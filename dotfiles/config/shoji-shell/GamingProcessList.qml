pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell

WidgetSurface {
    id: root
    property var processes: ({})
    property string gameAppId: ""
    property string gameName: ""
    property url gameArtwork: ""
    readonly property var rows: processes.ranked || []
    implicitWidth: 400; implicitHeight: 352
    border.color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.14)

    function iconFor(value) {
        if (value.appId) {
            const gameIcon = Quickshell.iconPath("steam_icon_" + value.appId, true);
            if (gameIcon) return gameIcon;
            if (value.appId === gameAppId && gameArtwork.toString()) return gameArtwork;
        }
        const aliases = { brave: "brave-browser", ghostty: "com.mitchellh.ghostty",
            quickshell: "org.quickshell", telegram: "org.telegram.desktop", obs: "com.obsproject.Studio",
            codex: "codex-desktop", chrome: "google-chrome", chromium: "chromium" };
        const entry = Dock.lookup(aliases[value.key] || value.name);
        if (entry && entry.icon) return Dock.iconFor(entry, value.name);
        if (value.icon && value.icon !== "applications" && value.icon !== "home-gpu")
            return Qt.resolvedUrl("icons/" + value.icon + ".svg");
        return Quickshell.iconPath(String(value.name).toLowerCase(), "application-x-executable");
    }

    UiText { x: 16; y: 16; text: "ПРИЛОЖЕНИЕ"; font.pixelSize: 9; color: Theme.ink; font.letterSpacing: 1 }
    UiText { x: 206; y: 16; width: 48; text: "CPU"; font.pixelSize: 9; color: Theme.ink; horizontalAlignment: Text.AlignRight }
    UiText { x: 262; y: 16; width: 48; text: "GPU"; font.pixelSize: 9; color: Theme.ink; horizontalAlignment: Text.AlignRight }
    UiText { x: 318; y: 16; width: 66; text: "RAM"; font.pixelSize: 9; color: Theme.ink; horizontalAlignment: Text.AlignRight }
    Column {
        x: 16; y: 43; width: parent.width - 32
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true; shadowColor: "#080810"; shadowOpacity: 1
            shadowVerticalOffset: 1; shadowBlur: 0.5; blurMax: 6
        }
        Repeater {
            model: root.rows
            Item {
                id: row
                required property var modelData
                width: 368; height: 52
                readonly property string displayName: modelData.appId && modelData.appId === root.gameAppId && root.gameName
                    ? root.gameName : modelData.name
                Rectangle { x: -3; y: 1; width: 30; height: 30; radius: 7; color: Theme.ink }
                Image {
                    id: appIcon
                    x: 0; y: 4; width: 24; height: 24
                    source: root.iconFor(row.modelData); sourceSize: Qt.size(48, 48)
                    asynchronous: true; fillMode: Image.PreserveAspectFit
                }
                PanelIcon { x: 0; y: 4; width: 24; height: 24; name: "applications"; tint: Theme.surface; visible: appIcon.status === Image.Error || appIcon.status === Image.Null }
                UiText { x: 32; y: 0; width: 146; text: row.displayName; font.pixelSize: 12; font.weight: Font.DemiBold; color: "white" }
                UiText { x: 32; y: 21; width: 146; text: "Процессов: " + row.modelData.count; font.pixelSize: 9; color: Theme.ink }
                UiText {
                    x: 190; y: 0; width: 48
                    text: typeof row.modelData.cpu === "number" ? row.modelData.cpu.toFixed(1) + "%" : "—"
                    font.pixelSize: 12; horizontalAlignment: Text.AlignRight
                    color: "white"; font.weight: Font.Medium
                }
                UiText {
                    x: 246; y: 0; width: 48
                    text: typeof row.modelData.gpu === "number" ? row.modelData.gpu.toFixed(1) + "%" : "—"
                    font.pixelSize: 12; horizontalAlignment: Text.AlignRight; color: "white"; font.weight: Font.Medium
                }
                UiText {
                    x: 302; y: 0; width: 66
                    text: row.modelData.rss >= 1073741824 ? (row.modelData.rss / 1073741824).toFixed(1) + " GiB"
                        : Math.round(row.modelData.rss / 1048576) + " MiB"
                    font.pixelSize: 12; horizontalAlignment: Text.AlignRight
                    color: "white"; font.weight: Font.Medium
                }
                Accessible.role: Accessible.ListItem
                Accessible.name: displayName + ", процессов " + modelData.count + ", CPU "
                    + (typeof modelData.cpu === "number" ? modelData.cpu.toFixed(1) + "%" : "нет данных")
                    + ", GPU " + (typeof modelData.gpu === "number" ? modelData.gpu.toFixed(1) + "%" : "нет данных")
                    + ", RAM RSS " + (modelData.rss / 1048576).toFixed(0) + " MiB"
            }
        }
    }
    UiText {
        x: 16; y: (parent.height - height) / 2; width: parent.width - 32
        visible: !root.rows.length; text: "Нет данных"; color: Theme.muted
        horizontalAlignment: Text.AlignHCenter
    }
}
