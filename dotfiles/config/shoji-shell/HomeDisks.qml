pragma ComponentBehavior: Bound
import QtQuick

WidgetSurface {
    id: root
    property var disks: []
    implicitWidth: 252; implicitHeight: 120
    radius: 20; border.width: 0
    Column {
        anchors.centerIn: parent
        width: parent.width - 32
        spacing: 12
        Repeater {
            model: 2
            Meter {
                required property int index
                readonly property var disk: root.disks[index] || {}
                width: parent.width
                label: index === 0 ? "SSD" : "HDD"
                reading: disk.mounted && disk.total > 0
                    ? (disk.used / 1073741824).toFixed(0) + " / " + (disk.total / 1073741824).toFixed(0) + " GiB"
                    : disk.mounted === false ? "Не подключён" : "Нет данных"
                fraction: disk.mounted && disk.total > 0 ? disk.used / disk.total : 0
                Accessible.role: Accessible.Indicator
                Accessible.name: label + ": " + reading
            }
        }
    }
}
