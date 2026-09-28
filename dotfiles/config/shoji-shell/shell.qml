//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma IconTheme Shoji
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root
    property string primaryOutputName: WidgetLayouts.primaryOutputName
    readonly property var primaryOutput: Quickshell.screens.find(screen => screen.name === primaryOutputName)
        || Quickshell.screens[0] || null
    property string panelScreen: ""
    property string panelPage: ""
    property bool panelReady: false
    property var stats: ({})
    IpcHandler {
        target: "wallpaper"
        function toggle(outputName: string): void { Wallpapers.toggle(outputName); }
        function cancel(): void { Wallpapers.cancel(); }
    }
    Connections {
        target: Wallpapers
        function onTargetOutputChanged(): void { if (Wallpapers.targetOutput !== "") root.panelPage = ""; }
    }
    function toggle(screenName, page) {
        if (panelScreen === screenName && panelPage === page) {
            panelPage = "";
        } else {
            panelScreen = screenName;
            panelPage = page;
            Notifications.toast = null;
        }
    }
    Process {
        running: root.panelPage === "controls" && root.panelReady
        command: ["python3", Qt.resolvedUrl("system-stats.py").toString().replace("file://", "")]
        stdout: SplitParser {
            onRead: data => {
                try { root.stats = JSON.parse(data); }
                catch (error) { console.warn("System telemetry:", error); }
            }
        }
    }
    // Backgrounds belong to every output; desktop controls stay on the primary.
    Variants {
        model: Quickshell.screens
        WallpaperScreen {
            required property var modelData
            output: modelData
        }
    }
    HermesHud {
        output: WidgetLayouts.outputFor("hermes") || root.primaryOutput
        layoutEnabled: Wallpapers.ready && WidgetLayouts.enabledOn("hermes", output)
        placement: WidgetLayouts.placement("hermes")
    }
    Variants {
        model: root.primaryOutput ? [root.primaryOutput] : []
        ScreenShell {
            required property var modelData
            output: modelData
            shell: root
        }
    }
}
