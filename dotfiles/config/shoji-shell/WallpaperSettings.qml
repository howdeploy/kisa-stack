pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: panel
    property bool lockScreen: false
    property string outputName: SystemSettings.targetOutput || (Quickshell.screens[0] ? Quickshell.screens[0].name : "")
    readonly property var output: Quickshell.screens.find(s => s.name === outputName) || null
    property string draft: ""
    property bool followDesktop: true
    property bool selectedStatic: false
    property string previewState: "input"
    property int imageStatus: Image.Null
    readonly property string previewSource: lockScreen && followDesktop ? SystemSettings.desktopStillFor(outputName).toString() : draft
    readonly property var previewFrame: lockScreen && followDesktop ? Wallpapers.frameFor(outputName)
        : !lockScreen && draft === Wallpapers.current(outputName).toString() ? Wallpapers.frameFor(outputName) : null
    readonly property bool working: SystemSettings.busy || Wallpapers.saving || LiveWallpapers.busy
    spacing: 14

    function resetSelection() {
        selectedStatic = !Wallpapers.liveFor(outputName);
        followDesktop = !SystemSettings.lockWallpapers[outputName];
        draft = lockScreen ? (SystemSettings.lockWallpapers[outputName] || SystemSettings.desktopStillFor(outputName)).toString()
            : SystemSettings.desktopStillFor(outputName).toString();
    }
    function choose(url) {
        draft = url.toString();
        followDesktop = false;
        selectedStatic = true;
    }
    function apply() {
        if (!output || working || (!lockScreen && !selectedStatic)) return;
        if (lockScreen) SystemSettings.setLockWallpaper(outputName, followDesktop ? "" : draft);
        else Wallpapers.apply(outputName, draft, Wallpapers.layoutId, null, previewFrame || {
            span: false, geometry: { x: output.x, y: output.y, width: output.width, height: output.height },
            crop: { x: 0.5, y: 0.5, zoom: 1 }
        });
    }
    onOutputNameChanged: resetSelection()
    onLockScreenChanged: resetSelection()
    Component.onCompleted: resetSelection()

    SettingsRow {
        label: "Монитор"
        SettingsChoice {
            hint: "Монитор для обоев"
            model: Quickshell.screens.map(s => ({ label: s.name, value: s.name }))
            currentIndex: model.findIndex(item => item.value === panel.outputName)
            onActivated: panel.outputName = currentValue
        }
    }
    SettingsRow {
        visible: panel.lockScreen
        label: "Как на рабочем столе"
        description: "Для живых обоев используется неподвижное превью"
        SettingsToggle { hint: "Обои локскрина как на рабочем столе"; selected: panel.followDesktop; onRequested: selected => panel.followDesktop = selected }
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: previewLoader.implicitHeight + 2
        radius: 10
        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.18)
        border.width: 1
        border.color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.1)
        clip: true
        Loader {
            id: previewLoader
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
            sourceComponent: panel.lockScreen ? lockPreview : desktopPreview
        }
    }
    Component {
        id: lockPreview
        LockPreview {
            id: lockView
            output: panel.output; wallpaperSource: panel.previewSource; wallpaperFrame: panel.previewFrame; stateName: panel.previewState
            onImageStatusChanged: panel.imageStatus = lockView.imageStatus
            Component.onCompleted: panel.imageStatus = lockView.imageStatus
        }
    }
    Component {
        id: desktopPreview
        Item {
            id: desktopView
            readonly property int imageStatus: wallpaper.status
            onImageStatusChanged: panel.imageStatus = desktopView.imageStatus
            Component.onCompleted: panel.imageStatus = desktopView.imageStatus
            implicitHeight: width * (panel.output ? panel.output.height / Math.max(1, panel.output.width) : 9 / 16)
            WallpaperImage {
                id: wallpaper
                anchors.fill: parent
                source: panel.previewSource
                framing: panel.previewFrame
                outputRect: Qt.vector4d(panel.output ? panel.output.x : 0, panel.output ? panel.output.y : 0,
                    panel.output ? panel.output.width : width, panel.output ? panel.output.height : height)
            }
        }
    }
    SettingsRow {
        visible: panel.lockScreen
        label: "Состояние в превью"
        SettingsChoice {
            hint: "Демонстрационное состояние локскрина"
            model: [{ label: "Ввод пароля", value: "input" }, { label: "Проверка", value: "checking" }, { label: "Ошибка", value: "error" }]
            currentIndex: model.findIndex(item => item.value === panel.previewState)
            onActivated: panel.previewState = currentValue
        }
    }
    UiText {
        Layout.fillWidth: true; wrapMode: Text.Wrap; color: Theme.muted; font.pixelSize: 11
        text: panel.lockScreen ? "Превью настоящего оформления. Точки пароля выдуманы; блокировка и проверка пароля не запускаются."
            : Wallpapers.liveFor(panel.outputName) ? "Сейчас используются живые обои. Выбор картинки заменит их только на этом мониторе."
            : "Выбери картинку ниже и примени её к монитору."
    }
    GridView {
        id: gallery
        Layout.fillWidth: true; Layout.preferredHeight: 258
        clip: true
        model: Wallpapers.library
        cellWidth: width / Math.max(1, Math.floor(width / 155))
        cellHeight: 126
        cacheBuffer: 0
        reuseItems: true
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        delegate: SettingsActionButton {
            id: tile
            required property url fileUrl
            required property string fileName
            width: gallery.cellWidth - 8; height: gallery.cellHeight - 8
            padding: 0
            hint: "Обои «" + fileName + "»"
            readonly property bool selected: (!panel.lockScreen || !panel.followDesktop) && panel.draft === fileUrl.toString()
            background: Rectangle {
                radius: 8
                color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, tile.hovered ? 0.07 : 0.025)
                border.width: 1
                border.color: tile.selected || tile.visualFocus ? Theme.accent : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.1)
                Behavior on border.color { ColorAnimation { duration: Theme.duration(180) } }
            }
            contentItem: Item {
                Image {
                    width: tile.width - 8; height: 78
                    x: 4; y: 4
                    source: tile.fileUrl
                    sourceSize: Qt.size(300, 170)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.duration(180) } }
                }
                UiText { width: tile.width - 14; x: 7; y: 88; text: tile.fileName; font.pixelSize: 10; color: tile.selected ? Theme.accent : Theme.muted }
            }
            onClicked: panel.choose(fileUrl)
        }
    }
    UiText { visible: Wallpapers.library.count === 0; text: "В папке обоев пока нет картинок"; color: Theme.muted; font.pixelSize: 12 }
    RowLayout {
        Layout.fillWidth: true
        SettingsActionButton {
            text: panel.lockScreen ? "Сохранить для локскрина" : "Применить обои"
            highlighted: true
            enabled: !!panel.output && !panel.working && SystemSettings.loaded && !!panel.previewSource
                && (panel.lockScreen || panel.selectedStatic)
                && previewLoader.status === Loader.Ready && panel.imageStatus === Image.Ready
            onClicked: panel.apply()
        }
        SettingsActionButton { text: "Вернуть сохранённое"; enabled: !panel.working; onClicked: panel.resetSelection() }
    }
    SettingsActionButton {
        visible: !panel.lockScreen
        text: "Живые обои, кадрирование и раскладки…"
        enabled: !panel.working && !!panel.output
        onClicked: { const name = panel.outputName; SystemSettings.close(); Wallpapers.toggle(name); }
    }
    UiText { visible: !panel.lockScreen && Wallpapers.error !== ""; text: Wallpapers.error; color: Theme.danger; font.pixelSize: 11; Layout.fillWidth: true; wrapMode: Text.Wrap }
}
