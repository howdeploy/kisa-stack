pragma ComponentBehavior: Bound
import QtQuick

Image {
    id: root
    required property var transition
    required property Item sourceItem
    required property bool moving
    required property size viewportSize
    required property vector2d captureOrigin
    property var snapshot: null
    property vector2d frozenOrigin: Qt.vector2d(0, 0)
    property size frozenSize: Qt.size(0, 0)
    source: snapshot ? snapshot.url : ""
    visible: !!transition && transition.transitioning && moving && !!snapshot
    enabled: false
    cache: false
    layer.enabled: visible
    layer.effect: WidgetWaveMask {
        viewportSize: root.viewportSize
        widgetOrigin: root.frozenOrigin
        widgetSize: root.frozenSize
        progress: root.transition ? root.transition.progress : 1
        beforeVisible: 1
        afterVisible: 0
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
            if (!root.transition.transitioning) root.snapshot = null;
        }
    }
}
