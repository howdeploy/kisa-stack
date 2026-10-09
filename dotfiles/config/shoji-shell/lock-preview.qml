//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "lock"

ShellRoot {
    FloatingWindow {
        id: window
        title: "Shoji · предпросмотр блокировки"
        implicitWidth: Number(Quickshell.env("SHOJI_LOCK_PREVIEW_WIDTH")) || 1280
        implicitHeight: Number(Quickshell.env("SHOJI_LOCK_PREVIEW_HEIGHT")) || 800
        visible: true
        LockView {
            id: view
            anchors.fill: parent
            preview: true
            layoutName: "EN"
            backgroundUrl: Quickshell.env("SHOJI_LOCK_BACKGROUND")
            errorMessage: Quickshell.env("SHOJI_LOCK_PREVIEW_ERROR")
            onPasswordEdited: value => passwordText = value
            onSubmitted: value => { errorMessage = "Это предпросмотр. Пароль не проверяется."; }
        }
        Timer {
            interval: 800; running: !!Quickshell.env("SHOJI_LOCK_PREVIEW_IMAGE")
            onTriggered: view.grabToImage(result => {
                result.saveToFile(Quickshell.env("SHOJI_LOCK_PREVIEW_IMAGE"));
                Qt.quit();
            })
        }
    }
}
