//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
import QtQuick
import Quickshell
import "lock"

ShellRoot {
    SessionLock { id: locker }
    // Instantiate the real view and service, without requesting a lock or PAM.
    LockView { width: 360; height: 640; inputEnabled: false }
    Timer {
        interval: 300; running: true
        onTriggered: {
            if (locker.locked || locker.secure) console.error("Shoji lock check: unexpected lock");
            else {
                locker.submitPassword("guard-check");
                if (locker.busy || locker.requested || locker.pendingPassword)
                    console.error("Shoji lock check: authentication started without a secure lock");
                else console.log("SHOJI_LOCK_CHECK_OK");
            }
            Qt.quit();
        }
    }
}
