import QtQuick

ShaderEffect {
    property var source
    property size viewportSize
    property vector2d widgetOrigin
    property size widgetSize
    property real progress: 0
    property real beforeVisible: 0
    property real afterVisible: 0
    fragmentShader: "shaders/widget-wave-mask.frag.qsb"
}
