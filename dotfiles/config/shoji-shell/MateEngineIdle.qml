pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root
    property int revision: -1
    property bool reportedIdle: false
    property double responseAt: 0

    IdleMonitor {
        id: idle
        enabled: false
        timeout: 30
        respectInhibitors: true
        onIsIdleChanged: {
            root.reportedIdle = isIdle;
            if (socket.connected) socket.refresh();
        }
    }
    Socket {
        id: socket
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/shojiwm-" + Quickshell.env("WAYLAND_DISPLAY") + ".sock"
        connected: true
        function refresh() {
            write(JSON.stringify({ id: 1, method: "mateengine.idle",
                params: { revision: root.revision, idle: root.reportedIdle } }) + "\n");
            flush();
        }
        onConnectionStateChanged: {
            idle.enabled = false;
            root.reportedIdle = false;
            root.revision = -1;
            if (connected) refresh();
        }
        parser: SplitParser {
            onRead: data => {
                try {
                    const message = JSON.parse(data);
                    if (message.id !== 1 || !message.result) return;
                    const state = message.result;
                    if (!Number.isSafeInteger(state.revision) || typeof state.enabled !== "boolean" ||
                        !Number.isInteger(state.timeout) || state.timeout < 30 || state.timeout > 10800) return;
                    root.responseAt = Date.now();
                    if (root.revision !== state.revision) {
                        idle.enabled = false;
                        root.reportedIdle = false;
                        root.revision = state.revision;
                        idle.timeout = state.timeout;
                    }
                    idle.enabled = state.enabled;
                } catch (error) { console.warn("MateEngine idle:", error); }
            }
        }
    }
    Timer {
        interval: 500; repeat: true; running: socket.connected
        onTriggered: {
            if (Date.now() - root.responseAt > 1500) {
                idle.enabled = false;
                root.reportedIdle = false;
            }
            socket.refresh();
        }
    }
    Timer { interval: 1000; repeat: true; running: !socket.connected; onTriggered: socket.connected = true }
}
