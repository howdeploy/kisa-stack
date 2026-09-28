pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    property var receivedProviders: []
    property var providers: [
        { id: "codex", name: "ChatGPT", source: "Codex", state: "loading", windows: [] },
        { id: "grok", name: "Grok", source: "Build", state: "loading", windows: [] },
        { id: "kimi", name: "Kimi", source: "Code", state: "loading", windows: [] }
    ]
    implicitWidth: 286
    implicitHeight: content.implicitHeight + 40
    width: implicitWidth
    height: implicitHeight

    SystemClock { id: clock; precision: SystemClock.Minutes }

    function updateProvider(message) {
        if (!message || !["codex", "grok", "kimi"].includes(message.id) || !Array.isArray(message.windows)) return;
        root.receivedProviders = root.receivedProviders.concat([message.id]);
        root.providers = root.providers.map(provider => {
            if (provider.id !== message.id) return provider;
            if (message.state !== "available" && provider.windows.length)
                return Object.assign({}, provider, { state: message.state });
            return Object.assign({}, provider, message);
        });
    }
    Process {
        id: collector
        running: true
        onStarted: root.receivedProviders = []
        command: ["node", Qt.resolvedUrl("ai-limits.mjs").toString().replace("file://", "")]
        stdout: SplitParser {
            onRead: data => {
                try { root.updateProvider(JSON.parse(data)); }
                catch (error) { console.warn("Invalid AI limits response"); }
            }
        }
        onExited: {
            root.providers = root.providers.map(provider => {
                if (!root.receivedProviders.includes(provider.id))
                    return Object.assign({}, provider, { state: provider.windows.length ? "stale" : "unavailable" });
                return provider;
            });
        }
    }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: { if (!collector.running) collector.running = true; } }

    function stateText(provider) {
        if (provider.state === "stale") return "Данные устарели";
        if (provider.state === "auth") return "Нужен вход в аккаунт";
        if (provider.state === "missing") return "Источник не установлен";
        if (provider.state === "loading") return "Получаю лимиты…";
        if (provider.state === "available") return "Вход выполнен · нет квоты";
        return "Лимиты недоступны";
    }

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: 10
        color: Qt.darker(Theme.surface, 1.12)
        border.width: 1
        border.color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.10)

        // Fixed grain behind the text; only repaint when the surface size changes.
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
                    const y = Math.floor(seed / 4294967296 * height);
                    ctx.fillRect(x, y, 1, 1);
                }
            }
        }

        ColumnLayout {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
            spacing: 18

            Repeater {
                model: root.providers
                delegate: ColumnLayout {
                    id: providerRow
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 10
                    readonly property bool stale: modelData.state !== "available" || !!modelData.fetchedAt && clock.date.getTime() - modelData.fetchedAt > 120000
                    readonly property bool known: modelData.windows.length > 0 && modelData.windows.every(w => typeof w.remaining === "number" && isFinite(w.remaining))
                    readonly property real used: known ? 100 - Math.min.apply(null, modelData.windows.map(w => w.remaining)) : 0
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        UiText { Layout.fillWidth: true; text: providerRow.modelData.name; font.pixelSize: 13; font.weight: Font.Medium }
                        UiText {
                            visible: providerRow.stale || providerRow.modelData.state !== "available" || !providerRow.known
                            text: providerRow.modelData.state === "available" && providerRow.stale ? "Устарело" : root.stateText(providerRow.modelData)
                            font.pixelSize: 10
                            color: Theme.muted
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 3
                        radius: 1.5
                        color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.09)
                        Accessible.name: providerRow.known ? "Потрачено " + Math.floor(providerRow.used) + "%" : root.stateText(providerRow.modelData)
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(100, providerRow.used)) / 100
                            height: parent.height
                            radius: parent.radius
                            color: providerRow.stale ? Theme.line : providerRow.used >= 85 ? Theme.danger : Theme.accent
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: providerRow.known
                        spacing: 4
                        Repeater {
                            model: providerRow.modelData.windows
                            delegate: RowLayout {
                                id: quotaRow
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 8
                                UiText {
                                    Layout.fillWidth: true
                                    text: quotaRow.modelData.label + " · " + Math.floor(100 - quotaRow.modelData.remaining) + "%"
                                    font.pixelSize: 10
                                    color: Theme.muted
                                }
                                UiText {
                                    text: quotaRow.modelData.resetsAt ? "Сброс " + Qt.formatDateTime(new Date(quotaRow.modelData.resetsAt), "dd.MM HH:mm") : "Сброс неизвестен"
                                    font.pixelSize: 10
                                    color: Theme.muted
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
