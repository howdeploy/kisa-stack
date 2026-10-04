import QtQuick

WidgetSurface {
    id: root
    property string label
    property var value: null
    property string detail: ""
    property color accent: Theme.accent
    readonly property bool known: typeof value === "number" && isFinite(value)
    implicitWidth: 80; implicitHeight: 98
    Rectangle {
        anchors { fill: parent; margins: 1 }
        radius: 9; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.08)
    }
    UiText { x: 12; y: 11; text: root.label; font.pixelSize: 10; color: root.accent; font.weight: Font.DemiBold }
    UiText { x: 12; y: 31; text: root.known ? Math.round(root.value) + "%" : "—"; font.pixelSize: 21; font.weight: Font.Bold }
    UiText { x: 12; y: 61; width: parent.width - 24; text: root.detail; font.pixelSize: 9; color: Theme.muted }
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
        height: 3; radius: 1.5
        color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.12)
        Rectangle { width: parent.width * (root.known ? Math.max(0, Math.min(100, root.value)) / 100 : 0); height: parent.height; radius: parent.radius; color: root.accent }
    }
    Accessible.role: Accessible.Indicator
    Accessible.name: label + ": " + (known ? Math.round(value) + "% " + detail : "нет свежих данных")
}
