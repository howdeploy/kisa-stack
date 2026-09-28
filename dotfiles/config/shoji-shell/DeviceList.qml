import QtQuick
import QtQuick.Layouts

Item {
    id: list
    property bool expanded: false
    property bool animate: true
    default property alias contents: body.data
    implicitHeight: expanded ? body.implicitHeight : 0
    Layout.fillWidth: true
    Layout.minimumHeight: 0
    Layout.maximumHeight: implicitHeight
    visible: expanded || implicitHeight > 0
    enabled: expanded
    clip: true

    // This is the only height animation; the popup follows this layout directly.
    Behavior on implicitHeight {
        enabled: list.animate
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }
    data: ColumnLayout {
        id: body
        width: list.width
        spacing: 4
    }
}
