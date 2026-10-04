pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    required property var output
    screen: output
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shoji-snow-near"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    surfaceFormat.opaque: false
    color: "transparent"
    mask: Region {}
}
