pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Mpris

Item {
    id: root
    property bool compact: false
    implicitWidth: 286
    implicitHeight: compact ? 206 : header.implicitHeight + 10 + spectrumSurface.height
    width: implicitWidth
    height: implicitHeight

    function sourceName(url) {
        const match = String(url || "").match(/^https:\/\/([^/?#]+)(?:[/?#]|$)/i);
        const host = match ? match[1].toLowerCase().replace(/:443$/, "") : "";
        if (host === "music.yandex.ru") return "Яндекс Музыка";
        if (["youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com"].includes(host)) return "YouTube";
        return host;
    }
    function playerSource(candidate) {
        return sourceName((candidate.metadata || {})["xesam:url"])
            || (/\s[-—]\sYouTube$/.test(candidate.trackTitle || "") ? "YouTube" : "");
    }
    readonly property var player: {
        if (!spectrumAvailable || capturePid <= 1 || ambiguousAudio) return null;
        const candidates = Mpris.players.values.filter(p => {
            if (p.dbusName === "org.mpris.MediaPlayer2.playerctld") return false;
            const nativePid = String(p.dbusName || "").match(/\.instance(\d+)$/);
            const pid = Number((p.metadata || {})["kde:pid"] || (nativePid ? nativePid[1] : 0));
            return pid === capturePid && playerSource(p);
        });
        // The captured stream is playing even when the integration reports Paused.
        const native = candidates.find(p => p.isPlaying && !(p.metadata || {})["kde:pid"]);
        const matching = native
            ? candidates.filter(p => playerSource(p) === playerSource(native)) : candidates;
        const integrated = matching.filter(p => (p.metadata || {})["kde:pid"]);
        if (integrated.length === 1) return integrated[0];
        return matching.length === 1 ? matching[0] : null;
    }
    readonly property string source: player ? playerSource(player)
        : playing && mateEngine ? "MateEngine" : ""
    readonly property bool playing: captureWanted && spectrumAvailable && capturePid > 1 && !ambiguousAudio
        && (!mateEngine || mateTrack.playing === true)
    property int capturePid: 0
    property string captureSource: ""
    readonly property bool mateEngine: captureSource === "mateengine"
    property var mateTrack: ({})
    readonly property string mateIcon: Qt.resolvedUrl("icons/mateengine.svg").toString()
    property bool ambiguousAudio: false
    readonly property string youtubeVideoId: {
        if (!player || source !== "YouTube") return "";
        const url = String((player.metadata || {})["xesam:url"] || "");
        const match = url.match(/[?&]v=([\w-]{11})(?:[&#]|$)/)
            || url.match(/\/(?:shorts|live|embed)\/([\w-]{11})(?:[/?#]|$)/);
        return match ? match[1] : "";
    }
    property var youtubeTrack: ({})
    property var youtubeRequest: null
    function loadYoutubeTrack() {
        if (youtubeRequest) youtubeRequest.abort();
        youtubeRequest = null;
        youtubeDeadline.stop();
        youtubeTrack = ({});
        const videoId = youtubeVideoId;
        if (!videoId) return;
        const request = new XMLHttpRequest();
        youtubeRequest = request;
        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE
                || root.youtubeRequest !== request || root.youtubeVideoId !== videoId) return;
            root.youtubeRequest = null;
            youtubeDeadline.stop();
            if (request.status !== 200) return;
            try {
                const value = JSON.parse(request.responseText);
                if (typeof value.title !== "string" || !value.title
                    || typeof value.author_name !== "string" || !value.author_name) return;
                root.youtubeTrack = { id: videoId, title: value.title, artist: value.author_name };
            } catch (error) { root.youtubeTrack = ({}); }
        };
        request.open("GET", "https://www.youtube.com/oembed?format=json&url="
            + encodeURIComponent("https://www.youtube.com/watch?v=" + videoId));
        request.send();
        youtubeDeadline.restart();
    }
    onYoutubeVideoIdChanged: loadYoutubeTrack()
    Component.onDestruction: { if (youtubeRequest) youtubeRequest.abort(); }
    Timer {
        id: youtubeDeadline
        interval: 10000
        onTriggered: {
            if (root.youtubeRequest) root.youtubeRequest.abort();
            root.youtubeRequest = null;
        }
    }
    readonly property string title: youtubeVideoId ? (youtubeTrack.id === youtubeVideoId ? youtubeTrack.title
        : youtubeRequest ? "Загрузка трека…" : "Название недоступно")
        : player ? player.trackTitle || source
        : ambiguousAudio ? "Несколько аудиопотоков" : playing ? (mateEngine ? (mateTrack.playing && mateTrack.title || "MateEngine") : "Звук браузера") : "Ничего не играет"
    readonly property string artist: youtubeVideoId ? (youtubeTrack.id === youtubeVideoId ? youtubeTrack.artist : "YouTube")
        : player ? player.trackArtist || source
        : ambiguousAudio ? "Источник неоднозначен" : playing ? (mateEngine ? (mateTrack.playing && mateTrack.artist || "MateEngine") : "Без данных о треке") : "Включи музыку"
    // Plasma can publish artwork from another YouTube video under the same player.
    readonly property string artwork: youtubeVideoId ? "https://i.ytimg.com/vi/" + youtubeVideoId + "/hqdefault.jpg"
        : player ? player.trackArtUrl : mateEngine && playing ? (mateTrack.playing && mateTrack.artwork || mateIcon) : ""
    property var levels: []
    property bool spectrumAvailable: false
    // MPRIS may remain paused on another tab while Web Audio is already playing.
    readonly property bool captureWanted: visible
    readonly property real rawEnergy: playing
        ? Math.max.apply(Math, [0].concat(levels)) : 0
    readonly property real bass: playing
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
            compact ? 0.78 : 0.45 + energy * 0.18, compact ? 0.66 + pulse * 0.06 : 0.72 + pulse * 0.06, 1);
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
        resetSpectrum();
    }
    function resetSpectrum() {
        levels = [];
        spectrumAvailable = false;
        capturePid = 0;
        captureSource = "";
        mateTrack = ({});
        ambiguousAudio = false;
    }
    onCaptureWantedChanged: { if (!captureWanted) stopSpectrum(); }
    Process {
        id: spectrum
        command: ["python3", Qt.resolvedUrl("music-spectrum.py").toString().replace("file://", ""), "--auto"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const frame = JSON.parse(data);
                    if (!root.captureWanted) return;
                    if (!Number.isInteger(frame.pid) || frame.pid < 0 || typeof frame.ambiguous !== "boolean") return;
                    if (frame.source !== undefined && !["", "browser", "mateengine"].includes(frame.source)) return;
                    if (!Array.isArray(frame.bars) || frame.bars.length !== 24
                        || !frame.bars.every(v => typeof v === "number" && isFinite(v) && v >= 0 && v <= 1)) return;
                    root.levels = frame.bars;
                    root.capturePid = frame.pid;
                    root.captureSource = frame.source || "";
                    root.mateTrack = frame.source === "mateengine" && frame.track && typeof frame.track === "object" ? frame.track : ({});
                    root.ambiguousAudio = frame.ambiguous;
                    root.spectrumAvailable = frame.available === true;
                    spectrumTimeout.restart();
                } catch (error) { root.resetSpectrum(); }
            }
        }
        onExited: root.resetSpectrum()
    }
    Timer { interval: 2000; repeat: true; running: root.captureWanted; triggeredOnStart: true; onTriggered: { if (!spectrum.running) spectrum.running = true; } }
    Timer { id: spectrumTimeout; interval: 3500; onTriggered: root.resetSpectrum() }

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
        visible: !root.compact
        anchors { top: parent.top; left: parent.left; right: parent.right }
        spacing: 14
        Rectangle {
            Layout.preferredWidth: root.compact ? 48 : 64; Layout.preferredHeight: root.compact ? 48 : 64
            Layout.alignment: Qt.AlignVCenter
            radius: 4; color: Theme.raised
            Image { id: cover; anchors.fill: parent; source: root.artwork; asynchronous: true; fillMode: Image.PreserveAspectCrop; sourceSize.width: 128; sourceSize.height: 128 }
            Image { anchors.fill: parent; anchors.margins: 8; source: root.mateIcon; fillMode: Image.PreserveAspectFit; visible: root.mateEngine && cover.status !== Image.Ready }
            PanelIcon { anchors.centerIn: parent; name: "headphones"; tint: Theme.muted; visible: !root.mateEngine && cover.status !== Image.Ready }
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
                font.pixelSize: root.compact ? 16 : 20; font.weight: Font.Bold
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
    ClippingRectangle {
        id: homeCover
        visible: root.compact
        x: 0; y: 0; width: 122; height: 122
        radius: 22; color: Theme.raised
        layer.enabled: root.compact
        layer.effect: MultiEffect {
            shadowEnabled: true; shadowColor: "#080810"; shadowOpacity: 0.6
            shadowVerticalOffset: 4; shadowBlur: 0.8; blurMax: 12
        }
        Image {
            id: homeArtwork
            anchors.fill: parent; source: root.compact ? root.artwork : ""
            asynchronous: true; fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(244, 244)
        }
        Image { anchors.fill: parent; anchors.margins: 16; source: root.mateIcon; fillMode: Image.PreserveAspectFit; visible: root.mateEngine && homeArtwork.status !== Image.Ready }
        PanelIcon { anchors.centerIn: parent; width: 32; height: 32; name: "headphones"; tint: Theme.ink; visible: !root.mateEngine && homeArtwork.status !== Image.Ready }
    }
    WidgetSurface {
        id: homeCard
        visible: root.compact
        x: 52; y: 62; width: root.width - 52; height: root.height - 62
        radius: 20; color: Theme.surface
        border.width: 1; border.color: "#20ffffff"
        Column {
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
            spacing: 3
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true; shadowColor: "#080810"; shadowOpacity: 1
                shadowVerticalOffset: 2; shadowBlur: 0.7; blurMax: 8
            }
            UiText {
                width: parent.width; text: root.title
                font.pixelSize: 17; font.weight: Font.Bold; color: "white"
                maximumLineCount: 2; wrapMode: Text.Wrap
                Accessible.name: text
            }
            UiText { width: parent.width; text: root.artist; font.pixelSize: 11; color: "#f2f2f2" }
        }
    }
    Item {
        id: spectrumSurface
        parent: root.compact ? homeCard : root
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        anchors.leftMargin: root.compact ? 14 : 0
        anchors.rightMargin: root.compact ? 14 : 0
        anchors.bottomMargin: root.compact ? 12 : 0
        height: root.compact ? 46 : 44
        Rectangle {
            visible: !root.compact
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
            anchors {
                fill: parent
                leftMargin: root.compact ? 0 : 16; rightMargin: root.compact ? 0 : 16
                topMargin: root.compact ? 2 : 10; bottomMargin: root.compact ? 2 : 10
            }
            Accessible.ignored: true
            layer.enabled: root.compact
            layer.effect: MultiEffect {
                shadowEnabled: true; shadowColor: "#080810"; shadowOpacity: 0.9
                shadowVerticalOffset: 2; shadowBlur: 0.6; blurMax: 8
            }
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
                            y: root.compact ? (parent.height - height) / 2 : parent.height - height
                            width: parent.width
                            height: Math.max(2, parent.height * (root.levels[index] || 0))
                            radius: root.compact ? width / 2 : 1
                            color: root.captureWanted && root.spectrumAvailable && root.rawEnergy > 0.08
                                ? root.spectrumColor(index / 23) : root.compact ? "#cdd6f4" : Theme.line
                            opacity: root.compact ? 0.90 + root.pulse * 0.10 : 0.4 + root.energy * 0.5 + root.pulse * 0.1
                            Behavior on color { ColorAnimation { duration: 160 } }
                            Behavior on height { NumberAnimation { duration: 75 } }
                        }
                    }
                }
            }
        }
    }
}
