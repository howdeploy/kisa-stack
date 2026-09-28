import QtQuick

Rectangle {
    id: surface
    radius: 10
    color: Qt.darker(Theme.surface, 1.12)
    border.width: 1
    border.color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.08)

    // A fixed tile keeps the texture stationary while the panel changes size.
    Canvas {
        anchors.fill: parent
        readonly property url texture: Qt.resolvedUrl("assets/panel-grain.png")
        Component.onCompleted: loadImage(texture)
        onImageLoaded: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, width, height);
            if (!isImageLoaded(texture) || width < 2 || height < 2) return;
            ctx.beginPath();
            ctx.roundedRect(1, 1, width - 2, height - 2, surface.radius - 1, surface.radius - 1);
            ctx.clip();
            ctx.fillStyle = ctx.createPattern(texture, "repeat");
            ctx.globalAlpha = 0.25;
            ctx.fillRect(0, 0, width, height);
        }
    }
}
