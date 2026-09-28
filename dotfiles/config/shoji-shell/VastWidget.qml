pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    implicitWidth: 286
    implicitHeight: content.implicitHeight + 32
    width: implicitWidth
    height: implicitHeight
    property var account: ({ state: "loading" })
    property var instances: ({ state: "loading" })
    property var volumes: ({ state: "loading" })
    property var billing: ({ state: "loading" })
    property var rentals: ({ state: "loading", recent: [] })
    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string period: clock.date.getUTCFullYear() + "-" + String(clock.date.getUTCMonth() + 1).padStart(2, "0")
    readonly property string month: ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"][clock.date.getUTCMonth()]
    readonly property bool monthKnown: !!billing.fetchedAt && billing.period === period
    readonly property bool stale: [account, instances, volumes].some(value => value.state === "unavailable"
        || value.fetchedAt && clock.date.getTime() - value.fetchedAt > 120000)
        || [billing, rentals].some(value => value.state === "unavailable"
            || value.fetchedAt && clock.date.getTime() - value.fetchedAt > 1800000)
        || !!billing.fetchedAt && billing.period !== period

    function dollars(value) { return typeof value === "number" && isFinite(value) ? "$" + value.toFixed(2) : "—"; }
    function update(data) {
        try {
            const message = JSON.parse(data);
            if (!["account", "instances", "volumes", "billing", "rentals"].includes(message.kind)) return "";
            if (message.state === "available") root[message.kind] = message;
            else root[message.kind] = Object.assign({}, root[message.kind], { state: "unavailable" });
            return message.kind;
        } catch (error) { console.warn("Invalid Vast widget response"); }
        return "";
    }
    Process {
        id: statusCollector
        property var received: []
        running: true
        command: ["python3", Qt.resolvedUrl("vast-widget.py").toString().replace("file://", ""), "status"]
        onStarted: received = []
        stdout: SplitParser {
            onRead: data => {
                statusCollector.received = statusCollector.received.concat([root.update(data)]);
            }
        }
        onExited: {
            for (const kind of ["account", "instances", "volumes"])
                if (!received.includes(kind)) root[kind] = Object.assign({}, root[kind], { state: "unavailable" });
        }
    }
    Process {
        id: billingCollector
        property var received: []
        running: true
        command: ["python3", Qt.resolvedUrl("vast-widget.py").toString().replace("file://", ""), "billing"]
        onStarted: received = []
        stdout: SplitParser { onRead: data => { billingCollector.received = billingCollector.received.concat([root.update(data)]); } }
        onExited: {
            for (const kind of ["billing", "rentals"])
                if (!received.includes(kind)) root[kind] = Object.assign({}, root[kind], { state: "unavailable" });
        }
    }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: { if (!statusCollector.running) statusCollector.running = true; } }
    Timer { interval: 900000; running: true; repeat: true; onTriggered: { if (!billingCollector.running) billingCollector.running = true; } }

    WidgetSurface { anchors.fill: parent }
    ColumnLayout {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            UiText { text: "Vast.ai"; font.pixelSize: 14; font.weight: Font.DemiBold; Layout.fillWidth: true }
            Rectangle {
                visible: root.stale
                implicitWidth: 6; implicitHeight: 6; radius: 3; color: Theme.danger
                Accessible.role: Accessible.Indicator
                Accessible.name: "Данные устарели"
            }
            UiText { text: root.month; font.pixelSize: 12; color: Theme.muted }
        }
        RowLayout {
            Layout.fillWidth: true
            UiText { text: "БАЛАНС"; font.pixelSize: 12; color: Theme.muted; Layout.fillWidth: true }
            UiText { text: root.dollars(root.account.credit); font.pixelSize: 28; font.weight: Font.Bold; color: "white" }
        }
        RowLayout {
            Layout.fillWidth: true
            UiText { text: "РАСХОД"; font.pixelSize: 12; color: Theme.muted; Layout.fillWidth: true }
            UiText { text: root.monthKnown ? root.dollars(root.billing.total) : "—"; font.pixelSize: 24; font.weight: Font.DemiBold }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            UiText { text: "Инстансы"; font.pixelSize: 12; color: Theme.muted }
            UiText {
                text: root.instances.fetchedAt ? String(root.instances.total) : "—"
                font.pixelSize: 14; font.weight: Font.DemiBold
                Accessible.name: root.instances.fetchedAt ? "Инстансов: " + root.instances.total + ", работают: " + root.instances.running : "Инстансы: нет данных"
            }
            Item { Layout.fillWidth: true }
            UiText { text: "Тома"; font.pixelSize: 12; color: Theme.muted }
            UiText { text: root.volumes.fetchedAt ? String(root.volumes.total) : "—"; font.pixelSize: 14; font.weight: Font.DemiBold }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.10) }
        Repeater {
            model: root.rentals.recent
            delegate: RowLayout {
                id: rentalRow
                required property var modelData
                Layout.fillWidth: true
                spacing: 8
                UiText { Layout.fillWidth: true; text: rentalRow.modelData.label; font.pixelSize: 13 }
                UiText { text: root.dollars(rentalRow.modelData.amount); font.pixelSize: 13; font.weight: Font.Medium }
            }
        }
        UiText {
            visible: !root.rentals.recent.length
            text: "—"
            font.pixelSize: 13; color: Theme.muted
        }
    }
}
