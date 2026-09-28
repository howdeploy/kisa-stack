import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: icon
    property string name
    property color tint: Theme.ink
    implicitWidth: 20; implicitHeight: 20
    Image { id: image; anchors.fill: parent; source: Qt.resolvedUrl("icons/" + icon.name + ".svg"); sourceSize.width: 24; sourceSize.height: 24; fillMode: Image.PreserveAspectFit; visible: false }
    ColorOverlay { anchors.fill: image; source: image; color: icon.tint }
}
