pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string kind: "volume"
    property string layoutName: ""
    property bool armed: false
    property bool visible: false
    function showVolume() {
        if (!armed || !Services.sink || !Services.sink.audio) return;
        kind = "volume";
        visible = true;
        expiry.restart();
        feedback.restart();
    }
    function showLayout(name) {
        layoutName = name;
        kind = "layout";
        visible = true;
        expiry.restart();
    }
    // Restarting the timeout must not unmap the OSD between volume steps.
    Timer { id: expiry; interval: 1500; onTriggered: root.visible = false }
    // Coalesce rapid wheel/key steps and never overlap feedback sounds.
    Timer {
        id: feedback; interval: 120
        onTriggered: {
            if (!Services.muted && Services.volume > 0 && !sound.running)
                sound.running = true;
        }
    }
    Process {
        id: sound
        // Volume feedback is a level test; Notification has its own saved mute.
        command: ["pw-play", "--media-role", "Test", "--target", Services.sink ? Services.sink.name : "@DEFAULT_AUDIO_SINK@", "/usr/share/sounds/ocean/stereo/audio-volume-change.oga"]
        stderr: SplitParser { onRead: data => console.warn("Volume feedback:", data) }
        onExited: (exitCode, exitStatus) => { if (exitCode !== 0) console.warn("Volume feedback exited:", exitCode, exitStatus); }
    }
    // PipeWire enumerates sinks asynchronously. Do not show an OSD on startup
    // or mistake the first sample of a newly selected output for a key press.
    Timer { id: settle; interval: 350; onTriggered: root.armed = true }
    Component.onCompleted: settle.start()
    Connections {
        target: Services
        function onSinkChanged(): void { root.armed = false; feedback.stop(); settle.restart(); }
        function onVolumeChanged(): void { root.showVolume(); }
        function onMutedChanged(): void { root.showVolume(); }
    }
}
