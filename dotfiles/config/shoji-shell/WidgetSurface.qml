import QtQuick

Rectangle {
    id: surface
    radius: 10
    color: Qt.darker(Theme.surface, 1.12)
    border.width: 1
    border.color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.10)
    // Match the accepted limits widget's fine, stationary grain.
    Canvas {
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, width, height);
            ctx.beginPath();
            ctx.roundedRect(1, 1, width - 2, height - 2, surface.radius - 1, surface.radius - 1);
            ctx.clip();
            ctx.fillStyle = "white";
            ctx.globalAlpha = 0.045;
            let seed = 173;
            for (let i = 0; i < Math.floor(width * height / 3); i++) {
                seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
                const x = Math.floor(seed / 4294967296 * width);
                seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
                const y = Math.floor(seed / 4294967296 * height);
                ctx.fillRect(x, y, 1, 1);
            }
        }
    }
}
