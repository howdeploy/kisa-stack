pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import ".." as Desktop

Item {
    id: root
    readonly property bool secure: sessionLock.secure
    readonly property bool locked: sessionLock.locked
    readonly property string userName: Quickshell.env("USER")
    property bool requested: false
    property bool busy: false
    property string pendingPassword: ""
    property string enteredPassword: ""
    property string errorMessage: ""
    property int clearSerial: 0
    property string layoutName: ""
    property string pamError: ""
    property bool responded: false

    function requestLock() {
        if (requested || locked) return;
        if (!Quickshell.env("SHOJI_LOCK_PAM_SERVICE") || !userName || Quickshell.screens.length === 0) {
            console.error("Shoji lock: missing PAM configuration, user or outputs");
            Qt.quit();
            return;
        }
        requested = true;
        sessionLock.locked = true;
        confirmationTimeout.start();
    }
    function submitPassword(value) {
        if (!secure || !requested || busy || retryDelay.running) return;
        if (!value) { errorMessage = "Введите пароль пользователя"; return; }
        errorMessage = "";
        pamError = "";
        pendingPassword = value;
        enteredPassword = "";
        responded = false;
        busy = true;
        clearSerial += 1;
        if (!pam.start()) authenticationFailed("Не удалось начать проверку пароля. Повторите попытку.");
    }
    function respondToPrompt() {
        if (!busy || !pam.active || !pam.responseRequired) return;
        // A second challenge (OTP/new password) must never receive the password
        // again. This locker only supports a single hidden password challenge.
        if (responded || pam.responseVisible) {
            pamError = "Системная проверка запросила дополнительный ответ. Этот способ входа не поддерживается.";
            pam.abort();
            authenticationFailed(pamError);
            return;
        }
        responded = true;
        const value = pendingPassword;
        pendingPassword = "";
        pam.respond(value);
    }
    function authenticationFailed(message) {
        pendingPassword = "";
        enteredPassword = "";
        busy = false;
        clearSerial += 1;
        errorMessage = message;
        retryDelay.restart();
    }

    Timer {
        id: confirmationTimeout
        interval: 5000
        onTriggered: {
            if (!sessionLock.secure) {
                console.error("Shoji lock: compositor did not confirm a secure lock");
                Qt.quit();
            }
        }
    }
    Timer { id: retryDelay; interval: 1500 }
    WlSessionLock {
        id: sessionLock
        onSecureStateChanged: {
            if (secure) { confirmationTimeout.stop(); console.log("Shoji lock: secure"); }
        }
        WlSessionLockSurface {
            id: surface
            color: Desktop.Theme.surface
            LockView {
                anchors.fill: parent
                userName: root.userName
                backgroundUrl: Quickshell.env("SHOJI_LOCK_BACKGROUND")
                busy: root.busy
                errorMessage: root.errorMessage
                clearSerial: root.clearSerial
                layoutName: root.layoutName
                passwordText: root.enteredPassword
                inputEnabled: root.secure && !retryDelay.running
                onPasswordEdited: value => root.enteredPassword = value
                onSubmitted: value => root.submitPassword(value)
            }
        }
    }
    PamContext {
        id: pam
        config: Quickshell.env("SHOJI_LOCK_PAM_SERVICE")
        configDirectory: Quickshell.env("SHOJI_LOCK_PAM_DIRECTORY") || "/etc/pam.d"
        user: root.userName
        onPamMessage: root.respondToPrompt()
        onError: error => { root.pamError = "Ошибка системной проверки пароля. Повторите попытку."; }
        onCompleted: result => {
            if (!root.busy || !root.requested) return;
            root.pendingPassword = "";
            root.enteredPassword = "";
            root.busy = false;
            root.clearSerial += 1;
            if (result === PamResult.Success && root.responded && root.secure) {
                root.requested = false;
                sessionLock.locked = false;
                // Let the event loop flush unlock_and_destroy before exiting.
                Qt.callLater(Qt.quit);
            } else {
                root.authenticationFailed(root.pamError || (result === PamResult.MaxTries
                    ? "Слишком много попыток. Подождите и повторите."
                    : "Пароль не принят. Проверьте раскладку и повторите."));
            }
        }
    }
    Socket {
        id: keyboard
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/shojiwm-" + Quickshell.env("WAYLAND_DISPLAY") + ".sock"
        connected: true
        onConnectionStateChanged: {
            if (connected) { write('{"id":"lock-keyboard","method":"keyboard.get"}\n'); flush(); }
            else root.layoutName = "";
        }
        parser: SplitParser {
            onRead: data => {
                try {
                    const message = JSON.parse(data);
                    const layout = message.event === "keyboard.changed" ? message.payload
                        : message.id === "lock-keyboard" ? message.result : null;
                    if (layout && typeof layout.name === "string")
                        root.layoutName = layout.name.startsWith("English") ? "EN"
                            : layout.name.startsWith("Russian") ? "RU" : layout.name;
                } catch (error) { /* An unavailable layout indicator cannot unlock the session. */ }
            }
        }
    }
    Timer { interval: 2000; repeat: true; running: !keyboard.connected; onTriggered: keyboard.connected = true }
    IpcHandler {
        target: "session"
        // No unlock or password API is exposed over IPC.
        function status(): string { return JSON.stringify({ locked: root.locked, secure: root.secure }); }
    }
}
