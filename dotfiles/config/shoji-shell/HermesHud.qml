pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "HermesProtocol.js" as Protocol

Scope {
    id: root
    required property var output
    property bool layoutEnabled: true
    readonly property var transition: output ? WidgetLayouts.transitions[output.name] || null : null
    readonly property bool beforeVisible: transition
        ? transition.hasWallpaper && WidgetLayouts.enabledOn("hermes", output, transition.displayedLayoutId)
        : layoutEnabled
    readonly property bool afterVisible: transition && transition.transitioning
        ? WidgetLayouts.enabledOn("hermes", output, transition.transitionLayoutId) : beforeVisible
    readonly property bool relocating: !!transition && (transition.preparing || transition.transitioning)
        && WidgetLayouts.changesPlacement("hermes", output, transition.displayedLayoutId, transition.transitionLayoutId)
    readonly property var wavePlacement: transition
        ? WidgetLayouts.placement("hermes", beforeVisible && !(transition.transitioning && relocating)
            ? transition.displayedLayoutId : transition.transitionLayoutId)
        : placement
    property var placement: ({ horizontal: "center", vertical: "top", x: 0, y: 68 })
    readonly property bool opensUp: wavePlacement.vertical === "bottom"
    property bool shown: true
    property bool expanded: false
    property bool pinned: false
    property bool ready: false
    property int sequence: 0
    property var pending: ({})
    property var chats: [firstChat]
    property var activeChat: firstChat
    readonly property bool busy: activeChat.busy
    readonly property bool responding: activeChat.responding
    readonly property string modelName: activeChat.modelName
    readonly property string status: activeChat.status
    readonly property string errorText: activeChat.errorText
    readonly property var transcript: activeChat.transcript
    readonly property var question: activeChat.requests.length ? activeChat.requests[0] : null
    readonly property string hermesRoot: Quickshell.env("SHOJI_HERMES_ROOT") || Quickshell.env("HOME") + "/.hermes/hermes-agent"
    onQuestionChanged: { if (responseInput) responseInput.text = ""; }
    component ChatState: QtObject {
        property int number: 1
        property string title: "Новый диалог"
        property string sessionId: ""
        property string modelName: ""
        property string draft: ""
        property string queuedText: ""
        property string status: ""
        property string errorText: ""
        property bool busy: false
        property bool responding: false
        property bool disconnected: false
        property int answerIndex: -1
        property var requests: []
        property ListModel transcript: ListModel {}
    }
    ChatState { id: firstChat }
    Component { id: chatFactory; ChatState {} }

    component HudButton: ActionButton {
        id: control
        required property string iconName
        property real iconRotation: 0
        implicitWidth: 32; implicitHeight: 32; padding: 7
        contentItem: PanelIcon {
            name: control.iconName
            rotation: control.iconRotation
            tint: control.checked ? Theme.accent : Theme.ink
        }
        background: Rectangle {
            radius: 6
            color: control.checked ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.13)
                : control.hovered ? Theme.raised : "transparent"
            border.width: control.visualFocus ? 1 : 0
            border.color: Theme.accent
        }
    }

    function rpc(method, params, chat, context) {
        const id = ++sequence;
        pending[id] = { method: method, chat: chat, context: context || null };
        backend.write(Protocol.request(id, method, params));
    }
    function send(text) {
        if (!Settings.enabled("hermes")) return;
        const chat = activeChat;
        text = text.trim();
        if (!text || chat.busy || chat.requests.length || chat.disconnected) return;
        expanded = true;
        chat.errorText = "";
        chat.queuedText = text;
        chat.draft = "";
        chat.busy = true;
        if (!chat.transcript.count) chat.title = text.replace(/\s+/g, " ").slice(0, 80);
        if (!backend.running) {
            ready = false;
            pending = ({});
            chat.status = "Подключаюсь…";
            backend.running = true;
            startup.restart();
        } else if (ready) {
            if (chat.sessionId) submitQueued(chat);
            else createSession(chat);
        }
    }
    function createSession(chat) {
        chat.status = "Открываю диалог…";
        if (Object.values(pending).some(call => call.method === "session.create" && call.chat === chat)) return;
        rpc("session.create", { title: "Shoji HUD · " + chat.title, source: "desktop", cols: 72, cwd: Quickshell.env("HOME") }, chat);
    }
    function submitQueued(chat) {
        if (!chat.queuedText || !chat.sessionId) return;
        const text = chat.queuedText;
        chat.queuedText = "";
        chat.transcript.append({ role: "user", body: text });
        chat.transcript.append({ role: "assistant", body: "" });
        chat.answerIndex = chat.transcript.count - 1;
        chat.status = "Думаю…";
        rpc("prompt.submit", { session_id: chat.sessionId, text: text, surface: "hud" }, chat);
    }
    function stop(chat) {
        chat = chat || activeChat;
        if (!chat.busy) return;
        if (chat.sessionId) {
            chat.status = "Останавливаю…";
            rpc("session.interrupt", { session_id: chat.sessionId }, chat);
        } else {
            chat.draft = chat.queuedText;
            chat.queuedText = "";
            chat.busy = false;
            chat.status = "Остановлено";
        }
    }
    function selectChat(chat) {
        activeChat = chat;
        expanded = true;
    }
    function newChat() {
        const chat = chatFactory.createObject(root, { number: chats.length + 1 });
        chats = chats.concat([chat]);
        selectChat(chat);
        composer.forceActiveFocus();
    }
    function respond(value) {
        if (!question || responding) return;
        const call = Protocol.response(question, value, activeChat.sessionId);
        activeChat.responding = true;
        rpc(call.method, call.params, activeChat, question);
        responseInput.text = "";
    }
    function settle(chat, message) {
        chat.busy = false;
        chat.responding = false;
        chat.requests = [];
        chat.status = message || "";
    }
    function disconnected(message) {
        ready = false;
        pending = ({});
        for (const chat of chats) {
            if (!chat.sessionId && !chat.busy) continue;
            chat.disconnected = !!chat.sessionId;
            chat.sessionId = "";
            chat.errorText = message;
            if (chat.queuedText) { chat.draft = chat.queuedText; chat.queuedText = ""; }
            settle(chat, "");
        }
    }
    function receive(line) {
        const frame = Protocol.decode(line);
        if (!frame) return;
        if (frame.kind === "reply") {
            const call = pending[frame.id];
            if (!call) return;
            delete pending[frame.id];
            const chat = call.chat;
            if (frame.error) {
                chat.errorText = Protocol.text(frame.error.message) || "Ошибка Hermes";
                if (frame.error.code === 4001) {
                    chat.disconnected = true;
                    chat.errorText = "Сессия закрыта Hermes. Создай новый чат.";
                    settle(chat, "");
                }
                if (chat === activeChat) expanded = true;
                if (call.context) chat.responding = false;
                else if (["session.create", "prompt.submit"].includes(call.method)) {
                    settle(chat, "");
                    if (chat.queuedText) { chat.draft = chat.queuedText; chat.queuedText = ""; }
                }
                return;
            }
            const result = frame.result;
            if (call.method === "session.create") {
                chat.sessionId = Protocol.text(result.session_id);
                chat.modelName = result.info ? Protocol.text(result.info.model) : "";
                if (!chat.sessionId) { chat.errorText = "Hermes не создал диалог"; settle(chat, ""); return; }
                if (chat.queuedText) submitQueued(chat);
            } else if (call.method === "session.interrupt") {
                // Completion owns the turn boundary; interrupt acknowledgement is not completion.
                chat.status = "Останавливаю…";
            } else if (call.context) {
                chat.responding = false;
                if (call.method === "approval.respond" && result.resolved !== true) {
                    chat.errorText = "Разрешение уже недоступно";
                }
                chat.requests = chat.requests.filter(q => !(q.id === call.context.id && q.qid === call.context.qid));
            }
            return;
        }
        const p = frame.payload;
        if (frame.type === "gateway.ready") {
            startup.stop();
            ready = true;
            for (const chat of chats) if (chat.queuedText) createSession(chat);
            return;
        }
        const chat = Protocol.sessionFor(chats, frame.session);
        if (!chat) return;
        if (frame.type === "session.info") {
            if (p.model) chat.modelName = Protocol.text(p.model);
        } else if (frame.type === "message.delta") {
            if (chat.answerIndex >= 0) chat.transcript.setProperty(chat.answerIndex, "body", chat.transcript.get(chat.answerIndex).body + Protocol.text(p.text));
            chat.status = "Пишет…";
        } else if (frame.type === "message.complete") {
            if (chat.answerIndex >= 0 && typeof p.text === "string") chat.transcript.setProperty(chat.answerIndex, "body", p.text);
            if (p.status === "error") chat.errorText = Protocol.text(p.error) || "Ошибка ответа";
            settle(chat, p.status === "interrupted" ? "Остановлено" : "");
        } else if (frame.type === "error") {
            chat.errorText = Protocol.text(p.message) || "Ошибка Hermes";
            settle(chat, "");
        } else if (frame.type === "tool.start" || frame.type === "tool.generating") {
            chat.status = Protocol.text(p.name) || "Работает…";
        } else if (frame.type === "tool.complete") {
            chat.status = "Думаю…";
        } else if (frame.type.endsWith(".request")) {
            const incoming = Protocol.questions(frame.type, p);
            if (incoming.length) {
                chat.requests = chat.requests.concat(incoming.filter(q => !chat.requests.some(old => old.id === q.id && old.qid === q.qid)));
                if (chat === activeChat) expanded = true;
                chat.status = "Жду ответа";
            } else {
                chat.errorText = "Это действие требует полного интерфейса Hermes: " + frame.type;
                if (chat === activeChat) expanded = true;
                stop(chat);
            }
        } else if (frame.type.endsWith(".expire")) {
            chat.requests = chat.requests.filter(q => q.id !== p.request_id);
            chat.responding = false;
        }
    }

    Process {
        id: backend
        command: [root.hermesRoot + "/venv/bin/python", "-u", "-m", "tui_gateway.entry"]
        workingDirectory: root.hermesRoot
        environment: ({ HERMES_HOME: Quickshell.env("HOME") + "/.hermes", PYTHONPATH: null, PYTHONHOME: null })
        stdinEnabled: true
        stdout: SplitParser { onRead: data => root.receive(data) }
        // Hermes owns its logs. Do not copy stderr, credentials or tool output into shell logs.
        stderr: SplitParser { onRead: data => {} }
        onExited: {
            startup.stop();
            root.disconnected("Hermes отключился. Создай новый чат, чтобы продолжить.");
        }
    }
    Timer {
        id: startup
        interval: 60000
        onTriggered: {
            root.disconnected("Hermes не ответил при запуске. Попробуй отправить ещё раз.");
            backend.running = false;
        }
    }
    IpcHandler {
        target: "hermes"
        function show(): void { root.shown = true; root.expanded = true; }
        function hide(): void { root.expanded = false; root.shown = false; }
        function toggle(): void { root.shown = !root.shown; }
    }

    PanelWindow {
        screen: root.output
        visible: root.shown && root.relocating && !!root.transition && root.transition.transitioning && !!outgoing.snapshot
        anchors { top: true; left: true }
        margins.left: outgoing.frozenOrigin.x
        margins.top: outgoing.frozenOrigin.y
        implicitWidth: outgoing.frozenSize.width
        implicitHeight: outgoing.frozenSize.height
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "no_blur"
        WlrLayershell.layer: root.pinned ? WlrLayer.Overlay : WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}
        WidgetWaveSnapshot {
            id: outgoing
            anchors.fill: parent
            transition: root.transition
            sourceItem: panelContent
            moving: root.relocating && root.shown
            viewportSize: Qt.size(root.output ? root.output.width : 1, root.output ? root.output.height : 1)
            captureOrigin: Qt.vector2d(
                WidgetLayouts.horizontalPosition(root.wavePlacement, viewportSize.width, panel.width),
                WidgetLayouts.verticalPosition(root.wavePlacement, viewportSize.height, panel.height))
        }
    }
    PanelWindow {
        id: panel
        screen: root.output
        visible: root.shown && (root.beforeVisible || root.afterVisible) && !!root.output
        anchors.top: root.wavePlacement.vertical !== "bottom"
        anchors.bottom: root.wavePlacement.vertical === "bottom"
        anchors.left: root.wavePlacement.horizontal === "left"
        anchors.right: root.wavePlacement.horizontal === "right"
        margins.top: root.wavePlacement.y
        margins.bottom: root.wavePlacement.y
        margins.left: root.wavePlacement.x
        margins.right: root.wavePlacement.horizontal === "center" ? -root.wavePlacement.x : root.wavePlacement.x
        implicitWidth: Math.min(480, root.output ? root.output.width - 32 : 480)
        implicitHeight: composerSurface.implicitHeight + (root.expanded ? bodyRow.implicitHeight : 0)
        Behavior on implicitHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "no_blur"
        WlrLayershell.layer: root.pinned ? WlrLayer.Overlay : WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        mask: Region { item: panelContent.enabled ? panelContent : null }

        Item {
            id: panelContent
            anchors.fill: parent
            clip: true
            enabled: !(root.transition && root.transition.preparing) && !layer.enabled
            layer.enabled: !!root.transition && root.transition.transitioning
                && (root.beforeVisible !== root.afterVisible || root.relocating)
            layer.effect: WidgetWaveMask {
                viewportSize: Qt.size(root.output ? root.output.width : 1, root.output ? root.output.height : 1)
                widgetOrigin: Qt.vector2d(
                    WidgetLayouts.horizontalPosition(root.wavePlacement, viewportSize.width, panel.width),
                    WidgetLayouts.verticalPosition(root.wavePlacement, viewportSize.height, panel.height))
                widgetSize: Qt.size(panelContent.width, panelContent.height)
                progress: root.transition ? root.transition.progress : 1
                beforeVisible: root.beforeVisible && !root.relocating ? 1 : 0
                afterVisible: root.afterVisible ? 1 : 0
            }
            WidgetSurface { anchors.fill: parent }
            Item {
                id: layout
                anchors.fill: parent
                Item {
                    id: composerSurface
                    anchors.left: parent.left
                    anchors.right: parent.right
                    y: root.opensUp ? parent.height - height : 0
                    implicitHeight: 60
                    height: implicitHeight
                    RowLayout {
                        anchors { fill: parent; margins: 14 }
                        spacing: 8
                        UiText {
                            text: "Чат " + root.activeChat.number
                            font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.accent
                        }
                        TextField {
                            id: composer
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            placeholderText: root.busy ? root.status : "Спросить Hermes…"
                            text: root.activeChat.draft
                            onTextEdited: root.activeChat.draft = text
                            font.family: Theme.font; font.pixelSize: 16
                            color: Theme.ink; placeholderTextColor: Theme.muted
                            selectByMouse: true
                            background: Item {}
                            padding: 0
                            enabled: !root.busy && !root.question && !root.activeChat.disconnected
                            Accessible.name: "Сообщение Hermes"
                            onAccepted: { if (text.trim()) root.send(text); }
                            Keys.onEscapePressed: { root.expanded = false; focus = false; }
                        }
                        HudButton {
                            iconName: root.busy ? "hud-stop" : "hud-send"
                            hint: root.busy ? "Остановить ответ" : "Отправить"
                            enabled: root.busy || (!!composer.text.trim() && !root.question && !root.activeChat.disconnected)
                            onClicked: {
                                if (root.busy) root.stop();
                                else root.send(composer.text);
                            }
                        }
                        HudButton {
                            iconName: "hud-pin"
                            hint: root.pinned ? "Открепить от переднего плана" : "Закрепить поверх окон"
                            checkable: true
                            checked: root.pinned
                            onClicked: root.pinned = checked
                        }
                        HudButton {
                            iconName: "chevron-right"
                            iconRotation: (root.expanded ? -90 : 90) * (root.opensUp ? -1 : 1)
                            Behavior on iconRotation { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                            hint: root.expanded ? "Свернуть диалог" : "Развернуть диалог"
                            onClicked: root.expanded = !root.expanded
                        }
                    }
                }
                RowLayout {
                    id: bodyRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    y: root.opensUp ? composerSurface.y - height : composerSurface.height
                    height: implicitHeight
                    enabled: root.expanded
                    opacity: root.expanded ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    spacing: 0
                    Item {
                        id: sessionSurface
                        Layout.preferredWidth: 60
                        Layout.alignment: root.opensUp ? Qt.AlignBottom : Qt.AlignTop
                        implicitHeight: 96
                        ColumnLayout {
                            anchors { fill: parent; margins: 6 }
                            spacing: 4
                            Item {
                                Layout.preferredWidth: 48
                                Layout.preferredHeight: 48
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.13)
                                    border.width: wheelArea.activeFocus ? 1 : 0
                                    border.color: Theme.accent
                                }
                                SwipeView {
                                    id: sessionSwipe
                                    anchors.fill: parent
                                    orientation: Qt.Vertical
                                    interactive: false
                                    clip: true
                                    currentIndex: root.chats.indexOf(root.activeChat)
                                    function step(direction) {
                                        const next = Math.max(0, Math.min(root.chats.length - 1, currentIndex + direction));
                                        root.selectChat(root.chats[next]);
                                    }
                                    Repeater {
                                        model: root.chats
                                        delegate: Item {
                                            id: chatPage
                                            required property var modelData
                                            UiText {
                                                anchors.centerIn: parent
                                                text: "Ч" + chatPage.modelData.number
                                                font.pixelSize: 18
                                                font.weight: Font.DemiBold
                                                color: Theme.accent
                                            }
                                            Rectangle {
                                                anchors { right: parent.right; top: parent.top; margins: 5 }
                                                width: 5; height: 5; radius: 3
                                                visible: chatPage.modelData.busy || !!chatPage.modelData.errorText
                                                color: chatPage.modelData.requests.length || chatPage.modelData.errorText ? Theme.danger : Theme.accent
                                            }
                                        }
                                    }
                                }
                                MouseArea {
                                    id: wheelArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    activeFocusOnTab: true
                                    onClicked: forceActiveFocus()
                                    onWheel: wheel => {
                                        wheel.accepted = true;
                                        if (wheel.angleDelta.y) sessionSwipe.step(wheel.angleDelta.y < 0 ? 1 : -1);
                                    }
                                    Keys.onDownPressed: sessionSwipe.step(1)
                                    Keys.onUpPressed: sessionSwipe.step(-1)
                                    Accessible.role: Accessible.SpinBox
                                    Accessible.name: "Чат " + root.activeChat.number + ": " + root.activeChat.title
                                    Accessible.description: "Колесо вниз — следующий чат, вверх — предыдущий"
                                }
                            }
                            HudButton {
                                iconName: "plus"
                                hint: "Новый чат"
                                Layout.alignment: Qt.AlignHCenter
                                onClicked: root.newChat()
                            }
                        }
                    }
                    Item {
                        id: chatSurface
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        implicitHeight: chatLayout.implicitHeight + 28
                        ColumnLayout {
                            id: chatLayout
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                            spacing: 10
                            ScrollView {
                                id: scroll
                                visible: transcript.count > 0
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.min(300, Math.max(80, root.output.height - 420), conversation.implicitHeight)
                                contentWidth: availableWidth
                                clip: true
                                Column {
                                    id: conversation
                                    width: scroll.availableWidth
                                    spacing: 12
                                    onImplicitHeightChanged: {
                                        if (scroll.contentItem && !scroll.contentItem.dragging && !scroll.contentItem.flicking)
                                            scroll.contentItem.contentY = Math.max(0, implicitHeight - scroll.availableHeight);
                                    }
                                    Repeater {
                                        model: transcript
                                        delegate: TextEdit {
                                            required property string role
                                            required property string body
                                            width: conversation.width
                                            text: body
                                            visible: body.length > 0
                                            readOnly: true; selectByMouse: true
                                            textFormat: role === "assistant" ? TextEdit.MarkdownText : TextEdit.PlainText
                                            wrapMode: TextEdit.Wrap
                                            font.family: Theme.font; font.pixelSize: 15
                                            font.weight: role === "user" ? Font.DemiBold : Font.Normal
                                            color: role === "user" ? Theme.muted : Theme.ink
                                            selectionColor: Theme.accent; selectedTextColor: Theme.surface
                                            Accessible.name: (role === "user" ? "Вы: " : "Hermes: ") + body
                                        }
                                    }
                                }
                            }
                            UiText {
                                visible: !!root.errorText
                                text: root.errorText
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap; elide: Text.ElideNone
                                font.pixelSize: 13; color: Theme.danger
                            }
                            ColumnLayout {
                                visible: !!root.question
                                Layout.fillWidth: true
                                spacing: 8
                                UiText {
                                    text: root.question ? root.question.title : ""
                                    Layout.fillWidth: true; wrapMode: Text.Wrap; elide: Text.ElideNone
                                    font.pixelSize: 15; font.weight: Font.DemiBold
                                }
                                ScrollView {
                                    visible: !!root.question && !!root.question.detail
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.min(100, requestDetail.implicitHeight)
                                    contentWidth: availableWidth
                                    clip: true
                                    TextArea {
                                        id: requestDetail
                                        text: root.question ? root.question.detail : ""
                                        readOnly: true; selectByMouse: true
                                        wrapMode: TextEdit.Wrap; textFormat: TextEdit.PlainText
                                        font.family: Theme.font; font.pixelSize: 13; color: Theme.muted
                                        background: Item {}
                                        padding: 0
                                    }
                                }
                                TextField {
                                    id: responseInput
                                    visible: !!root.question && root.question.type !== "approval.request"
                                    Layout.fillWidth: true
                                    placeholderText: "Ответ…"
                                    echoMode: root.question && root.question.secret ? TextInput.Password : TextInput.Normal
                                    font.family: Theme.font; font.pixelSize: 15
                                    color: Theme.ink; placeholderTextColor: Theme.muted
                                    background: Rectangle { color: Theme.raised; radius: 6 }
                                    enabled: !root.responding
                                    Accessible.name: "Ответ на вопрос Hermes"
                                    onAccepted: { if (text.trim()) root.respond(text); }
                                }
                                RowLayout {
                                    ActionButton {
                                        text: root.question && root.question.type === "approval.request" ? "Разрешить раз" : "Ответить"
                                        highlighted: true
                                        enabled: !root.responding && !!root.question && (root.question.type === "approval.request"
                                            ? root.question.choices.includes("once") : !!responseInput.text.trim())
                                        onClicked: root.respond(root.question.type === "approval.request" ? "once" : responseInput.text)
                                    }
                                    ActionButton {
                                        text: "Отказать"
                                        enabled: !root.responding
                                        onClicked: root.respond(root.question.type === "approval.request" ? "deny" : "")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; margins: 14 }
                y: root.opensUp ? composerSurface.y : composerSurface.height
                height: 1
                color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.10)
                opacity: bodyRow.opacity
            }
        }
    }
}
