pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var items: []
    property bool available: false
    property bool nativeWave: false
    property bool active: false
    property bool busy: false
    readonly property bool revealing: uncover.running
    property bool capturing: false
    property bool prepared: false
    property bool freezeRequested: false
    property int pendingCaptures: 0
    signal captureWidgets()
    property bool covered: false
    property real progress: 0
    property string status: ""
    property var pendingDocument: null
    property var previousDocument: null
    property bool rollingBack: false
    property var geometry: ({ x: 0, y: 0, width: 1, height: 1 })
    readonly property size desktopSize: Qt.size(geometry.width, geometry.height)
    property bool restoring: false
    property int restoreFailures: 0
    property bool catalogReady: false
    readonly property string helper: decodeURIComponent(Qt.resolvedUrl("live-wallpaper.py").toString().replace("file://", ""))

    function send(action, extra) {
        if (!backend.running) return false;
        backend.write(JSON.stringify(Object.assign({ action: action }, extra || {})) + "\n");
        return true;
    }
    function scan() { send("scan"); }
    function activeOn(outputName) { return active && !!Wallpapers.liveFor(outputName); }
    function syncWave(acknowledge) {
        if (!nativeWave) return;
        send("wave", { acknowledge: !!acknowledge, state: { active: busy, progress: progress,
            capture: capturing, preparing: !freezeRequested, geometry: geometry } });
    }
    onBusyChanged: syncWave()
    Timer {
        interval: 16; repeat: true; running: uncover.running
        onTriggered: root.syncWave()
    }
    Timer {
        // Keep the watchdog alive while decoding; progress is stationary here.
        interval: 1000; repeat: true; running: root.busy && !uncover.running
        onTriggered: root.syncWave()
    }
    function origin(outputName) {
        const screen = Quickshell.screens.find(s => s.name === outputName);
        return Qt.vector2d(screen ? screen.x - geometry.x : 0, screen ? screen.y - geometry.y : 0);
    }
    function begin(document) {
        if (busy || pendingCaptures > 0) return false;
        if (restoring) { Wallpapers.error = "Восстанавливаю видеообои. Дождись завершения запуска."; return false; }
        if (!nativeWave) { Wallpapers.error = "Примени новый конфиг ShojiWM: Super+Shift+R"; return false; }
        if (!backend.running) { Wallpapers.error = "Служба обоев не запущена. Перезагрузи оболочку."; return false; }
        if (Object.values(WidgetLayouts.transitions).some(t => t.transitioning || t.preparing)) {
            Wallpapers.error = "Дождись завершения текущего перехода";
            return false;
        }
        const screens = Quickshell.screens;
        if (!screens.length) return false;
        const x = Math.min(...screens.map(s => s.x)), y = Math.min(...screens.map(s => s.y));
        geometry = { x: x, y: y,
            width: Math.max(...screens.map(s => s.x + s.width)) - x,
            height: Math.max(...screens.map(s => s.y + s.height)) - y };
        pendingDocument = document;
        previousDocument = Wallpapers.document;
        rollingBack = false;
        Wallpapers.error = "";
        Wallpapers.targetOutput = "";
        status = "Подготовка обоев…";
        prepared = false;
        freezeRequested = false;
        capturing = true;
        covered = false;
        progress = 0;
        busy = true;
        captureWidgets();
        if (busy) startBackend.restart();
        return true;
    }
    function captureWidget(item, accept) {
        pendingCaptures++;
        const done = result => {
            try {
                if (busy && !covered) {
                    if (!result) fail("Не удалось сохранить кадр виджетов. Повтори выбор.");
                    else accept(result);
                }
            }
            finally { pendingCaptures--; Qt.callLater(savePrepared); }
        };
        if (!item.grabToImage(done)) done(null);
    }
    function savePrepared() {
        if (!busy || !prepared || freezeRequested || pendingCaptures > 0 || !pendingDocument) return;
        freezeRequested = true;
        capturing = false;
        syncWave(true);
    }
    function frozen() {
        if (!busy || !freezeRequested || covered || !pendingDocument) return;
        covered = true;
        Wallpapers.saveDocument(pendingDocument);
    }
    function reveal() {
        progress = 0;
        syncWave();
        uncover.start();
    }
    function fail(message) {
        if (restoring) { restoring = false; restoreFailures++; }
        startBackend.stop();
        imagesReady.stop();
        status = message;
        Wallpapers.error = message;
        pendingDocument = null;
        if (busy) {
            uncover.stop();
            send("cancel");
            if (covered) {
                rollingBack = true;
                if (!Wallpapers.saving) saved();
            }
            else complete();
        }
    }
    function saved() {
        if (!busy || !covered) return;
        if (rollingBack && JSON.stringify(Wallpapers.document) !== JSON.stringify(previousDocument)) {
            Wallpapers.saveDocument(previousDocument);
            return;
        }
        for (const transition of Object.values(WidgetLayouts.transitions)) transition.syncCovered();
        imagesReady.start();
    }
    function saveFailed() {
        if (!busy) return;
        send("cancel");
        if (rollingBack) { complete(); return; }
        fail("Не удалось сохранить выбор. Предыдущие обои сохранены.");
    }
    function restore() {
        if (restoring || busy || active || !backend.running || !catalogReady || !Wallpapers.ready
                || !nativeWave || !Wallpapers.document.live || Wallpapers.saving || Wallpapers.targetOutput) return;
        // Reload restores the saved renderer without freezing widgets or rewriting the selection.
        restoring = true;
        status = "Восстановление видеообоев…";
        send("prepare", { selection: Wallpapers.document.live, restore: true });
    }
    function complete() {
        busy = false;
        progress = 0;
        capturing = false;
        prepared = false;
        freezeRequested = false;
        covered = false;
        pendingDocument = null;
        previousDocument = null;
        rollingBack = false;
        if (!Wallpapers.error) status = "";
    }
    Timer {
        // ponytail: reserve several refreshes for the GPU snapshot before mapping
        // candidates; replace with presentation feedback if low-refresh outputs need it.
        id: startBackend; interval: 80
        onTriggered: if (root.busy) {
            root.capturing = false;
            root.syncWave();
            root.send("prepare", { selection: root.pendingDocument.live || null });
        }
    }
    NumberAnimation {
        id: uncover
        target: root; property: "progress"; from: 0; to: 1; duration: 680
        easing.type: Easing.Linear
        onFinished: root.complete()
    }
    // Keep the previous frame until static images are decoded too (including live -> still).
    Timer {
        id: imagesReady; interval: 16; repeat: true
        onTriggered: {
            const transitions = Object.values(WidgetLayouts.transitions);
            if (!transitions.every(t => t.front.status === Image.Ready
                    && t.front.source.toString() === Wallpapers.current(t.outputName)
                    && JSON.stringify(t.front.framing) === JSON.stringify(Wallpapers.frameFor(t.outputName)))) return;
            stop();
            if (root.rollingBack) root.complete();
            else root.send("commit");
        }
    }
    Timer {
        interval: 10000 + 45000 * Math.max(1, Wallpapers.liveLayers(root.pendingDocument).length)
        running: root.busy && !uncover.running
        onTriggered: { imagesReady.stop(); root.send("cancel"); root.fail("Переход прерван: обои не ответили вовремя"); }
    }
    Timer {
        // Each renderer gets its own preparation deadline in the helper.
        interval: 10000 + 120000 * Math.max(1, Wallpapers.liveLayers().length)
        running: root.restoring
        onTriggered: { root.send("cancel"); root.fail("Восстановление задержалось. Попробую снова автоматически."); }
    }
    Timer {
        interval: Math.min(300000, 30000 * Math.pow(2, Math.min(root.restoreFailures, 4)))
        running: Wallpapers.ready && !!Wallpapers.document.live
            && !root.active && !root.restoring && !root.busy && !Wallpapers.saving && !Wallpapers.targetOutput
        repeat: true
        onTriggered: {
            if (!backend.running) backend.running = true;
            else root.restore();
        }
    }
    Connections { target: Wallpapers; function onReadyChanged() { root.restore(); } }
    Timer {
        interval: 1000; repeat: true; running: root.catalogReady && !root.nativeWave
        onTriggered: root.scan()
    }
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (root.busy || root.restoring) { root.send("cancel"); root.fail("Состав мониторов изменился. Повтори выбор обоев."); }
            else if (root.active && Wallpapers.document.live) root.begin(Wallpapers.document);
        }
    }
    Process {
        id: backend
        running: true
        stdinEnabled: true
        command: ["python3", root.helper]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const message = JSON.parse(data);
                    if (message.event === "catalogue") {
                        root.items = message.items;
                        root.available = message.assets;
                        root.nativeWave = !!message.nativeWave;
                        root.catalogReady = true;
                        root.restore();
                    } else if (message.event === "ready") {
                        if (root.restoring) root.send("commit");
                        else if (root.busy && root.pendingDocument) {
                            root.prepared = true;
                            root.savePrepared();
                        }
                        else root.send("cancel");
                    } else if (message.event === "frozen") {
                        root.frozen();
                    } else if (message.event === "committed") {
                        root.active = message.active;
                        if (root.restoring) {
                            root.restoring = false;
                            root.restoreFailures = 0;
                            root.status = "";
                            Wallpapers.error = "";
                        }
                        if (root.busy && root.covered && root.pendingDocument && !root.rollingBack) root.reveal();
                    } else if (message.event === "error") {
                        root.active = message.active;
                        root.fail(message.message);
                    } else if (message.event === "stopped") {
                        root.active = false;
                        root.status = message.message;
                        Wallpapers.error = message.message;
                    }
                } catch (error) { console.warn("Live wallpapers:", error); }
            }
        }
        onExited: {
            root.active = false;
            root.fail("Служба обоев остановилась. Перезагрузи оболочку.");
        }
    }
}
