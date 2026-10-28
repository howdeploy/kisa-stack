pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool opened: false
    property string targetOutput: ""
    readonly property var targetScreen: Quickshell.screens.find(s => s.name === targetOutput) || null
    readonly property string edge: {
        const screens = Quickshell.screens.slice().sort((a, b) => a.x - b.x || a.y - b.y || a.name.localeCompare(b.name));
        return screens.length < 2 || (screens[0] && screens[0].name === targetOutput) ? "left" : "right";
    }
    property string page: "displays"
    property var snapshot: ({})
    readonly property var values: snapshot.values || ({})
    readonly property var outputs: snapshot.outputs || []
    readonly property var devices: snapshot.devices || []
    readonly property var trial: snapshot.trial || null
    readonly property bool available: socket.connected && snapshot.version === 1
    readonly property bool busy: mutation !== 0 || saving
    property string error: ""
    property string status: ""
    property bool loaded: false
    property bool saving: false
    property var document: ({ version: 1, values: null, local: { lockMinutes: 10, dimMinutes: 5 } })
    readonly property int lockMinutes: document.local ? document.local.lockMinutes : 10
    readonly property int dimMinutes: document.local ? document.local.dimMinutes : 5
    readonly property var lockWallpapers: document.lockWallpapers || ({})
    property int sequence: 0
    property int mutation: 0
    property string mutationMethod: ""
    property bool restoreAttempted: false
    property string lastSavedText: ""
    property string savingText: ""
    property int pendingTarget: 0
    property var surfaceState: ({})

    function copy(value) { return JSON.parse(JSON.stringify(value)); }
    function showOn(outputName) {
        if (Lock.locked) return;
        if (!Quickshell.screens.some(s => s.name === outputName)) {
            error = "Не удалось определить монитор для настроек";
            return;
        }
        targetOutput = outputName;
        opened = true;
        refresh();
    }
    function open(section, outputName) {
        if (["displays", "keyboard", "pointer", "audio", "connections", "lock", "appearance", "notifications"].includes(section)) page = section;
        if (outputName) { pendingTarget = 0; showOn(outputName); }
        else pendingTarget = send("settings.target", {});
    }
    function toggle(outputName) {
        if (opened || pendingTarget) close();
        else open("", outputName);
    }
    function close() { opened = false; pendingTarget = 0; if (trial) send("settings.revert", {}); }
    function send(method, params) {
        if (!socket.connected) return 0;
        const id = ++sequence;
        socket.write(JSON.stringify({ id: id, method: method, params: params || {} }) + "\n");
        socket.flush();
        return id;
    }
    function refresh() { send("settings.get", {}); }
    function mutate(method, params) {
        if (!available || busy || !loaded) return;
        error = ""; status = "";
        mutationMethod = method;
        mutation = send(method, params);
        requestTimeout.restart();
    }
    function updateInput(group, patch) {
        if (!values[group]) return;
        const next = copy(values);
        next[group] = Object.assign({}, next[group], patch);
        mutate("settings.input", next);
    }
    function applyDisplay(name, preference) {
        const next = copy(values.outputs || {});
        next[name] = preference;
        mutate("settings.displays", { outputs: next });
    }
    function confirmDisplays() { if (trial) mutate("settings.confirm", { token: trial.token }); }
    function revertDisplays() { mutate("settings.revert", {}); }
    function save() {
        if (!loaded || saving) return;
        savingText = JSON.stringify(document, null, 2) + "\n";
        if (savingText === lastSavedText) { status = "Настройки сохранены"; return; }
        saving = true;
        state.setText(savingText);
    }
    function setIdle(lock, dim) {
        if (!loaded || busy || !Number.isInteger(lock) || lock < 1 || lock > 120
                || !Number.isInteger(dim) || dim < 1 || dim > 60) return;
        document = Object.assign({}, document, { local: { lockMinutes: lock, dimMinutes: dim } });
        error = "";
        save();
    }
    function desktopStillFor(outputName) {
        const live = Wallpapers.liveFor(outputName);
        const entry = live ? LiveWallpapers.items.find(item => item.path === live.path) : null;
        return entry && entry.preview ? entry.preview : Wallpapers.current(outputName);
    }
    function lockWallpaperFor(outputName) {
        return lockWallpapers[outputName] || desktopStillFor(outputName);
    }
    function lockWallpaperFrameFor(outputName) {
        return lockWallpapers[outputName] ? null : Wallpapers.frameFor(outputName);
    }
    function setLockWallpaper(outputName, source) {
        if (!loaded || busy || !Quickshell.screens.some(s => s.name === outputName)) return;
        if (typeof source !== "string" || (source !== "" && (!source.startsWith("file:///") || source.includes("\u0000")))) return;
        const next = Object.assign({}, lockWallpapers);
        if (source) next[outputName] = source;
        else delete next[outputName];
        document = Object.assign({}, document, { lockWallpapers: next });
        error = "";
        save();
    }
    function restore() {
        if (!loaded || !available || restoreAttempted || busy) return;
        restoreAttempted = true;
        if (document.values) mutate("settings.restore", document.values);
    }
    IpcHandler {
        target: "settings"
        function open(section: string): void { root.open(section); }
        function toggle(outputName: string): void { root.toggle(outputName); }
        function close(): void { root.close(); }
        function status(): string {
            return JSON.stringify({ opened: root.opened, output: root.targetOutput,
                screenFound: !!root.targetScreen, edge: root.edge, backendAvailable: root.available,
                loaded: root.loaded, error: root.error, surface: root.surfaceState });
        }
    }
    FileView {
        id: state
        path: Settings.configHome + "/shoji-shell/system-settings.json"
        preload: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            if (root.loaded) return;
            try {
                const data = JSON.parse(text());
                if (!data || data.version !== 1 || !data.local
                        || !Number.isInteger(data.local.lockMinutes) || data.local.lockMinutes < 1 || data.local.lockMinutes > 120
                        || !Number.isInteger(data.local.dimMinutes) || data.local.dimMinutes < 1 || data.local.dimMinutes > 60
                        || (data.values !== null && (typeof data.values !== "object" || Array.isArray(data.values)))
                        || (data.lockWallpapers !== undefined && (!data.lockWallpapers || typeof data.lockWallpapers !== "object"
                            || Array.isArray(data.lockWallpapers) || !Object.entries(data.lockWallpapers).every(([name, url]) =>
                                /^[a-zA-Z0-9_.-]{1,64}$/.test(name) && typeof url === "string" && url.startsWith("file:///") && !url.includes("\u0000")))))
                    throw new Error("Invalid settings document");
                root.document = data;
                root.lastSavedText = text();
                root.loaded = true;
                root.restore();
            } catch (failure) { root.error = "Не удалось прочитать system-settings.json. Исходный файл сохранён."; }
        }
        onLoadFailed: failure => {
            if (failure === FileViewError.FileNotFound) { root.loaded = true; root.restore(); }
            else root.error = "Нет доступа к system-settings.json";
        }
        onSaved: { root.lastSavedText = root.savingText; root.saving = false; root.status = "Настройки сохранены"; }
        onSaveFailed: {
            root.saving = false;
            root.error = "Настройки действуют в этой сессии, но записать файл не удалось.";
            reload();
        }
    }
    Socket {
        id: socket
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/shojiwm-" + Quickshell.env("WAYLAND_DISPLAY") + ".sock"
        connected: true
        onConnectionStateChanged: {
            root.snapshot = ({});
            root.restoreAttempted = false;
            root.mutation = 0;
            requestTimeout.stop();
            if (connected) root.refresh();
            else root.close();
        }
        parser: SplitParser {
            onRead: line => {
                try {
                    const message = JSON.parse(line);
                    if (message.id === root.pendingTarget && root.pendingTarget !== 0) {
                        root.pendingTarget = 0;
                        if (message.error) root.error = String(message.error);
                        else root.showOn(message.result.output);
                        return;
                    }
                    if (message.event === "settings.changed") {
                        root.snapshot = message.payload;
                        root.restore();
                        return;
                    }
                    if (message.id === root.mutation && root.mutation !== 0) {
                        requestTimeout.stop();
                        const method = root.mutationMethod;
                        root.mutation = 0;
                        if (message.error) { root.error = String(message.error); root.refresh(); return; }
                        root.snapshot = message.result;
                        if (method === "settings.input" || method === "settings.confirm") {
                            root.document = Object.assign({}, root.document, { values: root.copy(root.values) });
                            root.save();
                        } else if (method === "settings.restore") root.status = "Сохранённые настройки отправлены ShojiWM";
                        return;
                    }
                    if (message.result && message.result.version === 1) {
                        root.snapshot = message.result;
                        root.restore();
                    }
                } catch (failure) { root.error = "Не удалось прочитать ответ ShojiWM"; }
            }
        }
    }
    Connections {
        target: Quickshell
        function onScreensChanged(): void {
            if (root.opened && !Quickshell.screens.some(s => s.name === root.targetOutput)) root.close();
        }
    }
    Timer {
        id: requestTimeout
        interval: 6000
        onTriggered: {
            root.mutation = 0;
            root.error = "ShojiWM не подтвердил запрос. Проверь текущее состояние перед повтором.";
            root.refresh();
        }
    }
    Timer { interval: 1500; repeat: true; running: !socket.connected; onTriggered: socket.connected = true }
}
