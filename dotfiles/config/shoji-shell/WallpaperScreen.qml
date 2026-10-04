pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root
    required property var output
    required property var shell
    Component.onCompleted: WidgetLayouts.setTransition(output.name, wallpaperTransition)
    Component.onDestruction: {
        WidgetLayouts.setTransition(output.name, null);
        if (Wallpapers.targetOutput === output.name) Wallpapers.cancel();
        if (ScreenShaders.targetOutput === output.name) ScreenShaders.cancel();
    }

    PanelWindow {
        screen: root.output
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "shoji-shell"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        surfaceFormat.opaque: false
        color: LiveWallpapers.activeOn(root.output.name) ? "transparent" : "#454545"
        mask: Region {}
        WallpaperTransition {
            id: wallpaperTransition
            anchors.fill: parent
            outputName: root.output.name
            visible: !LiveWallpapers.activeOn(root.output.name)
        }
    }
    // The compositor samples wallpaper pixels here; widgets remain above the wave.
    PanelWindow {
        screen: root.output
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "shoji-wallpaper-wave"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        mask: Region {}
    }
    PanelWindow {
        screen: root.output
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "shoji-shell"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        mask: Region {
            item: weatherLoader.item ? weatherLoader.item.attributionItem : null
            Region { item: githubLoader.active && githubLoader.enabled ? githubLoader : null }
            Region { item: profileLoader.active && profileLoader.enabled ? profileLoader : null }
            Region { item: sessionsLoader.active && sessionsLoader.enabled ? sessionsLoader : null }
            Region { item: nekoLoader.active && nekoLoader.enabled ? nekoLoader : null }
            Region { item: homeLoader.active && homeLoader.enabled ? homeLoader : null }
        }
        WidgetWaveLoader {
            id: homeLoader
            widgetId: "home"; output: root.output; transition: wallpaperTransition
            sourceComponent: HomeZone { shell: root.shell; output: root.output }
            // Keep the composition inside the usable desktop on smaller outputs.
            scale: Math.min(1, (root.output.width - 32) / 852, (root.output.height - 152) / 690)
            transformOrigin: Item.Center
        }
        WidgetWaveLoader {
            id: gamingHomeLoader
            widgetId: "gaming-home"; output: root.output; transition: wallpaperTransition
            sourceComponent: GamingHomeZone { shell: root.shell }
            scale: Math.max(0, Math.min(1, (root.output.width - 32) / 1468, (root.output.height - 152) / 420))
            transformOrigin: Item.Center
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
            active: false // Disabled by user; retain the widget for optional reuse.
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
            id: profileLoader
            widgetId: "profile"; output: root.output; transition: wallpaperTransition
            // Default's neighbours keep their old anchors while another preset fades in.
            readonly property real gapTop: WidgetLayouts.verticalPosition(WidgetLayouts.placement("github", "default"), root.output.height, githubLoader.height) + githubLoader.height + 12
            readonly property real gapBottom: WidgetLayouts.verticalPosition(WidgetLayouts.placement("music", "default"), root.output.height, musicLoader.height) - 12
            readonly property real availableHeight: Math.max(0, gapBottom - gapTop)
            height: Math.min(item ? item.implicitHeight : 0, availableHeight)
            y: gapTop + (availableHeight - height) / 2
            fits: availableHeight >= 180
            sourceComponent: ProfileWidget {}
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
    // Rear aquarium plane covers the widgets, while client windows remain above it.
    PanelWindow {
        screen: root.output
        anchors { top: true; bottom: true; left: true; right: true }
        visible: ScreenShaders.activeId === "aquarium"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "shoji-aquarium-mist"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        surfaceFormat.opaque: false
        color: "transparent"
        mask: Region {}
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
    PanelWindow {
        id: shaderPicker
        screen: root.output
        anchors { top: true; bottom: true; left: true; right: true }
        readonly property bool requested: ScreenShaders.targetOutput === root.output.name
        visible: requested && ScreenShaders.thumbnailsReady && shaderPickerLoader.status === Loader.Ready && !!shaderPickerLoader.item
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "shoji-shader-picker"
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        surfaceFormat.opaque: false
        color: "transparent"
        onVisibleChanged: { if (visible) shaderPickerLoader.forceActiveFocus(); }
        FocusScope {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: ScreenShaders.cancel()
            Loader {
                id: shaderPickerLoader
                anchors.fill: parent
                focus: true
                active: shaderPicker.requested
                sourceComponent: ShaderPicker {}
                onStatusChanged: {
                    if (status === Loader.Error) {
                        console.warn("Could not load the screen shader picker");
                        ScreenShaders.cancel();
                    }
                }
            }
        }
        Timer {
            interval: 3000
            running: shaderPicker.requested && shaderPickerLoader.status !== Loader.Ready
            onTriggered: ScreenShaders.cancel()
        }
    }
}
