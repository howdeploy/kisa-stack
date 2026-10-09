pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string error: ""
    readonly property bool starting: launch.running
    function request() {
        if (launch.running) return;
        error = "";
        launch.running = true;
    }
    Process {
        id: launch
        command: ["python3", decodeURIComponent(Qt.resolvedUrl("lock/launch.py").toString().replace("file://", ""))]
        stderr: StdioCollector { id: diagnostics; waitForEnd: true }
        onExited: exitCode => {
            if (exitCode !== 0) root.error = "Не удалось заблокировать экран. " + diagnostics.text.trim();
        }
    }
}
