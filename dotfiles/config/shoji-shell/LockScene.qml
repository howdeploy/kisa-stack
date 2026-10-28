pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool active: false
    property bool available: false
    property var backgroundOutputs: []
    property string phase: "idle"
    property int generation: 0
    readonly property bool preparing: phase === "preparing"
    signal prepared()
    signal failed()

    function backgroundFor(name) { return available && active && backgroundOutputs.includes(name); }
    function send(id, method, params) {
        const socket = connection.item;
        if (!socket || !socket.connected) return false;
        socket.write(JSON.stringify({ id: id, method: method, params: params || {} }) + "\n");
        socket.flush();
        return true;
    }
    function refresh() { send("scene", "lock.scene"); }
    function cancel() {
        send("cancel", "lock.release.cancel");
        deadline.stop();
        phase = "idle";
        generation = 0;
    }
    function abort() {
        const beforeUnlock = preparing;
        cancel();
        if (beforeUnlock) failed();
    }
    function prepare() {
        cancel();
        if (!available) { failed(); return; }
        phase = "preparing";
        deadline.interval = 1500;
        deadline.restart();
        if (!send("prepare", "lock.release.prepare")) abort();
    }
    function start() {
        phase = "starting";
        deadline.interval = 1100;
        deadline.restart();
        send("start", "lock.release.start", { generation: generation });
    }
    onActiveChanged: { if (active) refresh(); }

    Loader {
        id: connection
        sourceComponent: Component {
            Socket {
                path: Quickshell.env("XDG_RUNTIME_DIR") + "/shojiwm-" + Quickshell.env("WAYLAND_DISPLAY") + ".sock"
                connected: true
                onConnectionStateChanged: {
                    root.available = false;
                    root.backgroundOutputs = [];
                    if (!connected) root.abort();
                    else if (root.active) root.refresh();
                }
                parser: SplitParser {
                    onRead: data => {
                        try {
                            const message = JSON.parse(data);
                            const result = message.result;
                            if (message.id === "scene") {
                                root.available = !!result && result.native === true;
                                root.backgroundOutputs = root.available && Array.isArray(result.backgroundOutputs)
                                    ? result.backgroundOutputs.filter(name => typeof name === "string") : [];
                            } else if (message.id === "prepare" && root.preparing) {
                                if (!result || !Number.isSafeInteger(result.generation)) root.abort();
                                else root.generation = result.generation;
                            } else if (message.id === "status" && root.preparing) {
                                if (message.error || !result || result.generation !== root.generation || result.state === "failed") root.abort();
                                else if (result.state === "ready") {
                                    root.phase = "ready";
                                    deadline.stop();
                                    root.prepared();
                                }
                            } else if (message.id === "start" && root.phase === "starting" && result && result.started === true) {
                                root.phase = "playing";
                            }
                        } catch (error) { console.warn("Lock scene response rejected"); root.abort(); }
                    }
                }
            }
        }
    }
    Timer {
        interval: 500; repeat: true; running: root.active
        onTriggered: root.refresh()
    }
    Timer {
        interval: 50; repeat: true; running: root.preparing || root.phase === "starting"
        onTriggered: {
            if (!root.generation) return;
            if (root.preparing) root.send("status", "lock.release.status", { generation: root.generation });
            else root.send("start", "lock.release.start", { generation: root.generation });
        }
    }
    Timer { id: deadline; onTriggered: root.abort() }
    Timer {
        interval: 1000; repeat: true
        running: !connection.item || !connection.item.connected
        onTriggered: { connection.active = false; connection.active = true; }
    }
}
