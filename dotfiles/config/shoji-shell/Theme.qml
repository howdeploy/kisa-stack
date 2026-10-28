pragma Singleton
import QtQuick
import Quickshell

Singleton {
    // Catppuccin Mocha, Mauve accent: https://catppuccin.com/palette/
    readonly property color surface: "#1e1e2e"
    readonly property color raised: "#313244"
    readonly property color hover: "#45475a"
    readonly property color accent: "#cba6f7"
    readonly property color ink: "#cdd6f4"
    readonly property color muted: "#a6adc8"
    readonly property color line: "#585b70"
    readonly property color danger: "#f38ba8"
    readonly property string font: "Noto Sans"
    readonly property int surfaceRadius: 10
    readonly property bool reducedMotion: Quickshell.env("SHOJI_REDUCED_MOTION") === "1"
    function duration(milliseconds) { return reducedMotion ? 0 : milliseconds; }
}
