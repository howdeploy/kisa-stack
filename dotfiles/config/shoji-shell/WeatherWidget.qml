pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    implicitWidth: 286
    implicitHeight: content.implicitHeight + 32
    width: implicitWidth
    height: implicitHeight
    property alias attributionItem: attribution
    property bool failed: false
    property bool received: false
    property var cities: [
        { name: "First city", temperature: null, time: 0, description: "", icon: "cloud" },
        { name: "Second city", temperature: null, time: 0, description: "", icon: "cloud" }
    ]
    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property bool stale: failed || cities.some(city => city.time > 0 && clock.date.getTime() - city.time > 1800000)

    Process {
        id: collector
        running: true
        command: ["python3", Qt.resolvedUrl("weather.py").toString().replace("file://", "")]
        onStarted: root.received = false
        stdout: SplitParser {
            onRead: data => {
                try {
                    const message = JSON.parse(data);
                    if (!Array.isArray(message.cities) || message.cities.length !== 2) return;
                    root.cities = message.cities;
                    root.received = true;
                    root.failed = false;
                } catch (error) { root.failed = true; }
            }
        }
        onExited: exitCode => { if (exitCode !== 0 || !root.received) root.failed = true; }
    }
    Timer {
        interval: 900000; running: true; repeat: true
        onTriggered: { if (!collector.running) collector.running = true; }
    }

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: 10
        color: Qt.darker(Theme.surface, 1.12)
        border.width: 1
        border.color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.10)
        Canvas {
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.clearRect(0, 0, width, height);
                ctx.beginPath();
                ctx.roundedRect(1, 1, width - 2, height - 2, surface.radius - 1, surface.radius - 1);
                ctx.clip();
                ctx.fillStyle = "white";
                ctx.globalAlpha = 0.045;
                let seed = 173;
                for (let i = 0; i < Math.floor(width * height / 3); i++) {
                    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
                    const x = Math.floor(seed / 4294967296 * width);
                    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
                    ctx.fillRect(x, Math.floor(seed / 4294967296 * height), 1, 1);
                }
            }
        }
    }
    ColumnLayout {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 12
        Repeater {
            model: root.cities
            delegate: RowLayout {
                id: cityRow
                required property var modelData
                Layout.fillWidth: true
                Layout.minimumHeight: 52
                spacing: 12
                readonly property real age: clock.date.getTime() - modelData.time
                readonly property bool known: typeof modelData.temperature === "number"
                    && isFinite(modelData.temperature) && age >= -900000 && age <= 10800000
                readonly property int degrees: known ? Math.round(modelData.temperature) : 0
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true; shadowColor: "black"; shadowOpacity: 1
                    shadowVerticalOffset: 2; shadowBlur: 0.8; blurMax: 8
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    UiText { Layout.fillWidth: true; text: cityRow.modelData.name; font.pixelSize: 16; font.weight: Font.Bold; color: "white" }
                    UiText {
                        Layout.fillWidth: true
                        text: cityRow.known ? cityRow.modelData.description : collector.running && !root.failed ? "Получаю погоду…" : "Нет свежих данных"
                        font.pixelSize: 11; color: "#f2f2f2"
                    }
                }
                PanelIcon {
                    Layout.preferredWidth: 24; Layout.preferredHeight: 24
                    name: cityRow.modelData.icon
                    tint: "white"
                    visible: cityRow.known
                }
                UiText {
                    Layout.minimumWidth: 72
                    horizontalAlignment: Text.AlignRight
                    text: cityRow.known ? (cityRow.degrees > 0 ? "+" : cityRow.degrees < 0 ? "−" : "") + Math.abs(cityRow.degrees) + "°" : "—"
                    color: "white"; font.pixelSize: 32; font.weight: Font.DemiBold
                    Accessible.name: cityRow.modelData.name + ": " + text
                }
            }
        }
        UiText {
            id: attribution
            Layout.fillWidth: true
            text: (root.stale ? "Данные устарели · " : "°C · ") + '<a href="https://open-meteo.com/">Open-Meteo</a>'
            textFormat: Text.StyledText
            font.pixelSize: 10; color: "#cdd6f4"; linkColor: "#cdd6f4"
            style: Text.Raised; styleColor: "black"
            onLinkActivated: link => Qt.openUrlExternally(link)
        }
    }
}
