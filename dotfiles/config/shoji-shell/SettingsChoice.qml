pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

ComboBox {
    id: control
    property string hint: ""
    implicitWidth: 218
    implicitHeight: 36
    font.family: Theme.font
    font.pixelSize: 12
    textRole: "label"
    valueRole: "value"
    hoverEnabled: true
    Accessible.name: hint
    contentItem: UiText {
        text: control.displayText
        verticalAlignment: Text.AlignVCenter
        leftPadding: 12
        rightPadding: 28
        font.pixelSize: 12
        elide: Text.ElideRight
    }
    indicator: PanelIcon {
        name: "chevron-right"
        width: 14; height: 14
        x: control.width - width - 10; y: (control.height - height) / 2
        rotation: control.popup.visible ? -90 : 90
        Behavior on rotation { NumberAnimation { duration: Theme.duration(180); easing.type: Easing.OutCubic } }
    }
    background: Rectangle {
        radius: Theme.surfaceRadius
        color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, control.hovered ? 0.075 : 0.025)
        border.width: 1
        border.color: control.visualFocus ? Theme.accent : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.1)
        Behavior on color { ColorAnimation { duration: Theme.duration(180) } }
    }
    popup: Popup {
        y: control.height + 4
        width: control.width
        padding: 4
        implicitHeight: Math.min(contentItem.implicitHeight + 8, 280)
        background: GrainSurface { grainOpacity: 1; surfaceOpacity: 0.96 }
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.duration(150); easing.type: Easing.OutCubic } }
        exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Theme.duration(90) } }
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator {}
        }
    }
    delegate: ItemDelegate {
        id: entry
        required property var modelData
        required property int index
        width: control.width - 8
        implicitHeight: 34
        highlighted: control.highlightedIndex === entry.index
        contentItem: UiText { text: entry.modelData.label; verticalAlignment: Text.AlignVCenter; font.pixelSize: 12; elide: Text.ElideRight }
        background: Rectangle {
            radius: 7
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, entry.highlighted ? 0.12 : 0)
            Behavior on color { ColorAnimation { duration: Theme.duration(140) } }
        }
    }
}
