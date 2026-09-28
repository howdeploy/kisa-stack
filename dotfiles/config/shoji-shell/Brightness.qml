import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property string connector: ""
    property bool active: false
    property bool available: false
    property real value: 0
    property string error: ""
    readonly property bool busy: worker.running
    function query(mode, percentage) {
        if (worker.running) return;
        worker.command = ["python3", Qt.resolvedUrl("brightness.py").toString().replace("file://", ""), mode, connector];
        if (mode === "set") worker.command = worker.command.concat([String(percentage)]);
        worker.running = true;
    }
    onActiveChanged: { if (active) query("get", 0); }
    onConnectorChanged: { available = false; if (active) query("get", 0); }
    Process {
        id: worker
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    root.available = result.available;
                    root.value = result.value;
                    root.error = result.error;
                } catch (error) { root.available = false; root.error = "Не удалось прочитать яркость"; }
            }
        }
    }
}
