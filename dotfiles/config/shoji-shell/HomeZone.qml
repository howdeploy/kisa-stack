pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

Item {
    id: root
    required property var shell
    required property var output
    implicitWidth: 852; implicitHeight: 690
    width: implicitWidth; height: implicitHeight
    SystemClock { id: clock; precision: SystemClock.Seconds }
    readonly property bool fresh: shell.statsAt > 0 && clock.date.getTime() - shell.statsAt < 10000
    readonly property var stats: fresh ? shell.stats : ({})
    HomeClock { x: 36; y: 0; width: 780; height: 228 }
    HomeSystemCard {
        x: 0; y: 242; width: 252; height: 170
        radius: 22; border.width: 0
        onSettingsRequested: root.shell.toggle(root.output.name, "controls")
    }
    HomeCalendar {
        x: 270; y: 266; width: 276; height: 170
        radius: 20; border.width: 0
    }
    MusicWidget {
        x: 564; y: 234; width: 288; height: 206
        compact: true
    }
    Item {
        x: 4; y: 430; width: 248; height: 116
        HomeStat {
            x: 0; width: 76; height: 104; label: "CPU"; value: root.stats.cpu; accent: "#f5c2e7"
            detail: typeof root.stats.cpuTemperature === "number" && isFinite(root.stats.cpuTemperature)
                ? Math.round(root.stats.cpuTemperature) + " °C" : "— °C"
        }
        HomeStat { x: 86; y: 12; width: 76; height: 104; label: "GPU"; value: root.stats.gpu ? root.stats.gpu.load : null; detail: root.stats.gpu ? root.stats.gpu.temperature + " °C" : "Нет данных"; accent: "#fab387" }
        HomeStat { x: 172; width: 76; height: 104; label: "RAM"; value: root.stats.ramTotal ? root.stats.ramUsed / root.stats.ramTotal * 100 : null; detail: root.stats.ramTotal ? (root.stats.ramUsed / 1073741824).toFixed(1) + " GiB" : "Память"; accent: "#89b4fa" }
    }
    HomeDisks { x: 0; y: 562; width: 252; height: 120; disks: root.stats.disks || [] }
    HomeAccounts { x: 270; y: 454; width: 582; height: 228 }
}
