pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "WallpaperCrop.js" as Crop

ColumnLayout {
    id: panel
    property string outputName: SystemSettings.targetOutput || (Quickshell.screens[0] ? Quickshell.screens[0].name : "")
    readonly property var output: Quickshell.screens.find(s => s.name === outputName) || null
    property bool video: false
    property bool span: false
    property string draft: ""
    property string videoPath: ""
    property string layoutId: Wallpapers.layoutId
    property var crops: ({})
    property bool initialized: false
    property bool previewsRegistered: false
    readonly property var liveEntry: LiveWallpapers.items.find(item => item.path === videoPath) || null
    readonly property string selectionKey: video ? videoPath : draft
    readonly property string previewSource: video ? liveEntry ? liveEntry.preview || "" : "" : draft
    readonly property var crop: crops[selectionKey]
        || (video ? Wallpapers.document.liveCrops || {} : Wallpapers.document.imageCrops || {})[selectionKey]
        || (video && (Wallpapers.liveFor(outputName) || {}).path === videoPath ? Wallpapers.liveFor(outputName).crop : null)
        || (!video && draft === Wallpapers.current(outputName).toString() ? (Wallpapers.frameFor(outputName) || {}).crop : null)
        || ({ x: 0.5, y: 0, zoom: 1 })
    readonly property var geometry: {
        const screens = span ? Quickshell.screens : output ? [output] : [];
        const x = screens.length ? Math.min(...screens.map(s => s.x)) : 0;
        const y = screens.length ? Math.min(...screens.map(s => s.y)) : 0;
        return { x: x, y: y,
            width: screens.length ? Math.max(...screens.map(s => s.x + s.width)) - x : 1,
            height: screens.length ? Math.max(...screens.map(s => s.y + s.height)) - y : 1 };
    }
    readonly property bool working: Wallpapers.saving || LiveWallpapers.busy
    readonly property bool canApply: !!output && Wallpapers.ready && !working && !!previewSource
        && preview.status === Image.Ready && (!video || LiveWallpapers.available)
    property bool compact: false
    spacing: compact ? 8 : 10

    function resetSelection() {
        const live = Wallpapers.liveFor(outputName);
        video = !!live;
        videoPath = live ? live.path : "";
        draft = Wallpapers.current(outputName).toString();
        span = live ? live.mode === "span" : !!(Wallpapers.frameFor(outputName) || {}).span;
        layoutId = Wallpapers.layoutId;
        crops = ({});
    }
    function setVideo(value) {
        video = value;
        if (video && !videoPath && LiveWallpapers.items.length) videoPath = LiveWallpapers.items[0].path;
    }
    function choose(index) {
        if (video) videoPath = LiveWallpapers.items[index].path;
        else draft = Wallpapers.library.get(index, "fileUrl").toString();
    }
    function setCrop(x, y, zoom) {
        if (!selectionKey || working) return;
        const next = Object.assign({}, crops);
        next[selectionKey] = Crop.clamp(x, y, zoom);
        crops = next;
    }
    function apply() {
        if (!canApply) return;
        const frame = { span: span, crop: { x: crop.x, y: crop.y, zoom: crop.zoom }, geometry: geometry };
        Wallpapers.apply(outputName, video ? "" : draft, layoutId,
            video ? { path: videoPath, crop: frame.crop } : null, frame);
    }
    function requestPreviews() {
        if (!initialized) return;
        if (!video) {
            if (!Wallpapers.targetOutput) Wallpapers.requestThumbnails([]);
            return;
        }
        const columns = Math.max(1, Math.round(gallery.width / Math.max(1, gallery.cellWidth)));
        const first = Math.max(0, Math.floor(gallery.contentY / gallery.cellHeight) * columns);
        const count = (Math.ceil(gallery.height / gallery.cellHeight) + 1) * columns;
        const urls = [previewSource];
        for (let i = first; i < Math.min(LiveWallpapers.items.length, first + count); i++)
            urls.push(LiveWallpapers.items[i].preview || "");
        Wallpapers.requestThumbnails(urls);
    }
    function refreshVideos() {
        Wallpapers.checkedThumbnails = ({});
        Wallpapers.thumbnailErrors = ({});
        LiveWallpapers.scan();
        requestPreviews();
    }
    onVideoChanged: { if (initialized) Qt.callLater(requestPreviews); }
    onPreviewSourceChanged: { if (initialized) Qt.callLater(requestPreviews); }
    onOutputNameChanged: { if (initialized) resetSelection(); }
    Component.onCompleted: {
        Wallpapers.previewClients++;
        previewsRegistered = true;
        Wallpapers.checkedThumbnails = ({});
        Wallpapers.thumbnailErrors = ({});
        initialized = true;
        resetSelection(); LiveWallpapers.scan(); Qt.callLater(requestPreviews);
    }
    Component.onDestruction: { if (previewsRegistered) Wallpapers.previewClients--; }
    Connections {
        target: LiveWallpapers
        function onItemsChanged(): void {
            if (panel.video && !panel.videoPath && LiveWallpapers.items.length) panel.videoPath = LiveWallpapers.items[0].path;
            if (panel.initialized) Qt.callLater(panel.requestPreviews);
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 18
        SettingsRow {
            label: "Монитор"
            SettingsChoice {
                Layout.preferredWidth: 150
                hint: "Монитор для обоев"
                model: Quickshell.screens.map(s => ({ label: s.name, value: s.name }))
                currentIndex: model.findIndex(item => item.value === panel.outputName)
                onActivated: panel.outputName = currentValue
            }
        }
        SettingsRow {
            label: "Тип обоев"
            SettingsChoice {
                Layout.preferredWidth: 150
                hint: "Тип обоев"
                model: [{ label: "Изображения", value: false }, { label: "Видеообои", value: true }]
                currentIndex: panel.video ? 1 : 0
                onActivated: panel.setVideo(currentValue)
            }
        }
    }
    SettingsRow {
        label: "Общий фон на все мониторы"
        description: panel.compact ? "" : panel.span ? "Одна область изображения на весь рабочий стол" : "Изменится только выбранный монитор"
        SettingsToggle {
            hint: "Общий фон на все мониторы"
            selected: panel.span
            enabled: Quickshell.screens.length > 1 && !panel.working
            onRequested: selected => panel.span = selected
        }
    }
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 80
        Layout.preferredHeight: 260
        Layout.maximumHeight: 280
        radius: 10
        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.18)
        border.width: 1
        border.color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.1)
        clip: true
        Image {
            id: preview
            anchors { fill: parent; margins: 10 }
            source: panel.video ? Wallpapers.thumbnails[panel.previewSource] || "" : panel.previewSource
            sourceSize.width: 1200
            asynchronous: true; cache: false
            fillMode: Image.PreserveAspectFit
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.duration(180) } }
            MouseArea {
                anchors.fill: parent
                enabled: preview.status === Image.Ready && !panel.working
                preventStealing: true
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                property point start
                property var initialCrop
                onPressed: mouse => { start = Qt.point(mouse.x, mouse.y); initialCrop = panel.crop; }
                onPositionChanged: mouse => {
                    if (!pressed) return;
                    const dx = preview.paintedWidth - cropFrame.width, dy = preview.paintedHeight - cropFrame.height;
                    panel.setCrop(dx > 0.5 ? initialCrop.x + (mouse.x - start.x) / dx : initialCrop.x,
                        dy > 0.5 ? initialCrop.y + (mouse.y - start.y) / dy : initialCrop.y, initialCrop.zoom);
                }
            }
            Rectangle {
                id: cropFrame
                readonly property real aspect: preview.implicitWidth / Math.max(1, preview.implicitHeight)
                readonly property real targetAspect: panel.geometry.width / Math.max(1, panel.geometry.height)
                width: preview.paintedWidth * Math.min(1, targetAspect / Math.max(0.0001, aspect)) / panel.crop.zoom
                height: preview.paintedHeight * Math.min(1, aspect / Math.max(0.0001, targetAspect)) / panel.crop.zoom
                x: (preview.width - preview.paintedWidth) / 2 + (preview.paintedWidth - width) * panel.crop.x
                y: (preview.height - preview.paintedHeight) / 2 + (preview.paintedHeight - height) * panel.crop.y
                visible: preview.status === Image.Ready && !!panel.output
                color: "transparent"; border.width: 2; border.color: Theme.accent
                Repeater {
                    model: panel.span ? Quickshell.screens : panel.output ? [panel.output] : []
                    Rectangle {
                        id: screenFrame
                        required property var modelData
                        x: (modelData.x - panel.geometry.x) / panel.geometry.width * cropFrame.width
                        y: (modelData.y - panel.geometry.y) / panel.geometry.height * cropFrame.height
                        width: modelData.width / panel.geometry.width * cropFrame.width
                        height: modelData.height / panel.geometry.height * cropFrame.height
                        color: "transparent"; border.width: panel.span ? 1 : 0
                        border.color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.45)
                        UiText { x: 7; y: 5; text: screenFrame.modelData.name; font.pixelSize: 10; style: Text.Outline; styleColor: Theme.surface }
                    }
                }
                Repeater {
                    model: ["l", "r", "t", "b", "tl", "tr", "bl", "br"]
                    Rectangle {
                        id: handle
                        required property string modelData
                        x: modelData.includes("l") ? -4 : modelData.includes("r") ? cropFrame.width - 4 : cropFrame.width / 2 - 4
                        y: modelData.includes("t") ? -4 : modelData.includes("b") ? cropFrame.height - 4 : cropFrame.height / 2 - 4
                        width: 8; height: 8; radius: 2; color: Theme.accent
                        MouseArea {
                            anchors.centerIn: parent
                            width: handle.modelData === "t" || handle.modelData === "b" ? cropFrame.width : 20
                            height: handle.modelData === "l" || handle.modelData === "r" ? cropFrame.height : 20
                            enabled: !panel.working
                            preventStealing: true
                            cursorShape: handle.modelData.length === 2
                                ? (handle.modelData === "tl" || handle.modelData === "br" ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor)
                                : (handle.modelData === "l" || handle.modelData === "r" ? Qt.SizeHorCursor : Qt.SizeVerCursor)
                            property point start
                            property var rect
                            property real initialZoom
                            onPressed: mouse => {
                                start = mapToItem(preview, mouse.x, mouse.y);
                                initialZoom = panel.crop.zoom;
                                rect = { x: (cropFrame.x - (preview.width - preview.paintedWidth) / 2) / preview.paintedWidth,
                                    y: (cropFrame.y - (preview.height - preview.paintedHeight) / 2) / preview.paintedHeight,
                                    w: cropFrame.width / preview.paintedWidth, h: cropFrame.height / preview.paintedHeight };
                            }
                            onPositionChanged: mouse => {
                                if (!pressed) return;
                                const p = mapToItem(preview, mouse.x, mouse.y);
                                const next = Crop.resize(handle.modelData, rect, (p.x - start.x) / preview.paintedWidth,
                                    (p.y - start.y) / preview.paintedHeight, initialZoom);
                                panel.setCrop(next.x, next.y, next.zoom);
                            }
                        }
                    }
                }
            }
            WheelHandler {
                target: null
                onWheel: event => {
                    if (!(event.modifiers & Qt.ControlModifier)) { event.accepted = false; return; }
                    panel.setCrop(panel.crop.x, panel.crop.y, panel.crop.zoom + ((event.angleDelta.y || event.angleDelta.x) > 0 ? 0.05 : -0.05));
                    event.accepted = true;
                }
            }
        }
        UiText {
            anchors.centerIn: parent; color: Theme.muted; font.pixelSize: 12
            text: panel.video && Wallpapers.thumbnailErrors[panel.previewSource] ? "Не удалось подготовить превью"
                : preview.status === Image.Error ? "Не удалось загрузить превью"
                : preview.status === Image.Loading || (panel.video && panel.previewSource && !Wallpapers.checkedThumbnails[panel.previewSource])
                    ? "Подготовка превью…" : "Выбери обои в галерее"
            visible: preview.status !== Image.Ready
        }
    }
    SettingsRow {
        label: "Кадрирование"
        description: panel.compact ? "" : "Перетаскивай рамку и её края; Ctrl + колесо меняет масштаб"
        PanelSlider {
            Layout.preferredWidth: 150
            from: 1; to: 3; stepSize: 0.05; value: panel.crop.zoom
            enabled: !!panel.selectionKey && !panel.working
            Accessible.name: "Масштаб кадрирования"
            onMoved: panel.setCrop(panel.crop.x, panel.crop.y, value)
        }
        UiText { text: Math.round(panel.crop.zoom * 100) + "%"; color: Theme.muted; font.pixelSize: 11; Layout.preferredWidth: 38 }
        SettingsActionButton { text: "Сбросить"; enabled: !panel.working; onClicked: panel.setCrop(0.5, 0, 1) }
    }
    GridView {
        id: gallery
        Layout.fillWidth: true; Layout.fillHeight: true
        Layout.minimumHeight: panel.compact ? 80 : 126; Layout.preferredHeight: 258
        clip: true; cacheBuffer: 0; reuseItems: true
        cellWidth: width / Math.max(1, Math.floor(width / 155)); cellHeight: 126
        model: panel.video ? LiveWallpapers.items.length : Wallpapers.library.count
        onContentYChanged: { if (panel.initialized) Qt.callLater(panel.requestPreviews); }
        onWidthChanged: { if (panel.initialized) Qt.callLater(panel.requestPreviews); }
        onHeightChanged: { if (panel.initialized) Qt.callLater(panel.requestPreviews); }
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        delegate: SettingsActionButton {
            id: tile
            required property int index
            readonly property var entry: panel.video ? LiveWallpapers.items[index] || {} : ({})
            readonly property string url: panel.video ? entry.preview || "" : Wallpapers.library.get(index, "fileUrl").toString()
            readonly property string title: panel.video ? entry.title || "Видеообои" : Wallpapers.library.get(index, "fileName")
            readonly property bool selected: panel.video ? panel.videoPath === entry.path : panel.draft === url
            width: gallery.cellWidth - 8; height: gallery.cellHeight - 8; padding: 0
            hint: title
            background: Rectangle {
                radius: 8
                color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, tile.hovered ? 0.07 : 0.025)
                border.width: 1
                border.color: tile.selected || tile.visualFocus ? Theme.accent : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.1)
                Behavior on border.color { ColorAnimation { duration: Theme.duration(180) } }
            }
            contentItem: Item {
                Image {
                    id: thumbnailImage
                    x: 4; y: 4; width: tile.width - 8; height: 78
                    source: panel.video ? Wallpapers.thumbnails[tile.url] || "" : tile.url
                    sourceSize: Qt.size(300, 170)
                    asynchronous: true; cache: false; fillMode: Image.PreserveAspectCrop
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.duration(180) } }
                }
                PanelIcon {
                    x: (tile.width - width) / 2; y: 32
                    name: Wallpapers.thumbnailErrors[tile.url] ? "close" : "play"
                    tint: Theme.muted
                    visible: panel.video && thumbnailImage.status !== Image.Ready
                }
                UiText { x: 7; y: 88; width: tile.width - 14; text: tile.title; font.pixelSize: 10; color: tile.selected ? Theme.accent : Theme.muted }
            }
            onClicked: panel.choose(index)
        }
    }
    UiText {
        visible: gallery.count === 0 || (panel.video && !LiveWallpapers.available)
        text: panel.video ? LiveWallpapers.available ? "В каталоге пока нет видеообоев" : "Для видеообоев нужны ресурсы Wallpaper Engine в Steam"
            : "В папке обоев пока нет картинок"
        Layout.fillWidth: true; wrapMode: Text.Wrap; color: Theme.muted; font.pixelSize: 11
    }
    SettingsRow {
        label: "Раскладка виджетов"
        SettingsChoice {
            hint: "Раскладка виджетов"
            model: WidgetLayouts.layouts.map(item => ({ label: item.name, value: item.id }))
            currentIndex: model.findIndex(item => item.value === panel.layoutId)
            onActivated: panel.layoutId = currentValue
        }
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.1)
    }
    UiText {
        visible: Wallpapers.error !== ""
        text: Wallpapers.error; color: Theme.danger; font.pixelSize: 11
        Layout.fillWidth: true; wrapMode: Text.Wrap
    }
    RowLayout {
        SettingsActionButton {
            text: panel.working ? "Применение…" : "Применить"
            highlighted: true
            enabled: panel.canApply
            onClicked: panel.apply()
        }
        SettingsActionButton {
            text: "Вернуть сохранённое"
            enabled: !panel.working
            onClicked: panel.resetSelection()
        }
        SettingsActionButton {
            text: "Обновить видеообои"
            visible: panel.video; enabled: !panel.working
            onClicked: panel.refreshVideos()
        }
    }
}
