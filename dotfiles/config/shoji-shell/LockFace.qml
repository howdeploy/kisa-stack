pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// Presentation adapted from shoji-bar-3/components/LockFace.qml to our shell.
Item {
    id: face
    required property var output
    required property var controller
    property bool previewMode: false
    property real appearance: previewMode || Theme.reducedMotion ? 1 : 0
    Component.onCompleted: appearance = 1
    Behavior on appearance {
        NumberAnimation { duration: Theme.duration(220); easing.type: Easing.OutCubic }
    }
    readonly property bool nativeBackground: !previewMode && controller.locked && LockScene.backgroundFor(output ? output.name : "")
    property url avatarUrl: ""
    readonly property int backgroundStatus: backgroundImage.status
    property url wallpaperSource: SystemSettings.lockWallpaperFor(output ? output.name : "")
    property var wallpaperFrame: SystemSettings.lockWallpaperFrameFor(output ? output.name : "")
    property bool revealed: false
    readonly property bool ownsInput: !previewMode && Window.active && activeFocus
    readonly property bool fieldFocused: previewMode || ownsInput
    readonly property string layoutShortcut: (SystemSettings.values.keyboard || {}).options === "grp:ctrl_shift_toggle" ? "Ctrl+Shift"
        : (SystemSettings.values.keyboard || {}).options === "grp:caps_toggle" ? "Caps Lock" : "Alt+Shift"
    onOwnsInputChanged: { if (!ownsInput) revealed = false; }
    Process {
        running: true
        command: ["python3", decodeURIComponent(Qt.resolvedUrl("system-profile.py").toString().replace("file://", ""))]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const profile = JSON.parse(data);
                    if (typeof profile.avatar === "string" && profile.avatar.startsWith("file:///"))
                        face.avatarUrl = profile.avatar;
                } catch (error) { console.warn("Could not read system profile"); }
            }
        }
    }
    Connections {
        target: face.controller
        function onCheckingChanged(): void { face.revealed = false; }
        function onLockedChanged(): void { face.revealed = false; }
    }
    focus: !previewMode
    Keys.onPressed: event => {
        if (face.previewMode) return;
        if (event.key === Qt.Key_Escape || (event.key === Qt.Key_U && (event.modifiers & Qt.ControlModifier)))
            face.controller.clear();
        else if (event.key === Qt.Key_Backspace) face.controller.erase();
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) face.controller.submit();
        else if (event.text.length > 0 && event.text.charCodeAt(0) >= 0x20)
            face.controller.type(event.text);
        else return;
        event.accepted = true;
    }
    WallpaperImage {
        id: backgroundImage
        anchors.fill: parent
        source: face.nativeBackground ? "" : face.wallpaperSource
        framing: face.wallpaperFrame
        outputRect: Qt.vector4d(face.output ? face.output.x : 0, face.output ? face.output.y : 0,
            face.output ? face.output.width : face.width, face.output ? face.output.height : face.height)
        pixelRatio: face.previewMode ? face.scale : face.output ? face.output.devicePixelRatio : 1
    }
    Rectangle { anchors.fill: parent; color: "#b31e1e2e" }
    ColumnLayout {
        anchors { top: parent.top; topMargin: 48; left: parent.left; right: parent.right; leftMargin: 24; rightMargin: 24 }
        spacing: 12
        opacity: face.controller.faceOpacity * face.appearance
        UiText {
            Layout.fillWidth: true
            text: face.controller.time
            font.pixelSize: 68
            font.weight: Font.Light
            horizontalAlignment: Text.AlignHCenter
        }
        UiText {
            Layout.fillWidth: true
            text: face.controller.date
            color: Theme.muted
            font.pixelSize: 15
            horizontalAlignment: Text.AlignHCenter
        }
    }
    WidgetSurface {
        anchors { top: parent.top; right: parent.right; margins: 24 }
        opacity: face.controller.faceOpacity * face.appearance
        width: layoutBadge.implicitWidth + 28
        height: 42
        Accessible.role: Accessible.StaticText
        Accessible.name: "Раскладка: " + (Keyboard.available ? Keyboard.label : "недоступна") + ". Переключение " + face.layoutShortcut
        RowLayout {
            id: layoutBadge
            anchors.centerIn: parent
            spacing: 10
            PanelIcon { name: "keyboard"; tint: Theme.muted }
            UiText { text: Keyboard.available ? Keyboard.shortName : "—"; font.pixelSize: 16; font.weight: Font.DemiBold }
            UiText { text: face.layoutShortcut; color: Theme.muted; font.pixelSize: 11 }
        }
    }
    MouseArea {
        anchors.fill: parent
        enabled: !face.previewMode
        onPressed: mouse => { face.forceActiveFocus(); mouse.accepted = false; }
    }
    Item {
        anchors.centerIn: parent
        width: Math.min(420, face.width - 48)
        height: avatar.height + 20 + content.implicitHeight + 32
        opacity: face.controller.faceOpacity * face.appearance
        WidgetSurface {
            anchors { fill: parent; topMargin: avatar.height / 2 }
        }
        ClippingRectangle {
            id: avatar
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
            width: 96; height: 96
            radius: Theme.surfaceRadius
            color: Theme.raised
            border.width: 1
            border.color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.10)
            Image {
                id: portrait
                anchors.fill: parent
                source: face.avatarUrl
                sourceSize: Qt.size(192, 192)
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
            }
            UiText {
                anchors.centerIn: parent
                visible: portrait.status !== Image.Ready
                text: face.controller.user.slice(0, 1).toUpperCase()
                font.pixelSize: 32; font.weight: Font.DemiBold
                color: Theme.accent
            }
            Accessible.role: Accessible.Graphic
            Accessible.name: "Аватар: " + face.controller.user
        }
        ColumnLayout {
            id: content
            anchors { top: avatar.bottom; topMargin: 20; left: parent.left; right: parent.right; leftMargin: 32; rightMargin: 32 }
            spacing: 12
            UiText {
                Layout.fillWidth: true
                text: face.controller.user
                font.pixelSize: 15
                horizontalAlignment: Text.AlignHCenter
            }
            Rectangle {
                id: passwordField
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                radius: Theme.surfaceRadius
                color: face.fieldFocused ? Theme.raised : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.05)
                border.width: 1
                border.color: face.controller.failed ? Theme.danger : face.fieldFocused ? Theme.accent : Theme.line
                Accessible.role: face.previewMode ? Accessible.StaticText : Accessible.EditableText
                Accessible.name: "Пароль для разблокировки"
                Accessible.passwordEdit: !face.previewMode
                Behavior on color { ColorAnimation { duration: Theme.duration(360) } }
                Behavior on border.color { ColorAnimation { duration: Theme.duration(220) } }
                UiText {
                    x: 16; y: face.controller.typed || face.fieldFocused ? 9 : 20
                    text: "Пароль"
                    font.pixelSize: 16
                    color: Theme.muted
                    transformOrigin: Item.TopLeft
                    scale: face.controller.typed || face.fieldFocused ? 0.8 : 1
                    Behavior on y { NumberAnimation { duration: Theme.duration(460); easing.type: Easing.BezierSpline; easing.bezierCurve: [0.4, 0, 0.2, 1, 1, 1] } }
                    Behavior on scale { NumberAnimation { duration: Theme.duration(460); easing.type: Easing.BezierSpline; easing.bezierCurve: [0.4, 0, 0.2, 1, 1, 1] } }
                }
                UiText {
                    x: 16; y: 27; width: parent.width - 76
                    text: face.controller.displayPassword(face.revealed && face.ownsInput)
                    font.pixelSize: 16
                    font.letterSpacing: face.revealed && face.ownsInput ? 0 : 2
                    elide: Text.ElideLeft
                }
                ActionButton {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 5 }
                    implicitWidth: 44; implicitHeight: 44; padding: 6
                    focusPolicy: Qt.NoFocus
                    enabled: face.ownsInput && !face.controller.checking
                    hint: face.revealed ? "Скрыть пароль" : "Показать пароль на этом мониторе"
                    Accessible.checkable: true
                    Accessible.checked: face.revealed
                    contentItem: MotionIcon { kind: "eyes"; active: face.revealed; tint: Theme.ink }
                    onClicked: face.revealed = !face.revealed
                }
            }
            UiText {
                Layout.fillWidth: true
                Layout.minimumHeight: 38
                text: face.controller.status
                visible: text !== ""
                color: face.controller.failed ? Theme.danger : Theme.muted
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.Wrap
                elide: Text.ElideNone
            }
            ActionButton {
                Layout.fillWidth: true
                text: face.controller.checking ? "Проверка…" : "Разблокировать"
                highlighted: true
                focusPolicy: Qt.NoFocus
                enabled: !face.previewMode && face.controller.typed > 0 && !face.controller.checking
                onClicked: face.controller.submit()
            }
        }
    }
}
