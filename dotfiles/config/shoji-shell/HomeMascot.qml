import QtQuick
import "HomeMascots.js" as Art

Canvas {
    id: root
    property int digit: 0
    property int variant: 0
    property int tick: 0
    property bool animate: true
    readonly property var art: Art.variants[Math.max(0, Math.min(3, variant))][Math.max(0, Math.min(9, digit))]
    readonly property url atlas: Qt.resolvedUrl(art.file || "assets/home-clock-v" + (art.version || 2) + "/" + digit + ".png")
    property url loadedAtlas: ""
    property bool ready: false
    readonly property int phase: animate ? tick % 72 : 0
    readonly property bool blinking: animate && (phase === 47 || phase === 48)
    readonly property real tailAngle: animate ? Math.sin(phase * Math.PI / 36) * 0.10 : 0
    readonly property real earAngle: animate && phase >= 17 && phase <= 21
        ? Math.sin((phase - 17) * Math.PI / 4) * 0.07 : 0
    implicitWidth: 174; implicitHeight: 228
    smooth: false
    antialiasing: false
    onAtlasChanged: loadAtlas()
    onImageLoaded: { ready = isImageLoaded(atlas); requestPaint(); }
    onTickChanged: requestPaint()
    onAnimateChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: loadAtlas()

    function loadAtlas() {
        if (loadedAtlas === atlas) return;
        if (loadedAtlas.toString()) unloadImage(loadedAtlas);
        loadedAtlas = atlas;
        ready = false;
        loadImage(atlas);
        // Cached images may load synchronously without another imageLoaded signal.
        ready = isImageLoaded(atlas);
        requestPaint();
    }

    function polygon(ctx, points) {
        ctx.moveTo(points[0][0], points[0][1]);
        for (let i = 1; i < points.length; i++) ctx.lineTo(points[i][0], points[i][1]);
        ctx.closePath();
    }
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.clearRect(0, 0, width, height);
        ready = isImageLoaded(atlas);
        if (!ready) return;
        const a = art, b = a.body, t = a.tail;
        const unit = height / 228;
        const scale = Math.min((height - 12 * unit) / b[3], (width - 36 * unit) / b[2]);
        ctx.translate(Math.round((width - b[2] * scale) / 2 + (a.shift || -12) * unit), Math.round(height - 6 * unit - b[3] * scale));
        ctx.scale(scale, scale);
        ctx.translate(-b[0], -b[1]);

        // The tail is an independent layer, attached at a fixed point behind the hip.
        ctx.save();
        ctx.translate(a.hip[0], a.hip[1]);
        ctx.rotate(tailAngle);
        ctx.scale(2 / 3, 2 / 3);
        ctx.drawImage(atlas, t[0], t[1], t[2], t[3], t[0] - a.tailRoot[0], t[1] - a.tailRoot[1], t[2], t[3]);
        ctx.restore();

        ctx.save();
        ctx.beginPath();
        if (a.boundary) polygon(ctx, a.boundary);
        else ctx.rect(b[0], b[1], b[2], b[3]);
        // Keep this mask identical in every frame: Qt samples rectangular and
        // polygonal image clips differently when the atlas is scaled down.
        polygon(ctx, a.ear);
        ctx.fillRule = Qt.OddEvenFill;
        ctx.clip();
        ctx.drawImage(atlas, 0, 0);
        ctx.restore();

        ctx.save();
        ctx.translate(a.earPivot[0], a.earPivot[1]);
        ctx.rotate(earAngle);
        ctx.translate(-a.earPivot[0], -a.earPivot[1]);
        ctx.beginPath(); polygon(ctx, a.ear); ctx.clip();
        ctx.drawImage(atlas, 0, 0);
        ctx.restore();
        // Only the two eye patches change. Head, hands, body and digit stay fixed.
        if (blinking) {
            for (const eye of a.eyes)
                ctx.drawImage(atlas, eye[0] + a.blinkOffset[0], eye[1] + a.blinkOffset[1], eye[2], eye[3], eye[0], eye[1], eye[2], eye[3]);
        }
    }
}
