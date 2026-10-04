pragma ComponentBehavior: Bound
import QtQuick

Image {
    id: root
    required property var transition
    required property Item sourceItem
    required property bool moving
    required property size viewportSize
    required property vector2d captureOrigin
    property bool captureEnabled: true
    property var snapshot: null
    property vector2d frozenOrigin: Qt.vector2d(0, 0)
    property size frozenSize: Qt.size(0, 0)
    source: snapshot ? snapshot.url : ""
    visible: !!snapshot && (LiveWallpapers.busy ? LiveWallpapers.covered
        : !!transition && transition.transitioning && moving)
    enabled: false
    cache: false
    layer.enabled: visible
    layer.effect: WidgetWaveMask {
        outgoing: true
        transitionContext: root.transition
        screenSize: root.viewportSize
        localOrigin: root.frozenOrigin
        widgetSize: root.frozenSize
        localProgress: root.transition ? root.transition.progress : 1
        localBefore: 1
        localAfter: 0
    }
    Connections {
        target: LiveWallpapers
        function onCaptureWidgets() {
            if (!root.captureEnabled || !root.sourceItem || !root.sourceItem.visible || root.sourceItem.width <= 0 || root.sourceItem.height <= 0) return;
            root.frozenOrigin = root.captureOrigin;
            root.frozenSize = Qt.size(root.sourceItem.width, root.sourceItem.height);
            LiveWallpapers.captureWidget(root.sourceItem, result => { root.snapshot = result; });
        }
        function onBusyChanged() {
            if (!LiveWallpapers.busy) root.snapshot = null;
        }
    }
    Connections {
        target: root.transition
        function onPrepareTransition() {
            if (!root.moving || !root.sourceItem || !root.sourceItem.visible) return;
            root.frozenOrigin = root.captureOrigin;
            root.frozenSize = Qt.size(root.sourceItem.width, root.sourceItem.height);
            // Keep the ItemGrabResult alive until the outgoing wave finishes.
            root.transition.captureWidget(root.sourceItem, result => { root.snapshot = result; });
        }
        function onTransitioningChanged() {
            if (!root.transition.transitioning && !LiveWallpapers.busy) root.snapshot = null;
        }
    }
}
