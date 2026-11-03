pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    property url source
    property var framing: null
    property vector4d outputRect: Qt.vector4d(0, 0, width, height)
    property real pixelRatio: 1
    property bool capture: false
    readonly property int status: !source.toString() ? Image.Null
        : metadataError ? Image.Error : metadataSource !== source.toString() ? Image.Loading : image.status
    property string metadataSource: ""
    property bool metadataError: false
    property size originalSize: Qt.size(0, 0)
    readonly property var crop: framing && framing.crop ? framing.crop : ({ x: 0.5, y: 0.5, zoom: 1 })
    readonly property var geometry: framing && framing.geometry ? framing.geometry
        : ({ x: outputRect.x, y: outputRect.y, width: outputRect.z, height: outputRect.w })
    readonly property var texture: textureLoader.item
    function readMetadata() {
        const url = source.toString();
        if (metadataWorker.running || metadataSource === url) return;
        if (!url || /\.svg(?:[?#].*)?$/i.test(url)) {
            originalSize = Qt.size(0, 0);
            metadataError = false;
            metadataSource = url;
            return;
        }
        metadataWorker.requestSource = url;
        metadataWorker.replied = false;
        metadataWorker.command = ["python3", decodeURIComponent(Qt.resolvedUrl("wallpaper-thumbnail.py").toString().replace("file://", "")), "--size", url];
        metadataWorker.running = true;
    }
    onSourceChanged: {
        metadataSource = "";
        metadataError = false;
        originalSize = Qt.size(0, 0);
        if (metadataWorker.running) metadataWorker.running = false;
        Qt.callLater(readMetadata);
    }
    Component.onCompleted: readMetadata()
    Process {
        id: metadataWorker
        property string requestSource: ""
        property bool replied: false
        stdout: SplitParser {
            onRead: line => {
                if (metadataWorker.requestSource !== root.source.toString()) return;
                try {
                    const result = JSON.parse(line);
                    if (result.url !== metadataWorker.requestSource) return;
                    metadataWorker.replied = true;
                    root.originalSize = Qt.size(result.width || 0, result.height || 0);
                    root.metadataError = !(result.width > 0 && result.height > 0);
                    root.metadataSource = result.url;
                } catch (error) { console.warn("Could not read wallpaper dimensions"); }
            }
        }
        onExited: {
            if (requestSource === root.source.toString() && !replied) {
                root.metadataError = true;
                root.metadataSource = requestSource;
            }
            Qt.callLater(root.readMetadata);
        }
    }
    Item {
        id: content
        anchors.fill: parent
        clip: true
        Image {
            id: image
            readonly property real ratio: root.width / Math.max(1, root.outputRect.z)
            readonly property real zoom: Math.max(root.geometry.width / Math.max(1, implicitWidth),
                root.geometry.height / Math.max(1, implicitHeight)) * root.crop.zoom * ratio
            source: root.metadataSource === root.source.toString() && !root.metadataError ? root.source : ""
            asynchronous: true
            cache: false
            mipmap: true
            readonly property real decodeScale: root.originalSize.width > 0
                ? Math.min(1, Math.max(root.geometry.width / root.originalSize.width,
                    root.geometry.height / root.originalSize.height) * root.crop.zoom * ratio * root.pixelRatio) : 1
            sourceSize: root.originalSize.width > 0
                ? Qt.size(Math.max(1, Math.ceil(root.originalSize.width * decodeScale)),
                    Math.max(1, Math.ceil(root.originalSize.height * decodeScale))) : Qt.size(-1, -1)
            width: implicitWidth * zoom
            height: implicitHeight * zoom
            x: -(root.outputRect.x - root.geometry.x) * ratio - (width - root.geometry.width * ratio) * root.crop.x
            y: -(root.outputRect.y - root.geometry.y) * ratio - (height - root.geometry.height * ratio) * root.crop.y
        }
    }
    Loader {
        id: textureLoader
        active: root.capture
        sourceComponent: ShaderEffectSource {
            sourceItem: content
            visible: false
            live: true
            textureSize: Qt.size(Math.max(1, root.width * root.pixelRatio), Math.max(1, root.height * root.pixelRatio))
        }
    }
}
