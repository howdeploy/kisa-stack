pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property bool enabled: Settings.enabled("voice")
    readonly property string backend: Qt.resolvedUrl("voice-status.py").toString().replace("file://", "")
    property var snapshot: ({})
    property double receivedAt: 0
    property double now: Date.now()
    property int revision: 0
    property string actionError: ""
    property var threads: []
    property string threadsError: ""
    readonly property bool stale: !receivedAt || now - receivedAt > 10000
    readonly property bool available: enabled && !stale && snapshot.available === true
    readonly property bool busy: action.running
    readonly property bool listing: threadCollector.running
    readonly property string mode: available ? snapshot.mode || "" : ""
    readonly property string threadId: snapshot.threadId || ""
    readonly property string modeLabel: mode === "window" ? "Активное окно" : mode === "codex" ? "Агент" : "Нет данных"

    function item(key) {
        return !stale && snapshot[key] ? snapshot[key] : { state: "unknown", detail: "Нет свежих данных" };
    }
    function label(value) {
        return value === "ready" ? "Готово" : value === "connecting" ? "Подключается"
            : value === "unavailable" ? "Недоступно" : "Нет данных";
    }
    function tint(value) {
        return value === "ready" ? Theme.accent : value === "unavailable" ? Theme.danger
            : value === "connecting" ? Theme.ink : Theme.muted;
    }
    function refresh() { if (enabled && !collector.running) collector.running = true; }
    function change(args) {
        if (!available || busy) return;
        revision++;
        actionError = "";
        action.command = ["python3", backend].concat(args);
        action.running = true;
    }
    function setMode(value) { if (value !== mode) change(["set_mode", "--mode", value]); }
    function selectThread(value) { if (value !== threadId) change(["select_thread", "--thread-id", value]); }
    function threadName(id) {
        if (!id) return "Без Codex";
        const thread = threads.find(t => t.id === id);
        if (!thread || !thread.name || thread.name === id) return "Сессия · " + id.slice(0, 8);
        const duplicate = threads.some(t => t.id !== id && t.name === thread.name);
        return thread.name + (duplicate ? " · " + id.slice(0, 8) : "");
    }
    function loadThreads() {
        if (!available || listing || busy) return;
        threadCollector.command = ["python3", Qt.resolvedUrl("voice-status.py").toString().replace("file://", ""), "threads"];
        threadsError = "";
        threadCollector.running = true;
    }
    Process {
        id: collector
        property bool received: false
        property int requestRevision: 0
        running: root.enabled
        command: ["python3", Qt.resolvedUrl("voice-status.py").toString().replace("file://", "")]
        onStarted: { received = false; requestRevision = root.revision; }
        stdout: SplitParser {
            onRead: data => {
                if (collector.requestRevision !== root.revision) return;
                try {
                    const value = JSON.parse(data);
                    if (typeof value.available !== "boolean" || !value.input) return;
                    root.snapshot = value.available ? value : Object.assign({}, value, { threadId: root.threadId });
                    root.receivedAt = Date.now();
                    root.now = Date.now();
                    collector.received = true;
                } catch (error) { /* Invalid output never confirms readiness. */ }
            }
        }
        onExited: { if (!received && requestRevision === root.revision) root.receivedAt = 0; }
    }
    Process {
        id: action
        property bool acknowledged: false
        onStarted: acknowledged = false
        stderr: SplitParser { onRead: data => {} }
        stdout: SplitParser {
            onRead: data => {
                try { action.acknowledged = JSON.parse(data).version === 1; }
                catch (error) { action.acknowledged = false; }
            }
        }
        onExited: {
            root.revision++;
            if (!acknowledged) root.actionError = "Изменение не подтверждено";
            root.refresh();
        }
    }
    Process {
        id: threadCollector
        property bool received: false
        onStarted: received = false
        stdout: SplitParser {
            onRead: data => {
                try {
                    const page = JSON.parse(data);
                    if (!Array.isArray(page.threads)) return;
                    const rows = page.threads.filter(t => typeof t.id === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(t.id));
                    root.threads = rows.filter((t, i, all) => all.findIndex(other => other.id === t.id) === i).slice(0, 7);
                    threadCollector.received = true;
                } catch (error) { /* Preserve the current selection on a malformed page. */ }
            }
        }
        onExited: { if (!received) root.threadsError = "Список сессий недоступен"; }
    }
    Timer { interval: 3000; running: root.enabled; repeat: true; onTriggered: { root.now = Date.now(); root.refresh(); } }
    Timer { interval: 5000; running: collector.running; onTriggered: collector.running = false }
    Timer { interval: 25000; running: action.running; onTriggered: action.running = false }
    Timer { interval: 25000; running: threadCollector.running; onTriggered: threadCollector.running = false }
}
