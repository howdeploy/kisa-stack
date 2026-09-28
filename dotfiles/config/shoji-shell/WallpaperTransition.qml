pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    required property string outputName
    readonly property string requestedSource: Wallpapers.current(outputName)
    property bool initialized: false
    property bool hasWallpaper: false
    property bool firstIsFront: true
    property bool transitioning: false
    property bool preparing: false
    property int pendingCaptures: 0
    signal prepareTransition()
    property string displayedLayoutId: ""
    property string transitionLayoutId: ""
    property real progress: 0
    readonly property var front: firstIsFront ? first : second
    readonly property var back: firstIsFront ? second : first

    function loadRequested() {
        if (!initialized || !Wallpapers.ready || transitioning || preparing) return;
        if (hasWallpaper && front.source.toString() === requestedSource
                && displayedLayoutId === Wallpapers.layoutId) return;
        back.source = requestedSource;
        maybeStart();
    }
    function maybeStart() {
        if (!initialized || transitioning || preparing || back.status !== Image.Ready
                || back.source.toString() !== requestedSource) return;
        if (Wallpapers.targetOutput === outputName) return;
        transitionLayoutId = Wallpapers.layoutId;
        if (!hasWallpaper || front.status !== Image.Ready || wave.status === ShaderEffect.Error) {
            finish();
            return;
        }
        progress = 0;
        preparing = true;
        prepareTransition();
        startPrepared();
    }
    function captureWidget(item, accept) {
        pendingCaptures++;
        const complete = result => {
            try { accept(result); }
            finally {
                pendingCaptures--;
                Qt.callLater(startPrepared);
            }
        };
        if (!item.grabToImage(complete)) {
            console.warn("Could not capture outgoing widget for wallpaper transition");
            complete(null);
        }
    }
    function startPrepared() {
        if (!preparing || pendingCaptures > 0) return;
        transitioning = true;
        preparing = false;
        animation.start();
    }
    function finish() {
        const previous = front;
        firstIsFront = !firstIsFront;
        hasWallpaper = true;
        displayedLayoutId = transitionLayoutId;
        transitioning = false;
        previous.source = "";
        // A choice made during the wave becomes the next transition.
        Qt.callLater(loadRequested);
    }
    // Wallpaper and layout are committed together; start after both have changed.
    onRequestedSourceChanged: Qt.callLater(loadRequested)
    Component.onCompleted: { initialized = true; loadRequested(); }
    Connections {
        target: Wallpapers
        function onReadyChanged(): void { root.loadRequested(); }
        function onLayoutIdChanged(): void { Qt.callLater(root.loadRequested); }
        function onTargetOutputChanged(): void { root.maybeStart(); }
    }
    Image {
        id: first
        anchors.fill: parent
        source: Wallpapers.fallback
        sourceSize: Qt.size(root.width, root.height)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: root.firstIsFront && !root.transitioning
        onStatusChanged: {
            if (status === Image.Error) console.warn("Wallpaper image could not be loaded:", source);
            root.maybeStart();
        }
    }
    Image {
        id: second
        anchors.fill: parent
        sourceSize: Qt.size(root.width, root.height)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: !root.firstIsFront && !root.transitioning
        onStatusChanged: {
            if (status === Image.Error) console.warn("Wallpaper image could not be loaded:", source);
            root.maybeStart();
        }
    }
    ShaderEffect {
        id: wave
        anchors.fill: parent
        visible: root.transitioning
        blending: false
        property var oldImage: root.front
        property var newImage: root.back
        property size oldSize: Qt.size(Math.max(1, root.front.implicitWidth), Math.max(1, root.front.implicitHeight))
        property size newSize: Qt.size(Math.max(1, root.back.implicitWidth), Math.max(1, root.back.implicitHeight))
        property size viewportSize: Qt.size(width, height)
        property real progress: root.progress
        property color accent: Theme.accent
        property color warm: "#f5c2e7"
        property color backgroundColor: Theme.surface
        fragmentShader: "shaders/wallpaper-wave.frag.qsb"
        onStatusChanged: {
            if (status === ShaderEffect.Error) {
                console.warn("Wallpaper wave:", log);
                if (root.transitioning) { animation.stop(); root.finish(); }
            }
        }
    }
    NumberAnimation {
        id: animation
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: 680
        easing.type: Easing.Linear // The shader uses the reference's radial easing.
        onFinished: root.finish()
    }
}
