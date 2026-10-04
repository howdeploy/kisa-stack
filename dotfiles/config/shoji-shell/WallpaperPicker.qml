pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell

FocusScope {
    id: root
    required property string outputName
    focus: true
    readonly property real expandedWidth: Math.min(620, width * 0.56)
    readonly property real cardHeight: Math.min(388, height * 0.40)
    readonly property real layoutHeight: Math.min(220, height * 0.23)
    readonly property real layoutWidth: Math.min(620, width * 0.72)
    readonly property var previewScreens: Quickshell.screens.slice().sort((a, b) => a.x - b.x || a.y - b.y)
    readonly property real desktopLeft: Quickshell.screens.length ? Math.min(...Quickshell.screens.map(s => s.x)) : 0
    readonly property real desktopTop: Quickshell.screens.length ? Math.min(...Quickshell.screens.map(s => s.y)) : 0
    readonly property real desktopWidth: Quickshell.screens.length ? Math.max(...Quickshell.screens.map(s => s.x + s.width)) - desktopLeft : 1
    readonly property real desktopHeight: Quickshell.screens.length ? Math.max(...Quickshell.screens.map(s => s.y + s.height)) - desktopTop : 1
    readonly property var savedLive: Wallpapers.liveFor(outputName)
    property bool animatedMode: !!savedLive
    property bool span: savedLive ? savedLive.mode === "span" : !!(Wallpapers.frameFor(outputName) || {}).span
    readonly property var targetScreen: Quickshell.screens.find(s => s.name === outputName)
    readonly property real frameWidth: span ? desktopWidth : targetScreen ? targetScreen.width : width
    readonly property real frameHeight: span ? desktopHeight : targetScreen ? targetScreen.height : height
    readonly property var selectedLive: animatedMode && carousel.currentIndex >= 0
        ? LiveWallpapers.items[carousel.currentIndex] || null : null
    readonly property string selectedWallpaper: !animatedMode && carousel.currentIndex >= 0 && carousel.currentIndex < carousel.count
        ? Wallpapers.library.get(carousel.currentIndex, "fileUrl").toString() : ""
    readonly property var widgetLabels: ({ limits: "Лимиты AI", sessions: "Сессии", neko: "Котик",
        github: "GitHub", hermes: "Hermes", vast: "Vast.ai", music: "Музыка", profile: "Профиль", home: "Home Zone", "gaming-home": "Home Zone · Gaming" })
    readonly property var widgetIcons: ({ limits: "session-codex", sessions: "keyboard", github: "git-pull-request",
        hermes: "message-circle", vast: "cloud", music: "headphones", profile: "profile" })
    readonly property int activeRow: Wallpapers.pickerRow
    property string chosenWallpaper: ""
    property string chosenStill: ""
    property string chosenLive: ""
    property bool layoutTouched: false
    property bool restoringLayout: true
    property bool restoringWallpaper: true
    property string selectionError: ""
    property var crops: ({})
    readonly property string cropKey: animatedMode ? selectedLive ? selectedLive.path : "" : selectedWallpaper
    readonly property var crop: crops[cropKey]
        || (animatedMode ? Wallpapers.document.liveCrops || {} : Wallpapers.document.imageCrops || {})[cropKey]
        || (animatedMode && savedLive && savedLive.path === cropKey ? savedLive.crop : null)
        || ({ x: 0.5, y: 0, zoom: 1 })
    function setCrop(x, y, zoom) {
        if (!cropKey || Wallpapers.saving) return;
        const next = Object.assign({}, crops);
        next[cropKey] = { x: Math.max(0, Math.min(1, x)), y: Math.max(0, Math.min(1, y)),
            zoom: Math.max(1, Math.min(3, zoom)) };
        crops = next;
    }
    function zoomCrop(direction) { setCrop(crop.x, crop.y, crop.zoom + direction * 0.05); }
    function resizeCrop(edge, rect, dx, dy, initialZoom) {
        const left = edge.includes("l"), right = edge.includes("r");
        const top = edge.includes("t"), bottom = edge.includes("b");
        const sx = 1 + (left ? -dx : dx) / rect.w;
        const sy = 1 + (top ? -dy : dy) / rect.h;
        let scale = left || right ? top || bottom ? Math.max(sx, sy) : sx : sy;
        const ax = left ? rect.x + rect.w : right ? rect.x : rect.x + rect.w / 2;
        const ay = top ? rect.y + rect.h : bottom ? rect.y : rect.y + rect.h / 2;
        const maxW = left ? ax : right ? 1 - ax : Math.min(ax, 1 - ax) * 2;
        const maxH = top ? ay : bottom ? 1 - ay : Math.min(ay, 1 - ay) * 2;
        scale = Math.max(initialZoom / 3, Math.min(initialZoom, maxW / rect.w, maxH / rect.h, scale));
        const w = rect.w * scale, h = rect.h * scale;
        const x = left ? ax - w : right ? ax : ax - w / 2;
        const y = top ? ay - h : bottom ? ay : ay - h / 2;
        setCrop(w < 0.999999 ? x / (1 - w) : 0.5, h < 0.999999 ? y / (1 - h) : 0.5, initialZoom / scale);
    }
    readonly property bool canApply: Wallpapers.ready && !Wallpapers.saving && !LiveWallpapers.busy
    function setAnimated(value) {
        if (animatedMode === value) return;
        if (animatedMode) chosenLive = chosenWallpaper;
        else chosenStill = chosenWallpaper;
        animatedMode = value;
        chosenWallpaper = value ? chosenLive : chosenStill;
        selectionError = "";
        selectSaved();
        if (value) LiveWallpapers.scan();
    }
    function focusRow(row) { Wallpapers.pickerRow = row; selectionError = ""; forceActiveFocus(); }
    function step(direction) {
        if (Wallpapers.saving) return;
        if (activeRow === -1) {
            setAnimated(direction > 0);
        } else if (activeRow === 1) {
            layouts.currentIndex = Math.max(0, Math.min(layouts.count - 1, layouts.currentIndex + direction));
            layoutTouched = true;
        } else if (carousel.count) {
            carousel.currentIndex = Math.max(0, Math.min(carousel.count - 1, carousel.currentIndex + direction));
            chooseWallpaper();
        }
    }
    function chooseWallpaper() {
        if (restoringWallpaper) return;
        chosenWallpaper = animatedMode ? (selectedLive ? selectedLive.path : "")
            : carousel.currentIndex >= 0 ? Wallpapers.library.get(carousel.currentIndex, "fileUrl").toString() : "";
        selectionError = "";
    }
    function requestPreviews() {
        Wallpapers.requestPreviews(carousel.currentIndex, Math.ceil(width / (Math.min(136, width * 0.13) + 52) / 2) + 2,
            animatedMode ? LiveWallpapers.items.map(item => item.preview) : null);
    }
    function applySelected() {
        if (!canApply) return;
        const selected = WidgetLayouts.layouts[layouts.currentIndex];
        if (!selected) {
            selectionError = "Раскладка недоступна. Выбери другую или нажми Escape.";
            return;
        }
        const frame = { span: span, crop: { x: crop.x, y: crop.y, zoom: crop.zoom },
            geometry: { x: span ? desktopLeft : targetScreen.x, y: span ? desktopTop : targetScreen.y,
                width: frameWidth, height: frameHeight } };
        if (animatedMode) {
            if (!selectedLive) { selectionError = "Подпишись на обои в Steam Workshop и нажми R для обновления."; return; }
            if (!LiveWallpapers.available) { selectionError = "Установи Wallpaper Engine в Steam — нужны его ресурсы."; return; }
            if (!carousel.currentItem || !carousel.currentItem.loaded) {
                selectionError = "Дождись полного кадра для выбора области. Если он не загрузился, выбери другие обои.";
                return;
            }
            Wallpapers.apply(outputName, "", selected.id, { path: selectedLive.path, crop: frame.crop }, frame);
            return;
        }
        if (selectedWallpaper && selectedWallpaper !== Wallpapers.current(outputName)
                && (!carousel.currentItem || !carousel.currentItem.loaded)) {
            selectionError = Wallpapers.thumbnailErrors[selectedWallpaper] || (carousel.currentItem && carousel.currentItem.failed)
                ? "Картинка недоступна. Выбери другую или нажми Escape."
                : "Превью ещё загружается. Повтори Enter после загрузки.";
            return;
        }
        Wallpapers.apply(outputName, selectedWallpaper, selected.id, null, frame);
    }
    function selectSaved() {
        if (!Wallpapers.ready || carousel.width <= 0 || !carousel.count) return;
        restoringWallpaper = true;
        if (animatedMode) {
            const path = chosenWallpaper || (savedLive ? savedLive.path : "");
            const index = LiveWallpapers.items.findIndex(item => item.path === path);
            carousel.currentIndex = index >= 0 ? index : LiveWallpapers.items.length ? 0 : -1;
            requestPreviews();
            Qt.callLater(centerWallpaper);
            return;
        }
        const selected = chosenWallpaper || Wallpapers.current(outputName);
        for (let i = 0; i < Wallpapers.library.count; i++) {
            if (Wallpapers.library.get(i, "fileUrl").toString() === selected) {
                carousel.currentIndex = i;
                requestPreviews();
                Qt.callLater(centerWallpaper);
                return;
            }
        }
        chosenWallpaper = "";
        carousel.currentIndex = carousel.count ? 0 : -1;
        requestPreviews();
        Qt.callLater(centerWallpaper);
    }
    function centerWallpaper() {
        carousel.forceLayout();
        carousel.positionViewAtIndex(carousel.currentIndex, ListView.Center);
        restoringWallpaper = false;
    }
    function selectLayout() {
        if (layoutTouched || !layouts.count || layouts.width <= 0) return;
        layouts.currentIndex = Math.max(0, WidgetLayouts.layouts.findIndex(value => value.id === Wallpapers.layoutId));
        layouts.forceLayout();
        layouts.positionViewAtIndex(layouts.currentIndex, ListView.Center);
        restoringLayout = false;
    }
    Component.onCompleted: { selectSaved(); Qt.callLater(selectLayout); LiveWallpapers.scan(); forceActiveFocus(); }
    Connections { target: LiveWallpapers; function onItemsChanged() { if (root.animatedMode) root.selectSaved(); } }
    Connections {
        target: Wallpapers.library
        function onCountChanged(): void { root.selectSaved(); }
        function onStatusChanged(): void { root.selectSaved(); }
    }
    Connections {
        target: Wallpapers
        function onAcceptRequested(): void { root.applySelected(); }
        function onReadyChanged(): void { root.selectSaved(); root.selectLayout(); }
        function onLayoutIdChanged(): void { Qt.callLater(root.selectLayout); }
    }
    Keys.onEscapePressed: Wallpapers.cancel()
    Keys.onUpPressed: event => {
        if (event.modifiers & Qt.ShiftModifier) setCrop(crop.x, crop.y - 0.05, crop.zoom);
        else focusRow(Math.max(-1, activeRow - 1));
    }
    Keys.onDownPressed: event => {
        if (event.modifiers & Qt.ShiftModifier) setCrop(crop.x, crop.y + 0.05, crop.zoom);
        else focusRow(Math.min(1, activeRow + 1));
    }
    Keys.onTabPressed: focusRow(activeRow === 1 ? -1 : activeRow + 1)
    Keys.onBacktabPressed: focusRow(activeRow === -1 ? 1 : activeRow - 1)
    Keys.onPressed: event => {
        if (event.key === Qt.Key_R || event.key === Qt.Key_F5) {
            LiveWallpapers.scan();
            event.accepted = true;
        } else if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal || event.key === Qt.Key_Minus) {
            zoomCrop(event.key === Qt.Key_Minus ? -1 : 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_0) {
            setCrop(0.5, 0, 1);
            event.accepted = true;
        }
    }
    Keys.onLeftPressed: event => {
        if (event.modifiers & Qt.ShiftModifier) setCrop(crop.x - 0.05, crop.y, crop.zoom);
        else step(-1);
    }
    Keys.onRightPressed: event => {
        if (event.modifiers & Qt.ShiftModifier) setCrop(crop.x + 0.05, crop.y, crop.zoom);
        else step(1);
    }
    Keys.onReturnPressed: applySelected()
    Keys.onEnterPressed: applySelected()

    Rectangle {
        anchors.fill: parent
        color: "#a6000000"
        Image {
            anchors.fill: parent
            source: "assets/panel-grain.png"
            fillMode: Image.Tile
            opacity: 0.08
        }
    }
    MouseArea { anchors.fill: parent; onClicked: Wallpapers.cancel() }
    HoverHandler {
        property var previousPosition: null
        onPointChanged: {
            const position = point.scenePosition;
            const previous = previousPosition;
            previousPosition = Qt.point(position.x, position.y);
            // Mapping the picker under a stationary cursor must preserve the saved row.
            if (!previous || (previous.x === position.x && previous.y === position.y)) return;
            for (const [item, row] of [[kinds, -1], [carousel, 0], [layouts, 1]]) {
                if (item.contains(item.mapFromItem(null, position.x, position.y))) {
                    root.focusRow(row);
                    break;
                }
            }
        }
    }
    Row {
        id: kinds
        anchors { horizontalCenter: parent.horizontalCenter; bottom: carousel.top; bottomMargin: 14 }
        spacing: 24
        opacity: root.activeRow === -1 ? 1 : 0.72
        Behavior on opacity { NumberAnimation { duration: 160 } }
        WheelHandler { target: null; onWheel: event => { root.focusRow(-1); root.step((event.angleDelta.y || event.angleDelta.x) > 0 ? -1 : 1); event.accepted = true; } }
        Repeater {
            model: ["Изображения", "Анимированные"]
            delegate: Item {
                id: kind
                required property int index
                required property string modelData
                readonly property bool selected: root.animatedMode === (index === 1)
                width: selected ? 80 : 64
                height: 64
                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Accessible.role: Accessible.PageTab
                Accessible.name: modelData
                Accessible.selected: selected
                Accessible.onPressAction: { root.setAnimated(index === 1); root.focusRow(-1); }
                Rectangle {
                    anchors.fill: parent
                    color: kind.selected ? Theme.raised : Theme.surface
                    transform: Matrix4x4 {
                        matrix: Qt.matrix4x4(1, -0.12, 0, kind.height * 0.06,
                                             0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                    }
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: 2
                        color: root.activeRow === -1 ? Theme.accent : Theme.ink
                        visible: kind.selected
                    }
                }
                PanelIcon {
                    anchors.centerIn: parent
                    width: 24; height: 24
                    name: kind.index === 1 ? "play" : "image"
                    tint: kind.selected ? Theme.accent : Theme.muted
                }
                MouseArea { anchors.fill: parent; onClicked: { root.setAnimated(kind.index === 1); root.focusRow(-1); } }
            }
        }
        Switch {
            id: spanSwitch
            implicitWidth: 100
            implicitHeight: 46
            anchors.verticalCenter: parent.verticalCenter
            checked: root.span
            enabled: Quickshell.screens.length > 1
            onToggled: root.span = checked
            Accessible.name: "Общие обои на всех мониторах"
            indicator: Rectangle {
                x: 6; y: 6
                implicitWidth: 88; implicitHeight: 34
                radius: 17; color: Theme.surface
                Rectangle {
                    x: spanSwitch.checked ? parent.width - width - 3 : 3; y: 3
                    width: 38; height: 28; radius: 14; color: Theme.hover
                    Behavior on x { NumberAnimation { duration: 160 } }
                }
                Row {
                    x: 15; anchors.verticalCenter: parent.verticalCenter
                    Rectangle { width: 15; height: 11; radius: 1; color: "transparent"; border.color: spanSwitch.checked ? Theme.muted : Theme.accent }
                }
                Row {
                    x: 53; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                    Repeater { model: 2; Rectangle { width: 10; height: 11; radius: 1; color: "transparent"; border.color: spanSwitch.checked ? Theme.accent : Theme.muted } }
                }
            }
            contentItem: Item {}
        }
    }
    ListView {
        id: carousel
        onCountChanged: Qt.callLater(root.selectSaved)
        onWidthChanged: Qt.callLater(root.selectSaved)
        anchors { left: parent.left; right: parent.right }
        y: (root.height - height - root.layoutHeight - 32) / 2
        height: root.cardHeight + 48
        opacity: root.activeRow === 0 ? 1 : 0.68
        Behavior on opacity { NumberAnimation { duration: 160 } }
        model: root.animatedMode ? LiveWallpapers.items.length : Wallpapers.library.count
        orientation: ListView.Horizontal
        spacing: 52
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        snapMode: ListView.SnapToItem
        preferredHighlightBegin: (width - root.expandedWidth) / 2
        preferredHighlightEnd: preferredHighlightBegin + root.expandedWidth
        header: Item { width: carousel.preferredHighlightBegin; height: 1 }
        footer: Item { width: carousel.preferredHighlightBegin; height: 1 }
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightMoveDuration: 220
        cacheBuffer: 150
        enabled: !Wallpapers.saving
        onCurrentIndexChanged: root.requestPreviews()
        onMovementEnded: root.chooseWallpaper()
        WheelHandler {
            target: null
            onWheel: event => {
                const direction = (event.angleDelta.y || event.angleDelta.x) > 0 ? 1 : -1;
                if (event.modifiers & Qt.ControlModifier) root.zoomCrop(direction);
                else { root.focusRow(0); root.step(-direction); }
                event.accepted = true;
            }
        }
        delegate: Item {
            id: card
            required property int index
            readonly property var entry: root.animatedMode ? LiveWallpapers.items[index] || {} : ({})
            readonly property string fileUrl: root.animatedMode ? entry.preview || "" : (Wallpapers.library.get(index, "fileUrl") || "").toString()
            readonly property string fileName: root.animatedMode ? entry.title || "" : Wallpapers.library.get(index, "fileName") || ""
            readonly property bool selected: ListView.isCurrentItem
            readonly property bool loaded: preview.status === Image.Ready
            readonly property bool failed: preview.status === Image.Error
            width: selected ? root.expandedWidth : Math.min(136, root.width * 0.13)
            height: carousel.height
            Behavior on width { enabled: !root.restoringWallpaper; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Accessible.role: Accessible.ListItem
            Accessible.name: fileName
            Accessible.selected: selected
            Accessible.onPressAction: { carousel.currentIndex = card.index; root.chooseWallpaper(); root.focusRow(0); }
            Rectangle {
                anchors.centerIn: parent
                width: parent.width; height: root.cardHeight
                visible: preview.status !== Image.Ready
                color: Theme.surface
                opacity: 0.75
                PanelIcon {
                    anchors.centerIn: parent
                    visible: !!Wallpapers.thumbnailErrors[card.fileUrl.toString()] || card.failed
                    name: "close"
                    tint: Theme.muted
                }
            }
            Image {
                id: preview
                anchors.centerIn: parent
                width: parent.width
                height: root.cardHeight
                source: Wallpapers.thumbnails[card.fileUrl.toString()] || ""
                sourceSize: Qt.size(900, 600)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                // Diagonal slices above the shared dimmed backdrop.
                transform: Matrix4x4 {
                    matrix: Qt.matrix4x4(1, -0.12, 0, preview.height * 0.06,
                                         0, 1, 0, 0,
                                         0, 0, 1, 0,
                                         0, 0, 0, 1)
                }
                Rectangle {
                    id: cropFrame
                    readonly property real aspect: preview.implicitWidth / Math.max(1, preview.implicitHeight)
                    readonly property real targetAspect: root.frameWidth / root.frameHeight
                    width: preview.paintedWidth * Math.min(1, targetAspect / aspect) / root.crop.zoom
                    height: preview.paintedHeight * Math.min(1, aspect / targetAspect) / root.crop.zoom
                    x: (preview.width - preview.paintedWidth) / 2 + (preview.paintedWidth - width) * root.crop.x
                    y: (preview.height - preview.paintedHeight) / 2 + (preview.paintedHeight - height) * root.crop.y
                    visible: card.selected && card.loaded
                    z: 2
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.accent
                    Rectangle { width: 1; height: parent.height; x: parent.width / 2; color: Theme.accent; opacity: 0.6; visible: root.span && root.previewScreens.length === 2 }
                    Repeater {
                        model: ["l", "r", "t", "b", "tl", "tr", "bl", "br"]
                        delegate: Rectangle {
                            id: handle
                            required property string modelData
                            x: modelData.includes("l") ? -5 : modelData.includes("r") ? cropFrame.width - 5 : cropFrame.width / 2 - 5
                            y: modelData.includes("t") ? -5 : modelData.includes("b") ? cropFrame.height - 5 : cropFrame.height / 2 - 5
                            width: 10; height: 10; radius: 2; color: Theme.accent
                            MouseArea {
                                anchors.centerIn: parent
                                width: handle.modelData === "t" || handle.modelData === "b" ? cropFrame.width : 22
                                height: handle.modelData === "l" || handle.modelData === "r" ? cropFrame.height : 22
                                preventStealing: true
                                cursorShape: handle.modelData.length === 2
                                    ? (handle.modelData === "tl" || handle.modelData === "br" ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor)
                                    : (handle.modelData === "l" || handle.modelData === "r" ? Qt.SizeHorCursor : Qt.SizeVerCursor)
                                property point start
                                property var rect
                                property real initialZoom
                                onPressed: mouse => {
                                    start = mapToItem(preview, mouse.x, mouse.y);
                                    initialZoom = root.crop.zoom;
                                    rect = { x: (cropFrame.x - (preview.width - preview.paintedWidth) / 2) / preview.paintedWidth,
                                        y: (cropFrame.y - (preview.height - preview.paintedHeight) / 2) / preview.paintedHeight,
                                        w: cropFrame.width / preview.paintedWidth, h: cropFrame.height / preview.paintedHeight };
                                }
                                onPositionChanged: mouse => {
                                    if (!pressed) return;
                                    const point = mapToItem(preview, mouse.x, mouse.y);
                                    root.resizeCrop(handle.modelData, rect, (point.x - start.x) / preview.paintedWidth,
                                        (point.y - start.y) / preview.paintedHeight, initialZoom);
                                }
                            }
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: card.selected ? Qt.OpenHandCursor : Qt.PointingHandCursor
                    property real startX
                    property real startY
                    property real cropX
                    property real cropY
                    onPressed: mouse => { startX = mouse.x; startY = mouse.y; cropX = root.crop.x; cropY = root.crop.y; }
                    onPositionChanged: mouse => {
                        if (!pressed || !card.selected || !card.loaded) return;
                        const dx = preview.paintedWidth - cropFrame.width, dy = preview.paintedHeight - cropFrame.height;
                        root.setCrop(dx > 0.5 ? cropX + (mouse.x - startX) / dx : cropX,
                            dy > 0.5 ? cropY + (mouse.y - startY) / dy : cropY, root.crop.zoom);
                    }
                    preventStealing: card.selected
                    onClicked: { carousel.currentIndex = card.index; root.chooseWallpaper(); root.focusRow(0); }
                }
            }
        }
    }
    ListView {
        id: layouts
        onCountChanged: Qt.callLater(root.selectLayout)
        onWidthChanged: Qt.callLater(root.selectLayout)
        anchors { left: parent.left; right: parent.right; top: carousel.bottom; topMargin: 24 }
        height: root.layoutHeight + 16
        model: WidgetLayouts.layouts
        orientation: ListView.Horizontal
        spacing: 32
        clip: true
        interactive: false
        enabled: !Wallpapers.saving
        preferredHighlightBegin: (width - root.layoutWidth) / 2
        preferredHighlightEnd: preferredHighlightBegin + root.layoutWidth
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightMoveDuration: 220
        WheelHandler {
            target: null
            onWheel: event => {
                const direction = (event.angleDelta.y || event.angleDelta.x) > 0 ? 1 : -1;
                if (event.modifiers & Qt.ControlModifier) root.zoomCrop(direction);
                else { root.focusRow(1); root.step(-direction); }
                event.accepted = true;
            }
        }
        delegate: Item {
            id: layoutCard
            required property int index
            required property var modelData
            readonly property bool selected: ListView.isCurrentItem
            readonly property real totalWidth: Quickshell.screens.reduce((sum, screen) => sum + screen.width, 0) || 1
            readonly property real maxHeight: Math.max.apply(Math, [1].concat(Quickshell.screens.map(screen => screen.height)))
            width: root.layoutWidth * (selected ? 1 : 0.78)
            height: layouts.height
            opacity: selected ? 1 : 0.82
            Behavior on width { enabled: !root.restoringLayout; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 160 } }
            Accessible.role: Accessible.ListItem
            Accessible.name: modelData.name
            Accessible.description: Object.keys(modelData.widgets).map(id => root.widgetLabels[id] || id).join(", ")
            Accessible.selected: selected
            Accessible.onPressAction: { layouts.currentIndex = layoutCard.index; root.layoutTouched = true; root.focusRow(1); }
            Row {
                id: monitors
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                height: root.layoutHeight
                spacing: 6
                Repeater {
                    model: root.previewScreens
                    delegate: Rectangle {
                        id: monitor
                        required property var modelData
                        readonly property bool selectedOutput: root.span || modelData.name === root.outputName
                        readonly property bool clearedOutput: Wallpapers.outputsToClear(root.outputName, root.span).includes(modelData.name)
                        readonly property var savedLive: Wallpapers.liveFor(modelData.name)
                        readonly property var liveEntry: savedLive ? LiveWallpapers.items.find(item => item.path === savedLive.path) : null
                        readonly property string wallpaper: selectedOutput
                            ? root.animatedMode && root.selectedLive ? root.selectedLive.preview : root.selectedWallpaper
                            : clearedOutput ? Wallpapers.neutral : liveEntry ? liveEntry.preview : Wallpapers.current(modelData.name)
                        readonly property var savedScreens: savedLive ? Quickshell.screens.filter(s => savedLive.outputs.includes(s.name)) : []
                        readonly property var previewFrame: selectedOutput ? { crop: root.crop, geometry: {
                            x: root.span ? root.desktopLeft : root.targetScreen.x, y: root.span ? root.desktopTop : root.targetScreen.y,
                            width: root.frameWidth, height: root.frameHeight } } : clearedOutput ? null : savedLive && savedScreens.length ? {
                            crop: savedLive.crop || { x: 0.5, y: 0, zoom: 1 }, geometry: {
                                x: Math.min(...savedScreens.map(s => s.x)), y: Math.min(...savedScreens.map(s => s.y)),
                                width: Math.max(...savedScreens.map(s => s.x + s.width)) - Math.min(...savedScreens.map(s => s.x)),
                                height: Math.max(...savedScreens.map(s => s.y + s.height)) - Math.min(...savedScreens.map(s => s.y)) }
                            } : Wallpapers.frameFor(modelData.name)
                        readonly property real ratio: Math.min((monitors.width - Math.max(0, Quickshell.screens.length - 1) * monitors.spacing) / layoutCard.totalWidth,
                            monitors.height / layoutCard.maxHeight)
                        width: modelData.width * ratio
                        height: modelData.height * ratio
                        y: (monitors.height - height) / 2
                        color: root.animatedMode ? "black" : layoutCard.selected ? Theme.hover : Theme.raised
                        clip: true
                        transform: Matrix4x4 {
                            matrix: Qt.matrix4x4(1, -0.12, 0, monitor.height * 0.06,
                                                 0, 1, 0, 0,
                                                 0, 0, 1, 0,
                                                 0, 0, 0, 1)
                        }
                        WallpaperImage {
                            anchors.fill: parent
                            outputRect: Qt.vector4d(monitor.modelData.x, monitor.modelData.y, monitor.modelData.width, monitor.modelData.height)
                            framing: monitor.previewFrame
                            source: monitor.wallpaper === Wallpapers.neutral ? monitor.wallpaper : Wallpapers.thumbnails[monitor.wallpaper] || ""
                        }
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; top: parent.top }
                            height: Math.max(3, 40 * monitor.ratio)
                            color: Theme.surface
                            opacity: 0.85
                        }
                        Repeater {
                            model: Object.keys(layoutCard.modelData.widgets)
                            delegate: Rectangle {
                                id: miniature
                                required property string modelData
                                readonly property var entry: layoutCard.modelData.widgets[modelData]
                                readonly property real homeScale: Math.min(1, (monitor.modelData.width - 32) / 852, (monitor.modelData.height - 152) / 690)
                                readonly property real gamingScale: Math.max(0, Math.min(1, (monitor.modelData.width - 32) / 1468, (monitor.modelData.height - 152) / 420))
                                readonly property var targetOutput: WidgetLayouts.screenFor(entry.output)
                                readonly property string outputName: targetOutput ? targetOutput.name : ""
                                visible: outputName === monitor.modelData.name
                                width: (modelData === "gaming-home" ? 1468 * gamingScale : modelData === "home" ? 852 * homeScale : modelData === "neko" ? 210 : modelData === "hermes" ? 480 : ["github", "sessions", "profile"].includes(modelData) ? 340 : 286) * monitor.ratio
                                height: (modelData === "gaming-home" ? 420 * gamingScale : modelData === "home" ? 690 * homeScale : modelData === "neko" ? 210 : modelData === "hermes" ? 60 : modelData === "music" ? 120 : modelData === "github" ? 460 : modelData === "sessions" ? 350 : modelData === "profile" ? Math.min(410, Math.max(0, monitor.modelData.height - 688)) : 270) * monitor.ratio
                                x: WidgetLayouts.horizontalPosition(entry, monitor.modelData.width, width / monitor.ratio) * monitor.ratio
                                y: (modelData === "profile"
                                    ? (528 + monitor.modelData.height - 136 - height / monitor.ratio) / 2
                                    : entry.above === "limits"
                                    ? WidgetLayouts.verticalPosition(layoutCard.modelData.widgets.limits, monitor.modelData.height, 270)
                                        - height / monitor.ratio - entry.y
                                    : WidgetLayouts.verticalPosition(entry, monitor.modelData.height, height / monitor.ratio)) * monitor.ratio
                                radius: 3
                                color: ["neko", "home", "gaming-home"].includes(modelData) ? "transparent" : Theme.surface
                                border.width: ["neko", "home", "gaming-home"].includes(modelData) ? 0 : 1
                                border.color: Theme.line
                                clip: true
                                Column {
                                    anchors.centerIn: parent
                                    width: parent.width - 4
                                    spacing: 2
                                    visible: !["neko", "home", "gaming-home"].includes(miniature.modelData)
                                    PanelIcon {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 10; height: 10
                                        visible: miniature.height >= 30
                                        name: root.widgetIcons[miniature.modelData] || "applications"
                                        tint: Theme.accent
                                    }
                                }
                                Loader {
                                    anchors.fill: parent
                                    active: miniature.modelData === "neko"
                                    sourceComponent: NekoWidget { enabled: false }
                                }
                                Loader {
                                    anchors.fill: parent
                                    active: miniature.modelData === "home"
                                    sourceComponent: HomeZonePreview {}
                                }
                                Loader {
                                    anchors.fill: parent
                                    active: miniature.modelData === "gaming-home"
                                    sourceComponent: GamingHomeZonePreview {}
                                }
                            }
                        }
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.width: layoutCard.selected ? 2 : 1
                            border.color: layoutCard.selected
                                ? (root.activeRow === 1 ? Theme.accent : Theme.ink) : Theme.line
                        }
                    }
                }
            }
            MouseArea {
                id: hit
                anchors.fill: parent
                onClicked: { layouts.currentIndex = layoutCard.index; root.layoutTouched = true; root.focusRow(1); }
            }
        }
    }
    UiText {
        anchors { horizontalCenter: parent.horizontalCenter; top: layouts.bottom; topMargin: 12 }
        width: Math.min(640, root.width - 32)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: Wallpapers.error || root.selectionError
        visible: text.length > 0
        color: Theme.danger
        Accessible.role: Accessible.AlertMessage
    }
}
