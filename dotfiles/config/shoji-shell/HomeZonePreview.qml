pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    readonly property real ratio: width / 852
    Repeater {
        model: [
            { x: 0, y: 242, w: 252, h: 170, color: Theme.surface },
            { x: 270, y: 266, w: 276, h: 170, color: Theme.surface },
            { x: 564, y: 234, w: 122, h: 122, color: Theme.raised },
            { x: 616, y: 296, w: 236, h: 144, color: Theme.surface },
            { x: 4, y: 430, w: 76, h: 104, color: Theme.surface },
            { x: 90, y: 442, w: 76, h: 104, color: Theme.surface },
            { x: 176, y: 430, w: 76, h: 104, color: Theme.surface },
            { x: 0, y: 562, w: 252, h: 120, color: Theme.surface },
            { x: 270, y: 454, w: 285, h: 84, color: "#d8cdea" },
            { x: 567, y: 462, w: 285, h: 84, color: "#efd0c0" },
            { x: 270, y: 558, w: 187.33, h: 124, color: "#c7e0d7" },
            { x: 467.33, y: 558, w: 187.33, h: 124, color: "#e6cddd" },
            { x: 664.66, y: 558, w: 187.33, h: 124, color: "#cbdcf0" }
        ]
        Rectangle {
            required property var modelData
            x: modelData.x * root.ratio; y: modelData.y * root.ratio
            width: modelData.w * root.ratio; height: modelData.h * root.ratio
            radius: Math.max(1, 20 * root.ratio)
            color: modelData.color
        }
    }
    Repeater {
        model: 4
        Item {
            required property int index
            x: (65 + index * 174 + (index >= 2 ? 26 : 0)) * root.ratio
            width: 174 * root.ratio; height: 228 * root.ratio
            clip: true
            HomeMascot {
                anchors.fill: parent
                digit: parent.index + 1
                animate: false
            }
        }
    }
}
