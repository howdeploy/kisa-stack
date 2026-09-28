pragma ComponentBehavior: Bound
import QtQuick

Loader {
    id: root
    required property string widgetId
    required property var output
    required property var transition
    property bool fits: true
    readonly property bool beforeVisible: WidgetLayouts.enabledOn(widgetId, output, transition.displayedLayoutId)
    readonly property bool afterVisible: transition.transitioning
        ? WidgetLayouts.enabledOn(widgetId, output, transition.transitionLayoutId) : beforeVisible
    readonly property bool relocating: (transition.preparing || transition.transitioning)
        && WidgetLayouts.changesPlacement(widgetId, output, transition.displayedLayoutId, transition.transitionLayoutId)
    readonly property var placement: WidgetLayouts.placement(widgetId,
        beforeVisible && !(transition.transitioning && relocating)
            ? transition.displayedLayoutId : transition.transitionLayoutId)
    x: WidgetLayouts.horizontalPosition(placement, output.width, width)
    y: WidgetLayouts.verticalPosition(placement, output.height, height)
    active: Wallpapers.ready && transition.hasWallpaper && fits && (beforeVisible || afterVisible)
    enabled: !transition.preparing && !layer.enabled
    layer.enabled: transition.transitioning && (beforeVisible !== afterVisible || relocating)
    layer.effect: WidgetWaveMask {
        viewportSize: Qt.size(root.output.width, root.output.height)
        widgetOrigin: Qt.vector2d(root.x, root.y)
        widgetSize: Qt.size(root.width, root.height)
        progress: root.transition.progress
        beforeVisible: root.beforeVisible && !root.relocating ? 1 : 0
        afterVisible: root.afterVisible ? 1 : 0
    }
    WidgetWaveSnapshot {
        id: outgoing
        parent: root.parent
        transition: root.transition
        sourceItem: root.item
        moving: root.relocating
        viewportSize: Qt.size(root.output.width, root.output.height)
        captureOrigin: Qt.vector2d(root.x, root.y)
        x: frozenOrigin.x; y: frozenOrigin.y
        width: frozenSize.width; height: frozenSize.height
    }
}
