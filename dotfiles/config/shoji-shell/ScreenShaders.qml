pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string targetOutput: ""
    property var items: []
    property string selectedId: "none"
    property string previewId: "none"
    property string activeId: "none"
    property var previewScene: ({})
    property string captureEffect: "none"
    property bool ready: false
    property bool finishing: false
    property string error: ""
    property int sequence: 0
    property int pendingGet: 0
    property int pendingFinish: 0
    property string sessionId: ""
    property var thumbnails: ({})
    property string thumbnailError: ""
    property bool thumbnailsReady: false
    property bool capturePending: false
    property int pendingState: 0

    function send(method, params) {
        if (!shaderSocket.connected) return 0;
        const id = ++sequence;
        shaderSocket.write(JSON.stringify({ id: id, method: method, params: params || {} }) + "\n");
        shaderSocket.flush();
        return id;
    }
    function closeLocal() {
        targetOutput = "";
        ready = false;
        finishing = false;
        pendingGet = 0;
        pendingFinish = 0;
        capturePending = false;
        thumbnailsReady = false;
        previewWorker.running = false;
    }
    function toggle(outputName) {
        if (targetOutput !== "") { cancel(); return; }
        if (!Quickshell.screens.some(screen => screen.name === outputName)) return;
        Wallpapers.cancel();
        error = "";
        ready = false;
        thumbnails = ({});
        thumbnailError = "";
        thumbnailsReady = false;
        sessionId = Date.now().toString() + "-" + (++sequence).toString();
        targetOutput = outputName;
        if (shaderSocket.connected) pendingGet = send("screen-shaders.get", { output: targetOutput });
        else shaderSocket.connected = true;
    }
    function startThumbnails() {
        if (!capturePending || previewWorker.busy || targetOutput === "") return;
        capturePending = false;
        previewWorker.requestSession = sessionId;
        previewWorker.replied = false;
        previewWorker.busy = true;
        previewWorker.command = ["python3", decodeURIComponent(Qt.resolvedUrl("shader-previews.py").toString().replace("file://", "")),
            targetOutput, JSON.stringify(previewScene), captureEffect];
        previewWorker.running = true;
    }
    function finishThumbnails(images, failure) {
        thumbnails = images;
        thumbnailError = failure || "";
        thumbnailsReady = true;
        ready = true;
        send("screen-shaders.preview", { id: previewId, session: sessionId });
    }
    function preview(id) {
        if (!ready || finishing || !items.some(item => item.id === id) || id === previewId) return;
        previewId = id;
        error = "";
        send("screen-shaders.preview", { id: id, session: sessionId });
    }
    function apply() {
        if (!ready || finishing) return;
        finishing = true;
        pendingFinish = send("screen-shaders.apply");
    }
    function cancel() {
        if (targetOutput === "") return;
        send("screen-shaders.cancel");
        closeLocal();
    }

    IpcHandler {
        target: "screen-shaders"
        function toggle(outputName: string): void { root.toggle(outputName); }
        function cancel(): void { root.cancel(); }
        function status(): string {
            return JSON.stringify({ output: root.targetOutput, ready: root.ready,
                preview: root.previewId, error: root.error, connected: shaderSocket.connected,
                screens: Quickshell.screens.map(screen => screen.name),
                clipboardMode: Quickshell.env("QT_WAYLAND_USE_DATA_CONTROL") });
        }
    }
    Connections {
        target: Wallpapers
        function onTargetOutputChanged(): void { if (Wallpapers.targetOutput !== "") root.cancel(); }
    }
    Socket {
        id: shaderSocket
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/shojiwm-" + Quickshell.env("WAYLAND_DISPLAY") + ".sock"
        connected: true
        onConnectionStateChanged: {
            if (connected) {
                if (root.targetOutput !== "") root.pendingGet = root.send("screen-shaders.get", { output: root.targetOutput });
                else root.pendingState = root.send("screen-shaders.get");
            } else {
                root.closeLocal();
            }
        }
        parser: SplitParser {
            onRead: data => {
                try {
                    const message = JSON.parse(data);
                    if (message.event === "screen-shaders.changed") {
                        root.activeId = message.payload.active || message.payload.preview || "none";
                        if (root.targetOutput !== "") {
                            root.error = message.payload.error || "";
                            if (root.ready && !message.payload.previewing) root.closeLocal();
                        }
                    } else if (message.id === root.pendingState && root.pendingState !== 0) {
                        root.pendingState = 0;
                        if (message.result) root.activeId = message.result.active || message.result.preview || "none";
                    } else if (message.id === root.pendingGet && root.targetOutput !== "") {
                        root.pendingGet = 0;
                        if (message.error) {
                            root.error = "Меню недоступно. Примени конфиг ShojiWM: Super+Shift+R.";
                            root.thumbnailsReady = true;
                            return;
                        }
                        root.items = message.result.items;
                        root.previewScene = message.result.scene || {};
                        root.activeId = message.result.active || message.result.preview || "none";
                        root.captureEffect = root.activeId;
                        root.selectedId = message.result.selected;
                        root.previewId = root.selectedId;
                        root.error = message.result.error || "";
                        root.thumbnailsReady = false;
                        // Preserve the live effect; the worker reuses its clean source frame.
                        root.capturePending = true;
                        root.startThumbnails();
                    } else if (message.id === root.pendingFinish && root.pendingFinish !== 0) {
                        if (message.error) {
                            root.finishing = false;
                            root.error = "Не удалось применить эффект. Повтори Enter или нажми Escape.";
                        } else root.closeLocal();
                    } else if (message.error && root.targetOutput !== "") {
                        root.error = String(message.error);
                    }
                } catch (failure) {
                    if (root.targetOutput !== "") root.error = "Не удалось прочитать ответ ShojiWM.";
                    console.warn("Screen shader menu:", failure);
                }
            }
        }
    }
    Timer { interval: 1000; repeat: true; running: !shaderSocket.connected; onTriggered: shaderSocket.connected = true }
    Process {
        id: previewWorker
        property string requestSession: ""
        property bool replied: false
        property bool busy: false
        stdout: SplitParser {
            onRead: data => {
                if (previewWorker.requestSession !== root.sessionId || root.targetOutput === "" || previewWorker.replied) return;
                try {
                    const reply = JSON.parse(data);
                    previewWorker.replied = true;
                    root.finishThumbnails(reply.images || {}, reply.error || "");
                } catch (failure) {
                    console.warn("Invalid screen shader preview response:", failure);
                }
            }
        }
        onExited: {
            busy = false;
            if (requestSession === root.sessionId && root.targetOutput !== "" && !replied)
                root.finishThumbnails({}, "Не удалось подготовить превью шейдеров.");
            Qt.callLater(root.startThumbnails);
        }
    }
    Timer {
        interval: 8000
        running: previewWorker.running
        onTriggered: {
            previewWorker.replied = true;
            previewWorker.running = false;
            if (previewWorker.requestSession === root.sessionId && root.targetOutput !== "")
                root.finishThumbnails({}, "Подготовка превью превысила время ожидания.");
        }
    }
    Timer {
        interval: 3000
        running: root.targetOutput !== "" && root.pendingGet !== 0 && root.error === ""
        onTriggered: {
            root.error = "ShojiWM не ответил. Escape — закрыть меню.";
            root.thumbnailsReady = true;
        }
    }
}
