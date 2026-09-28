import QtQuick
import QtQuick.Controls

Slider {
    id: slider
    from: 0; to: 1
    implicitHeight: 28
    leftPadding: 0; rightPadding: 0
    background: Rectangle {
        x: slider.leftPadding + slider.handle.width / 2; y: (slider.height - height) / 2
        width: slider.availableWidth - slider.handle.width; height: 3; radius: 1.5
        color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.09)
        Rectangle {
            width: parent.width * slider.visualPosition
            height: parent.height; radius: parent.radius; color: Theme.accent
        }
    }
    handle: Rectangle {
        x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
        y: (slider.height - height) / 2
        width: 16; height: 16; radius: 8
        color: slider.enabled ? Theme.accent : Theme.muted
        border.width: slider.visualFocus ? 1 : 0
        border.color: Theme.ink
    }
}
