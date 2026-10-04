pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property string directory: Settings.wallpaperDirectory
    readonly property string fallback: neutral
    readonly property string neutral: Qt.resolvedUrl("assets/default-wallpaper.svg").toString()
    property string targetOutput: ""
    property int pickerRow: 0
    property var outputs: ({})
    property string layoutId: "empty"
    property var document: ({ outputs: {} })
    property var pendingDocument: null
    property bool ready: false
    property bool saving: false
    property string pendingOutput: ""
    property string error: ""
    property alias library: library
    property var thumbnails: ({})
    property var thumbnailErrors: ({})
    property var checkedThumbnails: ({})
    property var thumbnailQueue: []
    property string thumbnailUrl: ""
    signal acceptRequested()

    function current(outputName) { return liveFor(outputName) ? neutral : outputs[outputName] || fallback; }
    function liveLayers(value) {
        const live = (value || document).live;
        if (!live) return [];
        if (Array.isArray(live.layers)) return live.layers;
        const names = Quickshell.screens.map(s => s.name);
        return [Object.assign({}, live, { outputs: names, visibleOutputs: names })];
    }
    function liveFor(outputName, value) {
        return liveLayers(value).find(layer => layer.visibleOutputs.includes(outputName)) || null;
    }
    function frameFor(outputName) { return liveFor(outputName) ? null : (document.frames || {})[outputName] || null; }
    function outputsToClear(outputName, span) {
        if (span) return [];
        const live = liveFor(outputName);
        if (live) return live.mode === "span" ? live.visibleOutputs.filter(name => name !== outputName) : [];
        if (!(frameFor(outputName) || {}).span) return [];
        return Quickshell.screens.map(s => s.name).filter(name => name !== outputName
            && !liveFor(name) && (frameFor(name) || {}).span && current(name) === current(outputName));
    }
    function toggle(outputName) {
        if (LiveWallpapers.busy) return;
        if (targetOutput !== "") {
            acceptRequested();
            return;
        }
        if (!Quickshell.screens.some(s => s.name === outputName)) return;
        checkedThumbnails = ({});
        thumbnailErrors = ({});
        targetOutput = outputName;
    }
    function cancel() {
        // Closing releases input; an atomic write already in flight still completes.
        pendingOutput = "";
        targetOutput = "";
    }
    onTargetOutputChanged: { if (!targetOutput) thumbnailQueue = []; }
    function requestPreviews(index, radius, urls) {
        const next = [];
        for (let distance = 0; distance <= radius; distance++) {
            const indices = distance === 0 ? [index] : [index + distance, index - distance];
            for (const i of indices) {
                if (i < 0 || i >= (urls ? urls.length : library.count)) continue;
                const url = urls ? urls[i] : library.get(i, "fileUrl").toString();
                if (!url) continue;
                if (!checkedThumbnails[url] && url !== thumbnailUrl) next.push(url);
            }
        }
        // Include saved backgrounds on the other output in the desktop miniature.
        for (const screen of Quickshell.screens) {
            const live = liveFor(screen.name);
            const entry = live ? LiveWallpapers.items.find(item => item.path === live.path) : null;
            const url = entry ? entry.preview : current(screen.name);
            if (url && !checkedThumbnails[url] && url !== thumbnailUrl && !next.includes(url)) next.push(url);
        }
        thumbnailQueue = next;
        nextThumbnail();
    }
    function nextThumbnail() {
        if (thumbnailWorker.running || !targetOutput || !thumbnailQueue.length) return;
        thumbnailUrl = thumbnailQueue[0];
        thumbnailQueue = thumbnailQueue.slice(1);
        thumbnailWorker.command = ["python3", decodeURIComponent(Qt.resolvedUrl("wallpaper-thumbnail.py").toString().replace("file://", "")), thumbnailUrl];
        thumbnailWorker.running = true;
    }
    function apply(outputName, url, selectedLayout, liveSelection, frame) {
        if (!ready || saving || LiveWallpapers.busy || !Quickshell.screens.some(s => s.name === outputName)) return;
        const selected = WidgetLayouts.layouts.find(value => value.id === selectedLayout);
        if (!selected) {
            error = "Раскладка недоступна. Выбери другую или нажми Escape.";
            return;
        }
        const next = Object.assign({}, outputs);
        const affected = frame && frame.span ? Quickshell.screens.map(s => s.name) : [outputName];
        const cleared = outputsToClear(outputName, !!(frame && frame.span));
        const frames = Object.assign({}, document.frames || {});
        for (const name of cleared) {
            next[name] = neutral;
            delete frames[name];
        }
        for (const name of affected) {
            if (url) next[name] = url.toString();
            if (url && frame) frames[name] = frame;
        }
        const layers = liveLayers().map(layer => Object.assign({}, layer, {
            visibleOutputs: layer.visibleOutputs.filter(name => !affected.includes(name) && !cleared.includes(name))
        })).filter(layer => layer.visibleOutputs.length);
        if (liveSelection) layers.push(Object.assign({}, liveSelection, {
            mode: frame && frame.span ? "span" : "single", outputs: affected, visibleOutputs: affected
        }));
        pendingOutput = outputName;
        const nextDocument = Object.assign({}, document, { outputs: next, frames: frames, layout: selected.id,
            live: layers.length ? { layers: layers } : null });
        if (liveSelection && liveSelection.crop) {
            nextDocument.liveCrops = Object.assign({}, document.liveCrops || {});
            nextDocument.liveCrops[liveSelection.path] = liveSelection.crop;
        }
        if (url && frame) {
            nextDocument.imageCrops = Object.assign({}, document.imageCrops || {});
            nextDocument.imageCrops[url.toString()] = frame.crop;
        }
        if (JSON.stringify(document) === JSON.stringify(nextDocument)) { cancel(); return; }
        if (nextDocument.live || LiveWallpapers.active || document.live || (frame && frame.span)
                || (frameFor(outputName) && frameFor(outputName).span)) {
            LiveWallpapers.begin(nextDocument);
            return;
        }
        saveDocument(nextDocument);
    }
    function saveDocument(nextDocument) {
        if (saving) return;
        pendingDocument = nextDocument;
        saving = true;
        error = "";
        try {
            const serialized = JSON.stringify(pendingDocument, null, 4) + "\n";
            // FileView skips identical writes and does not emit saved for them.
            if (state.text() === serialized) saveCompleted();
            else state.setText(serialized);
        } catch (failure) {
            saveFailed();
        }
    }
    function saveFailed() {
        pendingDocument = null;
        pendingOutput = "";
        saving = false;
        error = "Не удалось сохранить выбор. Проверь доступ к wallpapers.json и повтори Enter.";
        LiveWallpapers.saveFailed();
    }
    function saveCompleted() {
        if (!saving || !pendingDocument) return;
        try {
            document = pendingDocument;
            outputs = document.outputs;
            layoutId = WidgetLayouts.layout(document.layout).id;
            error = "";
        } finally {
            pendingDocument = null;
            saving = false;
            if (targetOutput === pendingOutput) targetOutput = "";
            pendingOutput = "";
        }
        LiveWallpapers.saved();
    }
    Timer {
        interval: 10000
        running: root.saving && root.targetOutput !== ""
        onTriggered: {
            root.error = "Сохранение задерживается. Меню закрыто; запись ещё может завершиться.";
            root.cancel();
        }
    }
    Process {
        id: thumbnailWorker
        property bool replied: false
        onStarted: replied = false
        stdout: SplitParser {
            onRead: data => {
                try {
                    const message = JSON.parse(data);
                    if (message.url !== root.thumbnailUrl || typeof message.thumbnail !== "string") return;
                    thumbnailWorker.replied = true;
                    const previews = Object.assign({}, root.thumbnails);
                    const errors = Object.assign({}, root.thumbnailErrors);
                    previews[message.url] = message.thumbnail;
                    errors[message.url] = message.error || "";
                    root.thumbnails = previews;
                    root.thumbnailErrors = errors;
                } catch (error) { console.warn("Invalid wallpaper preview response"); }
            }
        }
        onExited: {
            if (!replied) {
                const errors = Object.assign({}, root.thumbnailErrors);
                errors[root.thumbnailUrl] = "Не удалось подготовить превью";
                root.thumbnailErrors = errors;
                const previews = Object.assign({}, root.thumbnails);
                previews[root.thumbnailUrl] = "";
                root.thumbnails = previews;
            }
            const checked = Object.assign({}, root.checkedThumbnails);
            checked[root.thumbnailUrl] = true;
            root.checkedThumbnails = checked;
            root.thumbnailUrl = "";
            Qt.callLater(root.nextThumbnail);
        }
    }
    FolderListModel {
        id: library
        folder: "file://" + root.directory
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.avif", "*.JPG", "*.JPEG", "*.PNG", "*.WEBP", "*.AVIF"]
        showDirs: false
        showDotAndDotDot: false
        sortField: FolderListModel.Name
    }
    FileView {
        id: state
        path: Settings.configHome + "/shoji-shell/wallpapers.json"
        preload: true
        printErrors: false
        atomicWrites: true
        onLoaded: {
            if (root.ready) return;
            try {
                const saved = JSON.parse(text());
                if (!saved || typeof saved !== "object" || Array.isArray(saved)
                        || !saved.outputs || typeof saved.outputs !== "object" || Array.isArray(saved.outputs)
                        || !Object.values(saved.outputs).every(url => typeof url === "string"))
                    throw new Error("Invalid wallpaper state");
                root.document = saved;
                root.outputs = saved.outputs;
                root.layoutId = WidgetLayouts.layout(saved.layout).id;
                root.ready = true;
                root.error = "";
            } catch (error) {
                root.error = "Не удалось прочитать wallpapers.json. Исправь файл и перезагрузи оболочку.";
            }
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) root.ready = true;
            else root.error = "Не удалось прочитать сохранённые обои";
        }
        onSaved: root.saveCompleted()
        onSaveFailed: root.saveFailed()
    }
}
