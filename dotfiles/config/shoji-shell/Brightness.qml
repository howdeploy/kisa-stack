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
    property var buses: ({})
    readonly property bool busy: worker.running
    function query(mode, percentage) {
        if (worker.running) return;
        worker.command = ["python3", Qt.resolvedUrl("brightness.py").toString().replace("file://", ""), mode, connector,
            String(percentage), buses[connector] || ""];
        worker.running = true;
    }
    onActiveChanged: { if (active) query("get", 0); }
    onConnectorChanged: { available = false; if (active) query("get", 0); }
    Connections {
        target: Quickshell
        function onScreensChanged(): void { root.buses = ({}); if (root.active) root.query("get", 0); }
    }
    Process {
        id: worker
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    if (result.available) root.buses[result.connector] = result.bus;
                    else root.buses = ({});
                    if (result.connector && result.connector !== root.connector) {
                        if (root.active) Qt.callLater(() => root.query("get", 0));
                        return;
                    }
                    root.available = result.available;
                    root.value = result.value;
                    root.error = result.error;
                } catch (error) { root.available = false; root.error = "Не удалось прочитать яркость"; }
            }
        }
    }
}
