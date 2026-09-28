pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root
    required property var output
    Component.onCompleted: WidgetLayouts.setTransition(output.name, wallpaperTransition)
    Component.onDestruction: {
        WidgetLayouts.setTransition(output.name, null);
        if (Wallpapers.targetOutput === output.name) Wallpapers.cancel();
    }

    PanelWindow {
        screen: root.output
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "shoji-shell"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: Theme.surface
        mask: Region {
            item: weatherLoader.item ? weatherLoader.item.attributionItem : null
            Region { item: githubLoader.active && githubLoader.enabled ? githubLoader : null }
            Region { item: sessionsLoader.active && sessionsLoader.enabled ? sessionsLoader : null }
            Region { item: nekoLoader.active && nekoLoader.enabled ? nekoLoader : null }
        }
        WallpaperTransition {
            id: wallpaperTransition
            anchors.fill: parent
            outputName: root.output.name
        }
        WidgetWaveLoader {
            id: limitsLoader
            widgetId: "limits"; output: root.output; transition: wallpaperTransition
            sourceComponent: AiLimitsWidget {}
        }
        WidgetWaveLoader {
            id: musicLoader
            widgetId: "music"; output: root.output; transition: wallpaperTransition
            y: placement.above === "limits" ? limitsLoader.y - height - placement.y
                : WidgetLayouts.verticalPosition(placement, root.output.height, height)
            sourceComponent: MusicWidget {}
        }
        Loader {
            id: weatherLoader
            anchors { left: parent.left; bottom: parent.bottom; margins: 16 }
            active: Settings.enabled("weather") && Wallpapers.layoutId !== "empty"
            sourceComponent: WeatherWidget {}
        }
        WidgetWaveLoader {
            id: vastLoader
            widgetId: "vast"; output: root.output; transition: wallpaperTransition
            sourceComponent: VastWidget {}
        }
        WidgetWaveLoader {
            id: githubLoader
            widgetId: "github"; output: root.output; transition: wallpaperTransition
            sourceComponent: GithubWidget {}
        }
        WidgetWaveLoader {
            id: sessionsLoader
            widgetId: "sessions"; output: root.output; transition: wallpaperTransition
            y: placement.vertical === "center"
                ? (limitsLoader.y + limitsLoader.height + vastLoader.y - height) / 2
                : WidgetLayouts.verticalPosition(placement, root.output.height, height)
            sourceComponent: SessionResumeWidget {}
        }
        WidgetWaveLoader {
            id: nekoLoader
            widgetId: "neko"; output: root.output; transition: wallpaperTransition
            readonly property real availableWidth: Math.max(0, musicLoader.active ? musicLoader.x - 28 : root.output.width - 32)
            width: Math.max(0, Math.min(210, availableWidth, root.output.height - 84))
            height: width
            x: musicLoader.active ? musicLoader.x - width - 12
                : WidgetLayouts.horizontalPosition(placement, root.output.width, width)
            // Compensate for the transparent margin below the resting paws.
            y: root.output.height - height + height * 0.10 - 8
            fits: width >= 96
            sourceComponent: NekoWidget { musicSource: musicLoader.active ? musicLoader.item : null }
        }
    }
    // One shared composition of the windows, beneath the shell controls.
    PanelWindow {
        screen: root.output
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "shoji-layout-melt"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        mask: Region {}
    }
    PanelWindow {
        id: picker
        screen: root.output
        anchors { top: true; bottom: true; left: true; right: true }
        readonly property bool requested: Wallpapers.targetOutput === root.output.name
        visible: requested && pickerLoader.status === Loader.Ready && !!pickerLoader.item
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "shoji-shell"
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"
        onVisibleChanged: { if (visible) pickerLoader.forceActiveFocus(); }
        FocusScope {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: Wallpapers.cancel()
            Loader {
                id: pickerLoader
                anchors.fill: parent
                focus: true
                active: picker.requested
                sourceComponent: WallpaperPicker { outputName: root.output.name }
                onStatusChanged: {
                    if (status === Loader.Error) {
                        Wallpapers.error = "Не удалось открыть меню обоев. Ввод освобождён.";
                        Wallpapers.cancel();
                    }
                }
            }
        }
        Timer {
            interval: 3000
            running: picker.requested && pickerLoader.status !== Loader.Ready
            onTriggered: Wallpapers.cancel()
        }
    }
}
