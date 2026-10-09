//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "lock"

ShellRoot {
    SessionLock { id: locker }
    Component.onCompleted: {
        // Keep an active lock independent of source edits and panel reloads.
        Quickshell.watchFiles = false;
        Qt.callLater(locker.requestLock);
    }
}
