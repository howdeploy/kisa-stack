pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "HomeCalendar.js" as Dates

WidgetSurface {
    id: root
    implicitWidth: 288; implicitHeight: 168
    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property var days: Dates.fortnight(clock.date)
    readonly property var months: ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"]
    readonly property string heading: days[0].getFullYear() !== days[13].getFullYear()
        ? months[days[0].getMonth()] + " " + days[0].getFullYear() + " — " + months[days[13].getMonth()] + " " + days[13].getFullYear()
        : months[days[0].getMonth()] + (days[0].getMonth() !== days[13].getMonth() ? " — " + months[days[13].getMonth()] : "") + " · " + days[0].getFullYear()
    UiText {
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 16 }
        text: root.heading; font.pixelSize: 13; font.weight: Font.DemiBold
    }
    Grid {
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 12; rightMargin: 12; topMargin: 48 }
        columns: 7; rowSpacing: 3
        Repeater {
            model: ["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "ВС"]
            UiText {
                required property string modelData
                width: (root.width - 24) / 7; height: 20
                text: modelData; font.pixelSize: 10; color: Theme.muted
                horizontalAlignment: Text.AlignHCenter
            }
        }
        Repeater {
            model: root.days
            Item {
                id: day
                required property var modelData
                readonly property bool today: Dates.sameDay(modelData, clock.date)
                width: (root.width - 24) / 7; height: 33
                Rectangle {
                    anchors.centerIn: parent
                    width: 30; height: 30; radius: 10
                    color: day.today ? Theme.accent : "transparent"
                }
                UiText {
                    anchors.centerIn: parent
                    text: day.modelData.getDate()
                    font.pixelSize: 13; font.weight: day.today ? Font.Bold : Font.Normal
                    color: day.today ? Theme.surface : day.modelData.getDay() === 0 || day.modelData.getDay() === 6 ? "#f5c2e7" : Theme.ink
                }
                Accessible.role: Accessible.StaticText
                Accessible.name: Qt.formatDateTime(modelData, "dd.MM.yyyy") + (today ? ", сегодня" : "")
            }
        }
    }
}
