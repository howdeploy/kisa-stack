import QtQuick

Item {
    id: root
    property url source
    property var framing: null
    property vector4d outputRect: Qt.vector4d(0, 0, width, height)
    property real pixelRatio: 1
    property bool capture: false
    readonly property int status: image.status
    readonly property var crop: framing && framing.crop ? framing.crop : ({ x: 0.5, y: 0.5, zoom: 1 })
    readonly property var geometry: framing && framing.geometry ? framing.geometry
        : ({ x: outputRect.x, y: outputRect.y, width: outputRect.z, height: outputRect.w })
    property alias texture: texture
    Item {
        id: content
        anchors.fill: parent
        clip: true
        Image {
            id: image
            readonly property real ratio: root.width / Math.max(1, root.outputRect.z)
            readonly property real zoom: Math.max(root.geometry.width / Math.max(1, implicitWidth),
                root.geometry.height / Math.max(1, implicitHeight)) * root.crop.zoom * ratio
            source: root.source
            asynchronous: true
            cache: false
            mipmap: true
            // Decode the original. Capping sourceSize before a crop discards detail.
            width: implicitWidth * zoom
            height: implicitHeight * zoom
            x: -(root.outputRect.x - root.geometry.x) * ratio - (width - root.geometry.width * ratio) * root.crop.x
            y: -(root.outputRect.y - root.geometry.y) * ratio - (height - root.geometry.height * ratio) * root.crop.y
        }
    }
    ShaderEffectSource {
        id: texture
        sourceItem: content
        visible: false
        live: root.capture
        textureSize: Qt.size(Math.max(1, root.width * root.pixelRatio), Math.max(1, root.height * root.pixelRatio))
    }
}
