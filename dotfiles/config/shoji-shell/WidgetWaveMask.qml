import QtQuick

ShaderEffect {
    property var source
    property var transitionContext
    property size screenSize
    property vector2d localOrigin
    property size widgetSize
    property real localProgress: 0
    property real localBefore: 0
    property real localAfter: 0
    property bool outgoing: false
    readonly property vector2d outputOrigin: LiveWallpapers.origin(transitionContext ? transitionContext.outputName : "")
    property size viewportSize: LiveWallpapers.busy ? LiveWallpapers.desktopSize : screenSize
    property vector2d widgetOrigin: LiveWallpapers.busy
        ? Qt.vector2d(outputOrigin.x + localOrigin.x, outputOrigin.y + localOrigin.y) : localOrigin
    property real progress: LiveWallpapers.busy ? LiveWallpapers.progress : localProgress
    property real beforeVisible: LiveWallpapers.busy ? (outgoing || !LiveWallpapers.covered ? 1 : 0) : localBefore
    property real afterVisible: LiveWallpapers.busy ? (outgoing ? 0 : 1) : localAfter
    property color accent: Theme.accent
    property color warm: "#f5c2e7"
    fragmentShader: "shaders/widget-wave-surface.frag.qsb"
}
