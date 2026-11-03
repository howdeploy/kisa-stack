pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

Item {
    id: root
    required property string outputName
    readonly property string requestedSource: Wallpapers.current(outputName)
    property string failedSource: ""
    readonly property string effectiveSource: failedSource === requestedSource ? Wallpapers.fallback : requestedSource
    readonly property var effectiveFrame: failedSource === requestedSource ? null : requestedFrame
    readonly property var requestedFrame: Wallpapers.frameFor(outputName)
    readonly property var output: Quickshell.screens.find(s => s.name === outputName)
    readonly property vector4d outputRect: Qt.vector4d(output ? output.x : 0, output ? output.y : 0, width, height)
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

    function syncCovered() {
        if (!LiveWallpapers.covered) return;
        displayedLayoutId = Wallpapers.layoutId;
        transitionLayoutId = Wallpapers.layoutId;
        loadRequested();
    }

    function loadRequested() {
        if (!initialized || !Wallpapers.ready || transitioning || preparing) return;
        if (LiveWallpapers.busy && !LiveWallpapers.covered) return;
        if (hasWallpaper && front.source.toString() === effectiveSource
                && JSON.stringify(front.framing) === JSON.stringify(effectiveFrame)
                && displayedLayoutId === Wallpapers.layoutId) return;
        back.framing = effectiveFrame;
        back.source = effectiveSource;
        maybeStart();
    }
    function maybeStart() {
        if (!initialized || transitioning || preparing || back.status !== Image.Ready
                || back.source.toString() !== effectiveSource) return;
        if (Wallpapers.targetOutput === outputName) return;
        transitionLayoutId = Wallpapers.layoutId;
        if (LiveWallpapers.covered || !hasWallpaper || front.status !== Image.Ready || wave.status === ShaderEffect.Error) {
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
    function imageFailed(item) {
        if (item !== back || item.source.toString() !== effectiveSource) return;
        console.warn("Wallpaper image could not be loaded:", item.source);
        if (effectiveSource === Wallpapers.fallback) return;
        Wallpapers.error = "Обои на " + outputName + " недоступны. Используется нейтральный фон; открой выбор обоев для повтора.";
        failedSource = requestedSource;
        Qt.callLater(loadRequested);
    }
    onRequestedSourceChanged: { failedSource = ""; Qt.callLater(loadRequested); }
    onRequestedFrameChanged: Qt.callLater(loadRequested)
    Component.onCompleted: { initialized = true; loadRequested(); }
    Connections {
        target: Wallpapers
        function onReadyChanged(): void { root.loadRequested(); }
        function onLayoutIdChanged(): void { Qt.callLater(root.loadRequested); }
        function onTargetOutputChanged(): void {
            if (Wallpapers.targetOutput === root.outputName && root.failedSource !== "") {
                root.failedSource = "";
                root.back.source = "";
                Qt.callLater(root.loadRequested);
            } else root.maybeStart();
        }
    }
    Connections {
        target: LiveWallpapers
        function onBusyChanged() { if (!LiveWallpapers.busy) root.loadRequested(); }
    }
    WallpaperImage {
        id: first
        anchors.fill: parent
        source: Wallpapers.fallback
        outputRect: root.outputRect
        pixelRatio: root.output ? root.output.devicePixelRatio : 1
        capture: root.preparing || root.transitioning
        visible: root.firstIsFront && !root.transitioning
        onStatusChanged: {
            if (status === Image.Error) root.imageFailed(first);
            root.maybeStart();
        }
    }
    WallpaperImage {
        id: second
        anchors.fill: parent
        outputRect: root.outputRect
        pixelRatio: root.output ? root.output.devicePixelRatio : 1
        capture: root.preparing || root.transitioning
        visible: !root.firstIsFront && !root.transitioning
        onStatusChanged: {
            if (status === Image.Error) root.imageFailed(second);
            root.maybeStart();
        }
    }
    ShaderEffect {
        id: wave
        anchors.fill: parent
        visible: root.transitioning
        blending: false
        property var oldImage: root.front.texture
        property var newImage: root.back.texture
        property size oldSize: Qt.size(width, height)
        property size newSize: Qt.size(width, height)
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
