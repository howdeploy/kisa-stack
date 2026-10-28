pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: drawer
    screen: SystemSettings.targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shoji-settings"
    WlrLayershell.keyboardFocus: requested && contentLoader.status === Loader.Ready ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    readonly property bool requested: SystemSettings.opened && !!SystemSettings.targetScreen && !Lock.locked
    property real reveal: 0
    property bool initialized: false
    visible: !!SystemSettings.targetScreen && !Lock.locked && (requested || reveal > 0)
    mask: Region { item: drawer.requested && contentLoader.status === Loader.Ready ? inputArea : null }
    Binding {
        target: SystemSettings
        property: "surfaceState"
        value: ({ requested: drawer.requested, visible: drawer.visible, reveal: drawer.reveal,
            width: drawer.width, height: drawer.height, contentStatus: contentLoader.status,
            contentWidth: contentLoader.width, contentHeight: contentLoader.height })
    }

    function syncReveal() {
        slide.stop();
        slide.from = reveal;
        slide.to = requested ? 1 : 0;
        slide.duration = Theme.duration(requested ? 280 : 220);
        slide.easing.type = requested ? Easing.OutCubic : Easing.InCubic;
        if (reveal !== slide.to) slide.start();
        if (requested) Qt.callLater(() => { if (drawer.requested && contentLoader.item) contentLoader.forceActiveFocus(); });
    }
    onRequestedChanged: { if (initialized) syncReveal(); }
    Component.onCompleted: { initialized = true; syncReveal(); }
    NumberAnimation { id: slide; target: drawer; property: "reveal" }

    FocusScope {
        id: inputArea
        anchors.fill: parent
        focus: true
        clip: true
        Keys.onEscapePressed: SystemSettings.close()
        MouseArea { anchors.fill: parent; enabled: drawer.requested; onClicked: SystemSettings.close() }
        Item {
            width: Math.max(1, Math.min(960, inputArea.width - 32))
            height: Math.max(1, Math.min(900, inputArea.height - 128))
            y: (inputArea.height - height) / 2
            x: SystemSettings.edge === "left" ? -width * (1 - drawer.reveal)
                : inputArea.width - width * drawer.reveal
            MouseArea { anchors.fill: parent; enabled: drawer.requested }
            Loader {
                id: contentLoader
                anchors.fill: parent
                active: drawer.visible
                focus: true
                sourceComponent: SystemSettingsContent {}
                onStatusChanged: {
                    if (status === Loader.Ready && drawer.requested) forceActiveFocus();
                    else if (status === Loader.Error) {
                        SystemSettings.error = "Не удалось открыть настройки. Ввод освобождён.";
                        SystemSettings.close();
                    }
                }
            }
        }
    }
}
