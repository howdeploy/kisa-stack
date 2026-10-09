pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import ".." as Desktop

Rectangle {
    id: root
    color: Desktop.Theme.surface
    property string userName: Quickshell.env("USER")
    property string backgroundUrl: ""
    property string errorMessage: ""
    property string layoutName: ""
    property bool busy: false
    property bool inputEnabled: true
    property int clearSerial: 0
    property bool preview: false
    property bool capsLock: false
    property string passwordText: ""
    signal passwordEdited(string password)
    signal submitted(string password)

    function focusPassword() { if (inputEnabled && !busy) password.forceActiveFocus(); }
    function syncPassword() {
        // Do not touch the active field if it already contains the shared value:
        // this preserves its cursor/selection and never moves keyboard focus.
        if (password.text !== passwordText) password.text = passwordText;
    }
    function clearPassword() { password.clear(); passwordEdited(""); }
    onPasswordTextChanged: syncPassword()
    onInputEnabledChanged: { if (inputEnabled) Qt.callLater(focusPassword); }
    onBusyChanged: { if (!busy) Qt.callLater(focusPassword); }
    onClearSerialChanged: password.clear()
    Component.onCompleted: { syncPassword(); Qt.callLater(focusPassword); }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    Image {
        anchors.fill: parent
        source: root.backgroundUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(root.width, root.height)
    }
    Rectangle { anchors.fill: parent; color: "#bc11111b" }
    MouseArea {
        anchors.fill: parent
        onClicked: root.focusPassword()
    }

    Column {
        anchors { top: parent.top; topMargin: Math.max(24, root.height * 0.12); horizontalCenter: parent.horizontalCenter }
        spacing: 0
        visible: root.height >= 520
        Desktop.UiText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "hh:mm")
            font.pixelSize: Math.min(96, root.width * 0.13)
            font.weight: Font.Light
            font.letterSpacing: -3
        }
        Desktop.UiText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: clock.date.toLocaleDateString(Qt.locale("ru_RU"), "dddd, d MMMM")
            color: Desktop.Theme.muted
            font.pixelSize: 16
        }
    }

    ColumnLayout {
        id: form
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(20, Math.min(root.height - height - 60, root.height * 0.52 - height * 0.25))
        width: Math.min(360, Math.max(180, root.width - 48))
        spacing: 16
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 64; implicitHeight: 64; radius: 22
            color: Desktop.Theme.raised
            border.width: 1; border.color: Desktop.Theme.line
            Image {
                anchors.centerIn: parent
                width: 28; height: 28
                source: Qt.resolvedUrl("../icons/home-lock.svg")
            }
        }
        Desktop.UiText {
            Layout.fillWidth: true
            text: root.userName
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 23; font.weight: Font.DemiBold
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 7
            Desktop.UiText { text: "Пароль пользователя"; font.pixelSize: 12; color: Desktop.Theme.muted }
            TextField {
                id: password
                objectName: "lockPasswordInput"
                Layout.fillWidth: true
                implicitHeight: 52
                enabled: root.inputEnabled && !root.busy
                echoMode: TextInput.Password
                passwordMaskDelay: 0
                placeholderText: "Введите пароль"
                font.family: Desktop.Theme.font
                font.pixelSize: 16
                color: Desktop.Theme.ink
                placeholderTextColor: Desktop.Theme.muted
                selectionColor: Desktop.Theme.accent
                selectedTextColor: Desktop.Theme.surface
                leftPadding: 16; rightPadding: 16
                selectByMouse: true
                inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                Accessible.name: "Пароль пользователя " + root.userName
                background: Rectangle {
                    radius: 14
                    color: Desktop.Theme.surface
                    border.width: password.activeFocus ? 2 : 1
                    border.color: root.errorMessage ? Desktop.Theme.danger
                        : password.activeFocus ? Desktop.Theme.accent : Desktop.Theme.line
                }
                onAccepted: {
                    const value = text;
                    root.clearPassword();
                    root.submitted(value);
                }
                onTextEdited: root.passwordEdited(text)
                Keys.onEscapePressed: root.clearPassword()
                Keys.onPressed: event => {
                    // Qt exposes no portable initial Caps Lock state. Track it
                    // after a printable letter or Caps Lock event on this view.
                    if (event.key === Qt.Key_CapsLock) root.capsLock = !root.capsLock;
                    else if (event.text && event.text.toLowerCase() !== event.text.toUpperCase())
                        root.capsLock = (event.text === event.text.toUpperCase()) !== !!(event.modifiers & Qt.ShiftModifier);
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Desktop.UiText {
                    Layout.fillWidth: true
                    text: root.capsLock ? "Caps Lock включён" : ""
                    color: Desktop.Theme.danger; font.pixelSize: 11
                }
                Desktop.UiText { text: root.layoutName; color: Desktop.Theme.muted; font.pixelSize: 11 }
            }
        }
        Desktop.ActionButton {
            id: unlockButton
            Layout.fillWidth: true
            implicitHeight: 46
            highlighted: true
            text: root.busy ? "Проверяем пароль…" : "Разблокировать"
            enabled: root.inputEnabled && !root.busy
            contentItem: Text {
                text: unlockButton.text
                color: Desktop.Theme.surface
                font.family: Desktop.Theme.font
                font.pixelSize: 13; font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                const value = password.text;
                root.clearPassword();
                root.submitted(value);
            }
        }
        Desktop.UiText {
            Layout.fillWidth: true
            Layout.minimumHeight: 34
            text: root.errorMessage
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
            horizontalAlignment: Text.AlignHCenter
            color: Desktop.Theme.danger
            font.pixelSize: 12
            Accessible.role: Accessible.AlertMessage
        }
    }
    Desktop.UiText {
        anchors { bottom: parent.bottom; bottomMargin: 24; horizontalCenter: parent.horizontalCenter }
        text: root.preview ? "Предпросмотр · экран не заблокирован" : "Сессия заблокирована"
        color: Desktop.Theme.muted
        font.pixelSize: 11
    }
}
