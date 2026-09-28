pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

FocusScope {
    id: root
    required property string outputName
    focus: true
    readonly property real expandedWidth: Math.min(620, width * 0.56)
    readonly property real cardHeight: Math.min(388, height * 0.40)
    readonly property real layoutHeight: Math.min(220, height * 0.23)
    readonly property real layoutWidth: Math.min(620, width * 0.72)
    readonly property string selectedWallpaper: carousel.currentIndex >= 0 && carousel.currentIndex < carousel.count
        ? Wallpapers.library.get(carousel.currentIndex, "fileUrl").toString() : ""
    readonly property var widgetLabels: ({ limits: "Лимиты AI", sessions: "Сессии", neko: "Котик",
        github: "GitHub", hermes: "Hermes", vast: "Vast.ai", music: "Музыка" })
    readonly property var widgetIcons: ({ limits: "session-codex", sessions: "keyboard", github: "git-pull-request",
        hermes: "message-circle", vast: "cloud", music: "headphones" })
    property int activeRow: 0
    property string chosenWallpaper: ""
    property bool layoutTouched: false
    property string selectionError: ""
    readonly property bool canApply: Wallpapers.ready && !Wallpapers.saving
    function focusRow(row) { activeRow = row; selectionError = ""; forceActiveFocus(); }
    function step(direction) {
        if (Wallpapers.saving) return;
        if (activeRow === 1) {
            layouts.currentIndex = Math.max(0, Math.min(layouts.count - 1, layouts.currentIndex + direction));
            layoutTouched = true;
        } else if (carousel.count) {
            carousel.currentIndex = Math.max(0, Math.min(carousel.count - 1, carousel.currentIndex + direction));
            chooseWallpaper();
        }
    }
    function chooseWallpaper() {
        chosenWallpaper = carousel.currentIndex >= 0 ? Wallpapers.library.get(carousel.currentIndex, "fileUrl").toString() : "";
        selectionError = "";
    }
    function requestPreviews() {
        Wallpapers.requestPreviews(carousel.currentIndex, Math.ceil(width / (Math.min(136, width * 0.13) + 52) / 2) + 2);
    }
    function applySelected() {
        if (!canApply) return;
        const selected = WidgetLayouts.layouts[layouts.currentIndex];
        if (!selected) {
            selectionError = "Раскладка недоступна. Выбери другую или нажми Escape.";
            return;
        }
        if (selectedWallpaper && selectedWallpaper !== Wallpapers.current(outputName)
                && (!carousel.currentItem || !carousel.currentItem.loaded)) {
            selectionError = Wallpapers.thumbnailErrors[selectedWallpaper] || (carousel.currentItem && carousel.currentItem.failed)
                ? "Картинка недоступна. Выбери другую или нажми Escape."
                : "Превью ещё загружается. Повтори Enter после загрузки.";
            return;
        }
        Wallpapers.apply(outputName, selectedWallpaper, selected.id);
    }
    function selectSaved() {
        const selected = chosenWallpaper || Wallpapers.current(outputName);
        for (let i = 0; i < Wallpapers.library.count; i++) {
            if (Wallpapers.library.get(i, "fileUrl").toString() === selected) {
                carousel.currentIndex = i;
                requestPreviews();
                return;
            }
        }
        chosenWallpaper = "";
        carousel.currentIndex = carousel.count ? 0 : -1;
        requestPreviews();
    }
    function selectLayout() {
        if (!layoutTouched) layouts.currentIndex = Math.max(0, WidgetLayouts.layouts.findIndex(value => value.id === Wallpapers.layoutId));
    }
    Component.onCompleted: { selectSaved(); selectLayout(); forceActiveFocus(); }
    Connections {
        target: Wallpapers.library
        function onCountChanged(): void { root.selectSaved(); }
        function onStatusChanged(): void { root.selectSaved(); }
    }
    Connections {
        target: Wallpapers
        function onAcceptRequested(): void { root.applySelected(); }
        function onReadyChanged(): void { root.selectSaved(); root.selectLayout(); }
    }
    Keys.onEscapePressed: Wallpapers.cancel()
    Keys.onUpPressed: focusRow(0)
    Keys.onDownPressed: focusRow(1)
    Keys.onTabPressed: focusRow(1 - activeRow)
    Keys.onBacktabPressed: focusRow(1 - activeRow)
    Keys.onLeftPressed: step(-1)
    Keys.onRightPressed: step(1)
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
    ListView {
        id: carousel
        anchors { left: parent.left; right: parent.right }
        y: (root.height - height - root.layoutHeight - 32) / 2
        height: root.cardHeight + 48
        opacity: root.activeRow === 0 ? 1 : 0.68
        Behavior on opacity { NumberAnimation { duration: 160 } }
        model: Wallpapers.library
        orientation: ListView.Horizontal
        spacing: 52
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        snapMode: ListView.SnapToItem
        preferredHighlightBegin: (width - root.expandedWidth) / 2
        preferredHighlightEnd: preferredHighlightBegin + root.expandedWidth
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightMoveDuration: 220
        cacheBuffer: 150
        enabled: !Wallpapers.saving
        onCurrentIndexChanged: root.requestPreviews()
        onMovementEnded: root.chooseWallpaper()
        HoverHandler { onHoveredChanged: { if (hovered) root.focusRow(0); } }
        WheelHandler { target: null; onWheel: event => { root.focusRow(0); root.step((event.angleDelta.y || event.angleDelta.x) > 0 ? -1 : 1); event.accepted = true; } }
        delegate: Item {
            id: card
            required property int index
            required property url fileUrl
            required property string fileName
            readonly property bool selected: ListView.isCurrentItem
            readonly property bool loaded: preview.status === Image.Ready
            readonly property bool failed: preview.status === Image.Error
            width: selected ? root.expandedWidth : Math.min(136, root.width * 0.13)
            height: carousel.height
            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
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
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                // Diagonal slices above the shared dimmed backdrop.
                transform: Matrix4x4 {
                    matrix: Qt.matrix4x4(1, -0.12, 0, preview.height * 0.06,
                                         0, 1, 0, 0,
                                         0, 0, 1, 0,
                                         0, 0, 0, 1)
                }
                MouseArea { anchors.fill: parent; onClicked: { carousel.currentIndex = card.index; root.chooseWallpaper(); root.focusRow(0); } }
            }
        }
    }
    ListView {
        id: layouts
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
        HoverHandler { onHoveredChanged: { if (hovered) root.focusRow(1); } }
        WheelHandler { target: null; onWheel: event => { root.focusRow(1); root.step((event.angleDelta.y || event.angleDelta.x) > 0 ? -1 : 1); event.accepted = true; } }
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
            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 160 } }
            Accessible.role: Accessible.ListItem
            Accessible.name: modelData.name
            Accessible.description: Object.keys(modelData.widgets).filter(id => Settings.enabled(id)).map(id => root.widgetLabels[id] || id).join(", ")
            Accessible.selected: selected
            Accessible.onPressAction: { layouts.currentIndex = layoutCard.index; root.layoutTouched = true; root.focusRow(1); }
            Row {
                id: monitors
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                height: root.layoutHeight
                spacing: 6
                Repeater {
                    model: Quickshell.screens
                    delegate: Rectangle {
                        id: monitor
                        required property var modelData
                        readonly property string wallpaper: modelData.name === root.outputName && root.selectedWallpaper
                            ? root.selectedWallpaper : Wallpapers.current(modelData.name)
                        readonly property real ratio: Math.min((monitors.width - Math.max(0, Quickshell.screens.length - 1) * monitors.spacing) / layoutCard.totalWidth,
                            monitors.height / layoutCard.maxHeight)
                        width: modelData.width * ratio
                        height: modelData.height * ratio
                        y: (monitors.height - height) / 2
                        color: layoutCard.selected ? Theme.hover : Theme.raised
                        clip: true
                        transform: Matrix4x4 {
                            matrix: Qt.matrix4x4(1, -0.12, 0, monitor.height * 0.06,
                                                 0, 1, 0, 0,
                                                 0, 0, 1, 0,
                                                 0, 0, 0, 1)
                        }
                        Image {
                            anchors.fill: parent
                            source: Wallpapers.thumbnails[monitor.wallpaper] || monitor.wallpaper
                            sourceSize: Qt.size(640, 360)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; top: parent.top }
                            height: Math.max(3, 40 * monitor.ratio)
                            color: Theme.surface
                            opacity: 0.85
                        }
                        Repeater {
                            model: Object.keys(layoutCard.modelData.widgets).filter(id => Settings.enabled(id))
                            delegate: Rectangle {
                                id: miniature
                                required property string modelData
                                readonly property var entry: layoutCard.modelData.widgets[modelData]
                                readonly property string outputName: entry.output === "primary"
                                    ? (WidgetLayouts.primaryOutput ? WidgetLayouts.primaryOutput.name : "") : entry.output
                                visible: outputName === monitor.modelData.name
                                width: (modelData === "neko" ? 210 : modelData === "hermes" ? 480 : ["github", "sessions"].includes(modelData) ? 340 : 286) * monitor.ratio
                                height: (modelData === "neko" ? 210 : modelData === "hermes" ? 60 : modelData === "music" ? 120 : modelData === "github" ? 460 : modelData === "sessions" ? 350 : 270) * monitor.ratio
                                x: WidgetLayouts.horizontalPosition(entry, monitor.modelData.width, width / monitor.ratio) * monitor.ratio
                                y: (entry.above === "limits"
                                    ? WidgetLayouts.verticalPosition(layoutCard.modelData.widgets.limits, monitor.modelData.height, 270)
                                        - height / monitor.ratio - entry.y
                                    : WidgetLayouts.verticalPosition(entry, monitor.modelData.height, height / monitor.ratio)) * monitor.ratio
                                radius: 3
                                color: modelData === "neko" ? "transparent" : Theme.surface
                                border.width: modelData === "neko" ? 0 : 1
                                border.color: Theme.line
                                clip: true
                                Column {
                                    anchors.centerIn: parent
                                    width: parent.width - 4
                                    spacing: 2
                                    visible: miniature.modelData !== "neko"
                                    PanelIcon {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 10; height: 10
                                        visible: miniature.height >= 30
                                        name: root.widgetIcons[miniature.modelData] || "applications"
                                        tint: Theme.accent
                                    }
                                    UiText {
                                        width: parent.width
                                        text: root.widgetLabels[miniature.modelData] || miniature.modelData
                                        font.pixelSize: Math.max(7, Math.min(10, monitor.ratio * 48))
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                                Loader {
                                    anchors.fill: parent
                                    active: miniature.modelData === "neko"
                                    sourceComponent: NekoWidget { enabled: false }
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
