import QtQuick

ShaderEffect {
    required property string outputName
    visible: LiveWallpapers.busy
    enabled: false
    property size desktopSize: LiveWallpapers.desktopSize
    property vector2d outputOrigin: LiveWallpapers.origin(outputName)
    property size outputSize: Qt.size(width, height)
    property real progress: LiveWallpapers.progress
    property real uncovering: LiveWallpapers.uncovering ? 1 : 0
    property color backgroundColor: Theme.surface
    property color accent: Theme.accent
    property color warm: "#f5c2e7"
    fragmentShader: "shaders/live-wallpaper-wave.frag.qsb"
}
