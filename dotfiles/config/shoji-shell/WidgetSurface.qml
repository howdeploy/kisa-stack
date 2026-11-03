import QtQuick

Rectangle {
    id: surface
    property real grainAlpha: 0.045
    radius: 10
    color: Qt.darker(Theme.surface, 1.12)
    border.width: 1
    border.color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.10)
    // Match the accepted limits widget's fine, stationary grain.
    Canvas {
        anchors.fill: parent
        readonly property url texture: Qt.resolvedUrl("assets/widget-grain.png")
        readonly property real strength: surface.grainAlpha / 0.045
        Component.onCompleted: loadImage(texture)
        onImageLoaded: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onStrengthChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, width, height);
            if (!isImageLoaded(texture) || width < 2 || height < 2) return;
            ctx.beginPath();
            ctx.roundedRect(1, 1, width - 2, height - 2, surface.radius - 1, surface.radius - 1);
            ctx.clip();
            ctx.fillStyle = ctx.createPattern(texture, "repeat");
            ctx.globalAlpha = strength;
            ctx.fillRect(0, 0, width, height);
        }
    }
}
