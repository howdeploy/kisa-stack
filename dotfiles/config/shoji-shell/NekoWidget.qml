pragma ComponentBehavior: Bound
import QtQuick
import "NekoMotion.js" as Motion

Item {
    id: root
    implicitWidth: 210
    implicitHeight: 210
    property color milkColor: "#f3eddd"
    property var musicSource: null
    readonly property bool musicActive: !!musicSource && musicSource.playing && musicSource.spectrumAvailable
    readonly property real musicEnergy: musicActive ? musicSource.energy : 0
    readonly property real musicPulse: musicActive ? musicSource.pulse : 0
    property var previousMusicLevels: []
    onMusicSourceChanged: previousMusicLevels = []
    onMusicActiveChanged: { if (!musicActive) previousMusicLevels = []; }
    property color musicMilkColor: {
        if (!musicActive || musicEnergy <= 0.02) return milkColor;
        const tint = musicSource.spectrumColor(0.5);
        return Qt.tint(milkColor, Qt.rgba(tint.r, tint.g, tint.b,
            Math.min(0.80, 0.38 + musicEnergy * 0.40 + musicPulse * 0.25)));
    }
    Behavior on musicMilkColor { ColorAnimation { duration: 300 } }
    Connections {
        target: root.musicSource
        function onLevelsChanged() {
            const levels = root.musicSource.levels;
            if (root.visible && root.musicActive && touch && root.motion && !touch.pressed
                    && Motion.dance(root.motion, levels, root.previousMusicLevels, root.musicSource.flowPhase)) root.awake = true;
            root.previousMusicLevels = levels.slice();
        }
    }
    property real sensitivity: 12
    property var motion: Motion.create()
    property vector4d bodyMotion: Qt.vector4d(0, 0, 0, 0)
    property vector2d earMotion: Qt.vector2d(0, 0)
    property vector2d upperMotion: Qt.vector2d(0, 0)
    property bool awake: false
    property real yaw: 0.68
    readonly property real pitch: 0.38
    property real squeeze: 0
    property bool squeezing: false
    Accessible.role: Accessible.Button
    Accessible.name: "Желейный котик"
    Accessible.description: "Нажмите левую или правую кнопку, чтобы толкнуть котика. С зажатой кнопкой: влево и вправо — поворот, вниз — сжатие, вверх — растяжение"
    Accessible.onPressAction: root.poke(0.5, 0.5)

    function poke(x, y) {
        Motion.poke(motion, x, y, yaw);
        awake = true;
    }

    function excite(x, z, squash, twist) {
        Motion.excite(motion, x * Math.cos(yaw) + z * Math.sin(yaw),
                      -x * Math.sin(yaw) + z * Math.cos(yaw), squash, twist);
        awake = true;
    }
    function wrapAngle(angle) { return Math.atan2(Math.sin(angle), Math.cos(angle)); }
    onVisibleChanged: {
        if (!visible) {
            squeezing = false;
            squeeze = 0;
            awake = false;
            motion = Motion.create();
            bodyMotion = Qt.vector4d(0, 0, 0, 0);
            earMotion = Qt.vector2d(0, 0);
            upperMotion = Qt.vector2d(0, 0);
        }
    }
    FrameAnimation {
        running: root.visible && root.awake
        onTriggered: {
            root.awake = Motion.advance(root.motion, frameTime, root.squeeze, root.squeezing);
            const q = Motion.pose(root.motion);
            root.bodyMotion = Qt.vector4d(q[0], q[1], q[2], q[3]);
            root.earMotion = Qt.vector2d(q[4], q[5]);
            root.upperMotion = Qt.vector2d(q[6], q[7]);
        }
    }
    ShaderEffect {
        id: cat
        anchors.fill: parent
        blending: true
        // Cache the resting cat when another desktop widget repaints. A larger
        // offscreen target also smooths the small raymarched silhouette.
        layer.enabled: true
        layer.smooth: true
        layer.textureSize: Qt.size(Math.ceil(width * 1.5), Math.ceil(height * 1.5))
        property vector4d bodyMotion: root.bodyMotion
        property vector2d earMotion: root.earMotion
        property vector2d upperMotion: root.upperMotion
        property color milkColor: root.musicMilkColor
        property size viewportSize: Qt.size(width, height)
        property vector2d viewAngles: Qt.vector2d(root.yaw, root.pitch)
        fragmentShader: "shaders/neko-pudding.frag.qsb"
        onStatusChanged: { if (status === ShaderEffect.Error) console.warn("Neko pudding shader:", log); }
    }
    MouseArea {
        id: touch
        anchors.fill: parent
        enabled: cat.status !== ShaderEffect.Error
        hoverEnabled: false
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        preventStealing: true
        property real previousX: 0
        property real pressX: 0
        property real pressY: 0
        property real pressSquash: 0
        property bool dragging: false
        onPositionChanged: mouse => {
            if (!pressed) return;
            let dx = (mouse.x - previousX) / Math.max(1, width);
            previousX = mouse.x;
            if (!dragging) {
                if (Math.hypot(mouse.x - pressX, mouse.y - pressY) < 4) return;
                dx = (mouse.x - pressX) / Math.max(1, width);
                dragging = true;
            }
            root.yaw = root.wrapAngle(root.yaw - dx * 5.2);
            root.squeeze = Motion.clamp(pressSquash + (mouse.y - pressY) / Math.max(1, height) * 0.9, -0.16, 0.28);
            // Vertical drag only moves the held spring target. Extra squash
            // impulses would fight the finger and make release unpredictable.
            root.excite(dx * root.sensitivity * 1.25, 0, 0, -dx * 3.0);
        }
        onPressed: mouse => {
            if ((mouse.buttons & acceptedButtons) !== mouse.button) return;
            pressX = previousX = mouse.x;
            pressY = mouse.y;
            pressSquash = Motion.clamp(Motion.pose(root.motion)[2], 0.10, 0.28);
            root.squeeze = pressSquash;
            root.squeezing = true;
            dragging = false;
            root.poke(mouse.x / Math.max(1, width), mouse.y / Math.max(1, height));
        }
        onReleased: mouse => {
            if (mouse.buttons & acceptedButtons) return;
            root.squeezing = false;
            root.squeeze = 0;
            root.awake = true;
            dragging = false;
        }
        onCanceled: {
            dragging = false;
            root.squeezing = false;
            root.squeeze = 0;
            root.awake = true;
        }
    }
}
