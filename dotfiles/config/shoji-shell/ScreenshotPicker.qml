pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: picker
    property bool opened: false
    property bool preparing: false
    property var previousToplevels: []
    property string targetOutput: ""
    property string windowGeometry: ""
    property var pendingCommand: []
    property string captureError: ""
    property string captureMode: ""
    readonly property string scripts: Settings.configHome + "/shojiwm/scripts"
    readonly property var targetScreen: Quickshell.screens.find(s => s.name === targetOutput) || null
    screen: targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    visible: frozenFrame.hasContent && !!targetScreen && !Lock.locked
    color: "transparent"
    surfaceFormat.opaque: false
    exclusionMode: ExclusionMode.Ignore
    mask: Region { item: picker.opened ? controls : null }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shoji-screenshot-picker"
    WlrLayershell.keyboardFocus: visible && opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    onOpenedChanged: { if (opened) Qt.callLater(() => { if (picker.visible && picker.opened) flameshotButton.forceActiveFocus(); }); }
    onTargetScreenChanged: { if (!targetScreen) cancel(); }

    function cancel() {
        opened = false;
        preparing = false;
        captureDelay.stop();
        prepareTimeout.stop();
        pendingCommand = [];
        releaseFrame();
    }
    function releaseFrame() {
        handoffTimeout.stop();
        frozenFrame.captureSource = null;
        previousToplevels = [];
    }
    function frameReady() {
        if (!preparing || !frozenFrame.hasContent || Lock.locked) return;
        prepareTimeout.stop();
        preparing = false;
        opened = true;
    }
    function editorReady(toplevel) {
        if (opened || preparing || captureDelay.running || !captureProcess.running
                || captureMode !== "region" || !toplevel || previousToplevels.includes(toplevel)) return;
        // Flameshot captures its image before mapping the editor window.
        if (/(^|\.)flameshot$/i.test(toplevel.appId || "")) releaseFrame();
    }
    function capture(mode) {
        if (!visible || captureProcess.running || (mode === "window" && windowGeometry === "")) return;
        captureMode = mode;
        captureError = "";
        previousToplevels = ToplevelManager.toplevels.values.slice();
        pendingCommand = mode === "ocr"
            ? [scripts + "/screenshot-ocr"]
            : mode === "region"
                ? [scripts + "/screenshot-region", targetOutput]
                : [scripts + "/screenshot-all", "-g", windowGeometry];
        opened = false;
        // Hide only the buttons; the frozen frame remains for the capture tools.
        captureDelay.restart();
    }
    IpcHandler {
        target: "screenshot"
        function toggle(outputName: string, geometry: string): void {
            if (picker.opened || picker.preparing) { picker.cancel(); return; }
            if (Lock.locked || captureDelay.running || captureProcess.running) return;
            picker.targetOutput = outputName;
            picker.windowGeometry = geometry;
            if (!picker.targetScreen) return;
            picker.preparing = true;
            prepareTimeout.restart();
            // Capture before mapping the picker or taking focus from an app menu.
            frozenFrame.captureSource = picker.targetScreen;
        }
    }
    Connections {
        target: Lock
        function onLockedChanged(): void { if (Lock.locked) picker.cancel(); }
    }
    ScreencopyView {
        id: frozenFrame
        anchors.fill: parent
        live: false
        paintCursor: false
        onHasContentChanged: picker.frameReady()
    }
    Timer {
        id: prepareTimeout
        interval: 3000
        onTriggered: {
            picker.cancel();
            Quickshell.execDetached(["notify-send", "Скриншот", "Не удалось заморозить экран."]);
        }
    }
    Timer {
        id: handoffTimeout
        // Release the cover if Flameshot fails to map after its 30s portal timeout.
        interval: 35000
        onTriggered: picker.releaseFrame()
    }
    Instantiator {
        model: ToplevelManager.toplevels
        delegate: QtObject {
            required property var modelData
            readonly property string appId: modelData ? modelData.appId : ""
            onAppIdChanged: picker.editorReady(modelData)
            Component.onCompleted: picker.editorReady(modelData)
        }
    }
    Timer {
        id: captureDelay
        interval: 160
        onTriggered: {
            if (Lock.locked || !picker.targetScreen) { picker.cancel(); return; }
            captureProcess.command = picker.pendingCommand;
            picker.pendingCommand = [];
            captureProcess.running = true;
            if (picker.captureMode === "region") handoffTimeout.restart();
        }
    }
    Process {
        id: captureProcess
        stderr: StdioCollector {
            onStreamFinished: {
                picker.captureError = text.trim();
                if (picker.captureError) console.warn("Screenshot:", picker.captureError);
            }
        }
        onExited: (exitCode, exitStatus) => {
            picker.releaseFrame();
            if (exitCode !== 0 || exitStatus !== 0)
                Quickshell.execDetached(["notify-send", picker.captureMode === "ocr" ? "Копирование текста" : "Скриншот",
                    picker.captureMode === "ocr" && picker.captureError ? picker.captureError
                        : "Не удалось выполнить захват. Подробности — в журнале оболочки."]);
        }
    }
    FocusScope {
        id: controls
        anchors.fill: parent
        visible: picker.opened
        focus: picker.opened
        Keys.onEscapePressed: picker.cancel()
        MouseArea { anchors.fill: parent; onClicked: picker.cancel() }
        WidgetSurface {
            anchors.centerIn: parent
            width: Math.min(516, parent.width - 32)
            height: 146
            readonly property color surfaceFill: Qt.darker(Theme.surface, 1.12)
            color: Qt.rgba(surfaceFill.r, surfaceFill.g, surfaceFill.b, 0.27)
            grainAlpha: 0.012
            border.color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.04)
            RowLayout {
                anchors.fill: parent
                anchors.margins: 13
                spacing: 27
                ActionButton {
                    id: flameshotButton
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    padding: 24
                    display: AbstractButton.IconOnly
                    hint: "Flameshot"
                    KeyNavigation.right: windowButton
                    Keys.onReturnPressed: picker.capture("region")
                    Keys.onEnterPressed: picker.capture("region")
                    onClicked: picker.capture("region")
                    background: Item {}
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: flameshotButton.hovered || flameshotButton.visualFocus ? Theme.accent : "#080810"
                        shadowOpacity: flameshotButton.hovered || flameshotButton.visualFocus ? 0.55 : 0.30
                        shadowVerticalOffset: flameshotButton.hovered || flameshotButton.visualFocus ? 0 : 2
                        shadowBlur: 0.65
                        blurMax: 12
                        Behavior on shadowColor { ColorAnimation { duration: Theme.duration(160) } }
                        Behavior on shadowOpacity { NumberAnimation { duration: Theme.duration(160) } }
                    }
                    contentItem: Image {
                        source: Quickshell.iconPath("flameshot")
                        sourceSize.width: 72; sourceSize.height: 72
                        fillMode: Image.PreserveAspectFit
                    }
                }
                ActionButton {
                    id: windowButton
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    padding: 24
                    display: AbstractButton.IconOnly
                    enabled: picker.windowGeometry !== ""
                    hint: "Снимок активного окна"
                    KeyNavigation.left: flameshotButton
                    KeyNavigation.right: ocrButton
                    Keys.onReturnPressed: picker.capture("window")
                    Keys.onEnterPressed: picker.capture("window")
                    onClicked: picker.capture("window")
                    background: Item {}
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: windowButton.hovered || windowButton.visualFocus ? Theme.accent : "#080810"
                        shadowOpacity: windowButton.hovered || windowButton.visualFocus ? 0.55 : 0.30
                        shadowVerticalOffset: windowButton.hovered || windowButton.visualFocus ? 0 : 2
                        shadowBlur: 0.65
                        blurMax: 12
                        Behavior on shadowColor { ColorAnimation { duration: Theme.duration(160) } }
                        Behavior on shadowOpacity { NumberAnimation { duration: Theme.duration(160) } }
                    }
                    icon.source: Qt.resolvedUrl("icons/screenshot-window.svg")
                    icon.cache: false
                    icon.width: 72; icon.height: 72
                }
                ActionButton {
                    id: ocrButton
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    padding: 24
                    display: AbstractButton.IconOnly
                    hint: "Копировать текст из области (русский и английский)"
                    KeyNavigation.left: windowButton
                    Keys.onReturnPressed: picker.capture("ocr")
                    Keys.onEnterPressed: picker.capture("ocr")
                    onClicked: picker.capture("ocr")
                    background: Item {}
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: ocrButton.hovered || ocrButton.visualFocus ? Theme.accent : "#080810"
                        shadowOpacity: ocrButton.hovered || ocrButton.visualFocus ? 0.55 : 0.30
                        shadowVerticalOffset: ocrButton.hovered || ocrButton.visualFocus ? 0 : 2
                        shadowBlur: 0.65
                        blurMax: 12
                        Behavior on shadowColor { ColorAnimation { duration: Theme.duration(160) } }
                        Behavior on shadowOpacity { NumberAnimation { duration: Theme.duration(160) } }
                    }
                    icon.source: Qt.resolvedUrl("icons/screenshot-ocr.svg")
                    icon.cache: false
                    icon.width: 72; icon.height: 72
                }
            }
        }
    }
}
