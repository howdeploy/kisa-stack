pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

// Adapted from bea4dev/shoji-bar-3/Lock.qml. This controller owns the password.
Singleton {
    id: root
    property bool locked: false
    readonly property bool secure: session.secure
    readonly property bool checking: pam.active || release.running || LockScene.preparing
    readonly property int typed: Array.from(secret).length
    readonly property string user: Quickshell.env("USER") || ""
    readonly property string time: Qt.formatDateTime(clock.date, "HH:mm")
    readonly property string date: Qt.formatDateTime(clock.date, "dddd, d MMMM")
    property string secret: ""
    property string status: ""
    property bool failed: false
    property real faceOpacity: 1
    property bool dpmsAvailable: false
    property bool screensOffRequested: false
    property int powerRequest: 0

    function engage() {
        if (locked) return;
        LockScene.cancel();
        secret = "";
        status = "";
        failed = false;
        faceOpacity = 1;
        locked = true;
        session.locked = true;
    }
    onLockedChanged: LockScene.active = locked
    function finishUnlock(wave) {
        if (!locked) return;
        session.locked = false;
        locked = false;
        if (wave) LockScene.start();
        else LockScene.cancel();
    }
    Connections {
        target: LockScene
        function onPrepared(): void { root.finishUnlock(true); }
        function onFailed(): void { if (root.locked && !release.running) release.start(); }
    }
    function type(text) {
        if (checking) return;
        failed = false;
        status = "";
        secret += text;
    }
    function erase() {
        if (!checking) secret = Array.from(secret).slice(0, -1).join("");
    }
    function clear() {
        if (!checking) secret = "";
    }
    function displayPassword(reveal) {
        return reveal && secure && !checking ? secret : "●".repeat(Math.min(typed, 30));
    }
    function submit() {
        if (checking || secret === "") return;
        failed = false;
        status = "Проверка пароля…";
        if (!pam.start()) {
            secret = "";
            failed = true;
            status = "Не удалось начать проверку пароля";
        }
    }
    function setPower(power) {
        const socket = powerConnection.item;
        if (!dpmsAvailable || !socket || !socket.connected) return;
        powerRequest += 1;
        socket.write(JSON.stringify({ id: powerRequest, method: "output.power",
            params: { power: power, wakeOnInput: power === "off" } }) + "\n");
        socket.flush();
        screensOffRequested = power === "off";
    }

    SystemClock { id: clock; precision: SystemClock.Minutes; enabled: root.locked }
    IdleMonitor {
        enabled: root.dpmsAvailable && !root.locked
        timeout: SystemSettings.lockMinutes * 60
        respectInhibitors: false
        onIsIdleChanged: { if (isIdle) root.engage(); }
    }
    IdleMonitor {
        id: screenIdle
        enabled: root.secure && !release.running
        timeout: SystemSettings.dimMinutes * 60
        respectInhibitors: false
        onIsIdleChanged: {
            if (isIdle && root.secure && !voiceWakeHold.running) root.setPower("off");
            else if (!isIdle) {
                voiceWakeHold.stop();
                if (root.screensOffRequested) root.setPower("on");
            }
        }
    }
    Loader {
        id: powerConnection
        sourceComponent: Component {
            Socket {
                path: Quickshell.env("XDG_RUNTIME_DIR") + "/shojiwm-" + Quickshell.env("WAYLAND_DISPLAY") + ".sock"
                connected: true
                onConnectionStateChanged: {
                    root.dpmsAvailable = false;
                    if (connected) {
                        write(JSON.stringify({ id: 0, method: "output.power.available" }) + "\n");
                        flush();
                    }
                }
                parser: SplitParser {
                    onRead: data => {
                        try {
                            const message = JSON.parse(data);
                            if (message.id === 0) {
                                root.dpmsAvailable = !!message.result && message.result.available === true;
                                if (root.dpmsAvailable && screenIdle.isIdle && root.secure && !voiceWakeHold.running) root.setPower("off");
                            } else if (message.id === root.powerRequest && message.error) {
                                root.screensOffRequested = false;
                                console.warn("Screen power request failed:", message.error.message || "unknown error");
                            }
                        } catch (error) { console.warn("Screen power response:", error); }
                    }
                }
            }
        }
    }
    Timer {
        interval: 1000; repeat: true
        running: !powerConnection.item || !powerConnection.item.connected
        onTriggered: { powerConnection.active = false; powerConnection.active = true; }
    }
    Timer {
        id: voiceWakeHold
        interval: SystemSettings.dimMinutes * 60 * 1000
        onTriggered: { if (root.secure && screenIdle.isIdle) root.setPower("off"); }
    }
    WlSessionLock {
        id: session
        onSecureStateChanged: { if (secure) root.locked = true; }
        surface: WlSessionLockSurface {
            id: lockSurface
            color: LockScene.backgroundFor(lockSurface.screen.name) ? "transparent" : Theme.surface
            LockFace { anchors.fill: parent; output: lockSurface.screen; controller: root }
        }
    }
    SequentialAnimation {
        id: release
        NumberAnimation { target: root; property: "faceOpacity"; to: 0; duration: Theme.duration(120) }
        ScriptAction {
            script: {
                root.finishUnlock(false);
            }
        }
    }
    PamContext {
        id: pam
        config: "login"
        user: root.user
        onPamMessage: {
            if (responseRequired) respond(root.secret);
            else if (message !== "") root.status = message;
        }
        onCompleted: result => {
            root.secret = "";
            if (result === PamResult.Success) {
                root.status = "";
                root.setPower("on");
                if (Theme.reducedMotion) release.start();
                else LockScene.prepare();
            } else {
                root.failed = true;
                root.status = result === PamResult.MaxTries ? "Слишком много попыток. Подожди и попробуй снова"
                    : result === PamResult.Error ? "Ошибка проверки пароля" : "Неверный пароль";
            }
        }
        onError: {
            root.secret = "";
            root.failed = true;
            root.status = "Не удалось проверить пароль";
        }
    }
    IpcHandler {
        target: "session"
        function lock(): void { root.engage(); }
        function outputs(): string {
            return JSON.stringify(Quickshell.screens.map(screen => ({ name: screen.name, x: screen.x })));
        }
        function wake(): string {
            const socket = powerConnection.item;
            if (!root.dpmsAvailable || !socket || !socket.connected) {
                return JSON.stringify({ requested: false });
            }
            if (root.secure) voiceWakeHold.restart();
            root.setPower("on");
            return JSON.stringify({ requested: true, locked: root.locked });
        }
        function status(): string {
            return JSON.stringify({ locked: root.locked, secure: root.secure,
                dpmsAvailable: root.dpmsAvailable, screensOffRequested: root.screensOffRequested });
        }
    }
}
