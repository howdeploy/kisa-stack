//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QT_WAYLAND_USE_DATA_CONTROL=1
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
    property double statsAt: 0
    property bool statsReady: false
    property var game: ({})
    property double gameAt: 0
    readonly property bool processStatsWanted: Wallpapers.ready && !!WidgetLayouts.outputFor("gaming-home")
    onProcessStatsWantedChanged: {
        if (statsReady && statsProcess && statsProcess.running)
            statsProcess.write(JSON.stringify({ processes: processStatsWanted }) + "\n");
    }
    IpcHandler {
        target: "wallpaper"
        function toggle(outputName: string): void { Wallpapers.toggle(outputName); }
        function cancel(): void { Wallpapers.cancel(); }
        function status(): string {
            return JSON.stringify({ ready: Wallpapers.ready, saving: Wallpapers.saving,
                busy: LiveWallpapers.busy, active: LiveWallpapers.active,
                pickerRequested: Wallpapers.targetOutput !== "", error: Wallpapers.error });
        }
    }
    Connections {
        target: Wallpapers
        function onTargetOutputChanged(): void { if (Wallpapers.targetOutput !== "") root.panelPage = ""; }
    }
    Connections {
        target: ScreenShaders
        function onTargetOutputChanged(): void { if (ScreenShaders.targetOutput !== "") root.panelPage = ""; }
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
        running: Wallpapers.ready && !!WidgetLayouts.outputFor("gaming-home")
        command: ["python3", Qt.resolvedUrl("game-fps").toString().replace("file://", ""), "--watch"]
        onRunningChanged: { if (!running) { root.game = ({}); root.gameAt = 0; } }
        stdout: SplitParser {
            onRead: data => {
                try { root.game = JSON.parse(data); root.gameAt = Date.now(); }
                catch (error) { console.warn("Game telemetry:", error); }
            }
        }
    }
    Process {
        id: statsProcess
        stdinEnabled: true
        onRunningChanged: { if (!running) root.statsReady = false; }
        running: (root.panelPage === "controls" && root.panelReady)
            || (Wallpapers.ready && WidgetLayouts.enabledOn("home", root.primaryOutput))
            || (Wallpapers.ready && !!WidgetLayouts.outputFor("gaming-home"))
        command: ["python3", Qt.resolvedUrl("system-stats.py").toString().replace("file://", "")]
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.stats = JSON.parse(data); root.statsAt = Date.now();
                    if (root.stats.telemetryReady) {
                        root.statsReady = true;
                        statsProcess.write(JSON.stringify({ processes: root.processStatsWanted }) + "\n");
                    }
                }
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
            shell: root
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
    Variants {
        model: Quickshell.screens
        SnowLayer {
            required property var modelData
            output: modelData
        }
    }
}
