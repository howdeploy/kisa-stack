pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property string directory: Settings.wallpaperDirectory
    readonly property string fallback: Qt.resolvedUrl("assets/default-wallpaper.svg").toString()
    property string targetOutput: ""
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

    function current(outputName) { return outputs[outputName] || fallback; }
    function toggle(outputName) {
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
    function requestPreviews(index, radius) {
        const next = [];
        for (let distance = 0; distance <= radius; distance++) {
            const indices = distance === 0 ? [index] : [index + distance, index - distance];
            for (const i of indices) {
                if (i < 0 || i >= library.count) continue;
                const url = library.get(i, "fileUrl").toString();
                if (!checkedThumbnails[url] && url !== thumbnailUrl) next.push(url);
            }
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
    function apply(outputName, url, selectedLayout) {
        if (!ready || saving || !Quickshell.screens.some(s => s.name === outputName)) return;
        const selected = WidgetLayouts.layouts.find(value => value.id === selectedLayout);
        if (!selected) {
            error = "Раскладка недоступна. Выбери другую или нажми Escape.";
            return;
        }
        if (selected.id === layoutId && (!url || current(outputName) === url.toString())) {
            cancel();
            return;
        }
        const next = Object.assign({}, outputs);
        if (url) next[outputName] = url.toString();
        pendingDocument = Object.assign({}, document, { outputs: next, layout: selected.id });
        pendingOutput = outputName;
        saving = true;
        error = "";
        try {
            state.setText(JSON.stringify(pendingDocument, null, 4) + "\n");
        } catch (failure) {
            saveFailed();
        }
    }
    function saveFailed() {
        pendingDocument = null;
        pendingOutput = "";
        saving = false;
        error = "Не удалось сохранить выбор. Проверь доступ к wallpapers.json и повтори Enter.";
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
