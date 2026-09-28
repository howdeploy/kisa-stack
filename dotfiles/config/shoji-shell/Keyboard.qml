pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool available: false
    property int owner: 0
    property int index: -1
    property string name: ""
    readonly property string shortName: name.startsWith("English") ? "EN" : name.startsWith("Russian") ? "RU" : name.slice(0, 2).toUpperCase()
    readonly property string label: shortName === "EN" ? "English" : shortName === "RU" ? "Русский" : name
    function accept(data) {
        if (!Number.isInteger(data.pid) || !Number.isInteger(data.index) || typeof data.name !== "string" || !data.name) return;
        const changed = available && owner === data.pid && (index !== data.index || name !== data.name);
        owner = data.pid;
        index = data.index;
        name = data.name;
        available = true;
        if (changed) Osd.showLayout(shortName + " · " + label);
    }
    FileView {
        id: status
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/shojiwm-" + Quickshell.env("WAYLAND_DISPLAY") + "-keyboard.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.accept(JSON.parse(text())); } catch (error) { root.available = false; } }
        onLoadFailed: root.available = false
    }
    // The file is absent until a compositor with layout status support starts.
    Timer { interval: 2000; repeat: true; running: !root.available; onTriggered: status.reload() }
}
