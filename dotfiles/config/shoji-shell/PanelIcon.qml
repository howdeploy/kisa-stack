import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: icon
    property string name
    property color tint: Theme.ink
    property real level: 1
    readonly property string motionKind: name === "bell" || name === "bell-off" ? "bell"
        : name === "wifi" || name === "wifi-off" || name === "wifi-disconnected" ? "wifi"
        : name === "volume" || name === "muted" ? "volume" : name === "brightness" ? "brightness" : ""
    function pulse() { animated.pulse(); }
    implicitWidth: 20; implicitHeight: 20
    Image { id: image; anchors.fill: parent; source: Qt.resolvedUrl("icons/" + icon.name + ".svg"); sourceSize.width: 24; sourceSize.height: 24; fillMode: Image.PreserveAspectFit; visible: false }
    ColorOverlay { anchors.fill: image; source: image; color: icon.tint; visible: icon.motionKind === "" }
    MotionIcon {
        id: animated
        anchors.fill: parent
        visible: icon.motionKind !== ""
        kind: icon.motionKind
        active: icon.name !== "bell-off" && icon.name !== "wifi-off" && icon.name !== "wifi-disconnected" && icon.name !== "muted"
        level: icon.level
        tint: icon.tint
    }
}
