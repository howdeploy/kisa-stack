pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Item {
    id: root
    implicitWidth: 286
    implicitHeight: header.implicitHeight + 10 + spectrumSurface.height
    width: implicitWidth
    height: implicitHeight

    function sourceName(url) {
        const match = String(url || "").match(/^https:\/\/([^/?#]+)(?:[/?#]|$)/i);
        const host = match ? match[1].toLowerCase().replace(/:443$/, "") : "";
        if (host === "music.yandex.ru") return "Яндекс Музыка";
        if (["youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com"].includes(host)) return "YouTube";
        return host;
    }
    readonly property var player: {
        const candidates = Mpris.players.values.filter(p => p.playbackState !== MprisPlaybackState.Stopped);
        return candidates.find(p => p.isPlaying) || candidates[0] || null;
    }
    readonly property string source: player ? sourceName(player.metadata["xesam:url"]) || player.identity : ""
    readonly property bool playing: !!player && player.isPlaying
    readonly property int capturePid: player ? Number(player.metadata["kde:pid"] || 0) : 0
    readonly property string title: player ? player.trackTitle || source : "Ничего не играет"
    readonly property string artist: player ? player.trackArtist || source : "Включи музыку"
    readonly property string artwork: player ? player.trackArtUrl : ""
    property var levels: []
    property bool spectrumAvailable: false
    readonly property bool captureWanted: visible && playing && capturePid > 0
    readonly property real rawEnergy: captureWanted && spectrumAvailable
        ? Math.max.apply(Math, [0].concat(levels)) : 0
    readonly property real bass: captureWanted && spectrumAvailable
        ? Math.max.apply(Math, [0].concat(levels.slice(2, 9))) : 0
    property real energy: Math.max(0, (rawEnergy - 0.08) / 0.92)
    property real bassFloor: bass
    property real pulse: Math.min(1, Math.max(0, bass - bassFloor) * 4)
    property real flowTarget: 0
    property real flowPhase: flowTarget
    readonly property real colorStrength: energy * (0.22 + pulse * 0.08)
    Behavior on energy { SmoothedAnimation { duration: 180; velocity: -1 } }
    Behavior on bassFloor { SmoothedAnimation { duration: 650; velocity: -1 } }
    Behavior on pulse { SmoothedAnimation { duration: 120; velocity: -1 } }
    Behavior on flowPhase { SmoothedAnimation { duration: 80; velocity: -1 } }

    // One travelling palette ties the dark backdrop to the brighter spectrum.
    function spectrumColor(offset) {
        return Qt.hsla(0.54 + 0.36 * (0.5 + 0.5 * Math.sin(flowPhase - offset * 2.4)),
            0.45 + energy * 0.18, 0.72 + pulse * 0.06, 1);
    }
    function spectrumBackground(offset) {
        const tint = spectrumColor(offset);
        return Qt.tint(Qt.darker(Theme.surface, 1.25), Qt.rgba(tint.r, tint.g, tint.b, colorStrength));
    }
    Timer {
        interval: 33
        repeat: true
        running: root.captureWanted && root.spectrumAvailable && root.rawEnergy > 0.08
        property double lastTick: 0
        onRunningChanged: lastTick = Date.now()
        onTriggered: {
            const now = Date.now();
            root.flowTarget += Math.max(0, Math.min(0.1, (now - lastTick) / 1000))
                * (0.25 + root.energy * 1.4 + root.pulse * 1.8);
            lastTick = now;
        }
    }

    function stopSpectrum() {
        spectrum.running = false;
        levels = [];
        spectrumAvailable = false;
    }
    onCapturePidChanged: stopSpectrum()
    onCaptureWantedChanged: { if (!captureWanted) stopSpectrum(); }
    Process {
        id: spectrum
        command: ["python3", Qt.resolvedUrl("music-spectrum.py").toString().replace("file://", ""), String(root.capturePid)]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const frame = JSON.parse(data);
                    if (!root.captureWanted || frame.pid !== root.capturePid) return;
                    if (!Array.isArray(frame.bars) || frame.bars.length !== 24
                        || !frame.bars.every(v => typeof v === "number" && isFinite(v) && v >= 0 && v <= 1)) return;
                    root.levels = frame.bars;
                    root.spectrumAvailable = frame.available === true;
                    spectrumTimeout.restart();
                } catch (error) { root.levels = []; root.spectrumAvailable = false; }
            }
        }
        onExited: { root.levels = []; root.spectrumAvailable = false; }
    }
    Timer { interval: 2000; repeat: true; running: root.captureWanted; triggeredOnStart: true; onTriggered: { if (!spectrum.running) spectrum.running = true; } }
    Timer { id: spectrumTimeout; interval: 1500; onTriggered: { root.levels = []; root.spectrumAvailable = false; } }

    component Grain: Canvas {
        id: grain
        required property real strength
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, width, height);
            ctx.beginPath();
            ctx.roundedRect(1, 1, width - 2, height - 2, 9, 9);
            ctx.clip();
            ctx.fillStyle = "white";
            ctx.globalAlpha = grain.strength;
            let seed = 173;
            for (let i = 0; i < Math.floor(width * height / 3); i++) {
                seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
                const x = Math.floor(seed / 4294967296 * width);
                seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
                ctx.fillRect(x, Math.floor(seed / 4294967296 * height), 1, 1);
            }
        }
    }
    RowLayout {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        spacing: 14
        Rectangle {
            Layout.preferredWidth: 64; Layout.preferredHeight: 64
            Layout.alignment: Qt.AlignVCenter
            radius: 4; color: Theme.raised
            Image { id: cover; anchors.fill: parent; source: root.artwork; asynchronous: true; fillMode: Image.PreserveAspectCrop; sourceSize.width: 128; sourceSize.height: 128 }
            PanelIcon { anchors.centerIn: parent; name: "headphones"; tint: Theme.muted; visible: cover.status !== Image.Ready }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 4
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 1
                shadowVerticalOffset: 2
                shadowBlur: 0.8
                blurMax: 8
            }
            UiText {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: 20; font.weight: Font.Bold
                color: "white"
                maximumLineCount: 2; wrapMode: Text.Wrap
                Accessible.name: text
            }
            UiText {
                Layout.fillWidth: true
                text: root.artist
                font.pixelSize: 12
                color: "#f2f2f2"
            }
        }
    }
    Item {
        id: spectrumSurface
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 44
        Rectangle {
            anchors.fill: parent
            opacity: 0.55
            radius: 10
            color: Qt.darker(Theme.surface, 1.25)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: root.spectrumBackground(0) }
                GradientStop { position: 0.5; color: root.spectrumBackground(0.5) }
                GradientStop { position: 1; color: root.spectrumBackground(1) }
            }
            border.width: 1
            border.color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.06)
            Grain { strength: 0.045 }
        }
        Item {
            anchors { fill: parent; leftMargin: 16; rightMargin: 16; topMargin: 10; bottomMargin: 10 }
            Accessible.ignored: true
            Row {
                anchors.fill: parent
                spacing: 3
                Repeater {
                    model: 24
                    delegate: Item {
                        required property int index
                        width: (parent.width - 23 * 3) / 24
                        height: parent.height
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: Math.max(2, parent.height * (root.levels[index] || 0))
                            radius: 1
                            color: root.captureWanted && root.spectrumAvailable && root.rawEnergy > 0.08
                                ? root.spectrumColor(index / 23) : Theme.line
                            opacity: 0.4 + root.energy * 0.5 + root.pulse * 0.1
                            Behavior on color { ColorAnimation { duration: 160 } }
                            Behavior on height { NumberAnimation { duration: 75 } }
                        }
                    }
                }
            }
        }
    }
}
