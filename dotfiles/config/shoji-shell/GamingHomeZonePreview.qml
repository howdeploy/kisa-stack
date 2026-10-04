pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects

Item {
    id: root
    readonly property real ratio: width / 1468
    Item {
        width: 1468; height: 420
        scale: root.ratio
        transformOrigin: Item.TopLeft
        Item {
            width: 700; height: 420
            Column {
                anchors.centerIn: parent; spacing: 14
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true; shadowColor: "#080810"; shadowOpacity: 1
                    shadowVerticalOffset: 3; shadowBlur: 0.8; blurMax: 12
                }
                Row {
                    spacing: 12
                    Text { id: hours; text: "12:34"; color: "white"; font.family: Theme.font; font.pixelSize: 144; font.weight: Font.Light }
                    Text { y: hours.height - height - 16; text: ":56"; color: Theme.ink; font.family: Theme.font; font.pixelSize: 56; font.weight: Font.Light }
                }
                UiText { anchors.horizontalCenter: parent.horizontalCenter; text: "сегодня"; font.pixelSize: 24; color: Theme.ink }
            }
        }
        WidgetSurface {
            x: 724; width: 320; height: 180
            PanelIcon { anchors.centerIn: parent; width: 40; height: 40; name: "image"; tint: Theme.muted }
        }
        Repeater {
            model: [
                { label: "CPU", icon: "home-cpu", accent: "#f5c2e7" },
                { label: "GPU", icon: "home-gpu", accent: "#fab387" },
                { label: "RAM", icon: "home-memory", accent: "#89b4fa" },
                { label: "VRAM", icon: "home-vram", accent: Theme.accent }
            ]
            WidgetSurface {
                id: metric
                required property int index
                required property var modelData
                x: 724 + (index % 2) * 166; y: 192 + Math.floor(index / 2) * 120
                width: 154; height: 108
                PanelIcon { x: 14; y: 12; width: 20; height: 20; name: metric.modelData.icon; tint: metric.modelData.accent }
                UiText { x: 42; y: 14; text: metric.modelData.label; font.pixelSize: 10; font.letterSpacing: 1; color: metric.modelData.accent }
                UiText { x: 14; y: 34; text: "—"; font.pixelSize: 30; color: Theme.ink }
                Rectangle { x: 14; y: 94; width: 126; height: 3; radius: 1.5; color: Theme.raised }
            }
        }
        GamingProcessList { x: 1068; y: (parent.height - height) / 2; width: 400; height: implicitHeight; enabled: false }
    }
}
