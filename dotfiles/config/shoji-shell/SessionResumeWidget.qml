pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "GithubTime.js" as SessionTime

Item {
    id: root
    implicitWidth: 340
    implicitHeight: content.implicitHeight + 32
    width: implicitWidth
    height: implicitHeight
    property string selected: "codex"
    property var snapshot: ({})
    property string loadError: ""
    property string copyError: ""
    property string copied: ""
    property string archiveError: ""
    property var lastArchived: null
    property bool refreshPending: false
    property bool gestureActive: false
    readonly property var current: snapshot[selected] || { sessions: [], error: "" }
    SystemClock { id: clock; precision: SystemClock.Minutes }

    Process {
        id: collector
        property bool received: false
        running: true
        command: ["python3", Qt.resolvedUrl("session-resume.py").toString().replace("file://", "")]
        onStarted: received = false
        stdout: SplitParser {
            onRead: data => {
                try {
                    const value = JSON.parse(data);
                    for (const id of ["codex", "kimi", "grok"])
                        if (!value[id] || !Array.isArray(value[id].sessions)) throw new Error("Invalid sessions");
                    if (!archiver.running && !root.refreshPending && !root.gestureActive) root.snapshot = value;
                    root.loadError = "";
                    collector.received = true;
                } catch (error) { root.loadError = "Не удалось обновить сессии"; }
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0 || !received) root.loadError = "Не удалось обновить сессии";
            if (root.refreshPending && !archiver.running) {
                root.refreshPending = false;
                collector.running = true;
            }
        }
    }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: { if (!collector.running && !archiver.running && !root.gestureActive) collector.running = true; } }
    Process {
        id: archiver
        property var pending: null
        property bool restoring: false
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.archiveError = "Не удалось сохранить архив";
                return;
            }
            root.lastArchived = restoring ? null : pending;
            root.refreshPending = collector.running;
            if (!collector.running) collector.running = true;
        }
    }
    function archiveSession(provider, sessionId, restoring) {
        if (archiver.running) return;
        root.archiveError = "";
        archiver.pending = { provider: provider, id: sessionId };
        archiver.restoring = restoring;
        archiver.command = ["python3", Qt.resolvedUrl("session-resume.py").toString().replace("file://", ""),
            restoring ? "--restore" : "--archive", provider, sessionId];
        archiver.running = true;
    }
    Process {
        id: clipboard
        property string pending: ""
        onExited: exitCode => {
            if (exitCode === 0) {
                root.copied = pending;
                copiedTimer.restart();
            } else root.copyError = "Не удалось скопировать команду";
        }
    }
    Timer { id: copiedTimer; interval: 1800; onTriggered: root.copied = "" }
    function copySession(session) {
        if (clipboard.running || !session.command) return;
        root.copyError = "";
        clipboard.pending = root.selected + ":" + session.id;
        clipboard.command = ["wl-copy", "--type", "text/plain", "--", session.command];
        clipboard.running = true;
    }

    WidgetSurface { anchors.fill: parent }
    ColumnLayout {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: ["codex", "kimi", "grok"]
                delegate: Item {
                    id: tab
                    required property string modelData
                    Layout.fillWidth: true
                    implicitHeight: 40
                    readonly property bool selected: root.selected === modelData
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData === "codex" ? "Codex" : modelData === "kimi" ? "Kimi" : "Grok"
                    Accessible.checkable: true
                    Accessible.checked: selected
                    Accessible.onPressAction: root.selected = tab.modelData
                    Rectangle {
                        anchors.fill: parent; radius: 6
                        color: Theme.raised
                        visible: tab.selected || tabHover.hovered
                    }
                    PanelIcon {
                        anchors.centerIn: parent
                        width: 22; height: 22
                        name: "session-" + tab.modelData
                        tint: tab.selected ? Theme.accent : Theme.muted
                    }
                    HoverHandler { id: tabHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.selected = tab.modelData }
                }
            }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.10) }
        Repeater {
            model: root.current.sessions
            delegate: Item {
                id: sessionRow
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: rowContent.implicitHeight + 8
                clip: true
                readonly property bool copied: root.copied === root.selected + ":" + modelData.id
                Accessible.role: Accessible.Button
                Accessible.name: "Скопировать команду продолжения: " + modelData.title + ", " + modelData.project
                Accessible.onPressAction: root.copySession(sessionRow.modelData)
                UiText {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: gesture.offset >= 96 ? "Отпусти →" : "В архив →"
                    font.pixelSize: 11; color: Theme.accent
                    visible: gesture.offset > 0
                }
                Rectangle {
                    anchors.fill: parent
                    transform: Translate { x: gesture.offset }
                    radius: 4; color: Theme.raised
                    visible: gesture.containsMouse || gesture.offset > 0
                }
                ColumnLayout {
                    id: rowContent
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 4
                    transform: Translate { x: gesture.offset }
                    UiText {
                        Layout.fillWidth: true
                        text: sessionRow.modelData.title
                        font.pixelSize: 12
                        color: gesture.containsMouse ? Theme.accent : Theme.ink
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        UiText {
                            Layout.fillWidth: true
                            text: sessionRow.modelData.project
                            font.pixelSize: 10; color: Theme.muted
                        }
                        UiText {
                            text: sessionRow.copied ? "✓ Скопировано" : SessionTime.ago(sessionRow.modelData.updatedAt, clock.date.getTime())
                            font.pixelSize: 10; color: sessionRow.copied ? Theme.accent : Theme.muted
                        }
                    }
                }
                MouseArea {
                    id: gesture
                    anchors.fill: parent
                    enabled: !archiver.running
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    preventStealing: true
                    pressAndHoldInterval: 300
                    cursorShape: armed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                    property real startX: 0
                    property real startY: 0
                    property real offset: 0
                    property bool armed: false
                    property bool moved: false
                    property bool cancelled: false
                    function reset() {
                        offset = 0;
                        armed = false;
                        root.gestureActive = false;
                    }
                    onPressed: mouse => {
                        startX = mouse.x; startY = mouse.y;
                        offset = 0; armed = false; moved = false; cancelled = false;
                        root.gestureActive = true;
                    }
                    onPressAndHold: { if (!cancelled) armed = true; }
                    onPositionChanged: mouse => {
                        if (!pressed) return;
                        const dx = mouse.x - startX;
                        const dy = Math.abs(mouse.y - startY);
                        if (Math.hypot(dx, dy) > 8) moved = true;
                        if ((!armed && moved) || dy > 24) cancelled = true;
                        offset = armed && !cancelled ? Math.max(0, Math.min(width, dx)) : 0;
                    }
                    onReleased: mouse => {
                        const archive = armed && !cancelled && offset >= 96;
                        const copy = !armed && !moved && containsMouse;
                        reset();
                        if (archive) root.archiveSession(root.selected, sessionRow.modelData.id, false);
                        else if (copy) root.copySession(sessionRow.modelData);
                    }
                    onCanceled: reset()
                }
            }
        }
        RowLayout {
            visible: root.lastArchived !== null
            Layout.fillWidth: true
            UiText { Layout.fillWidth: true; text: "Сессия скрыта"; font.pixelSize: 11; color: Theme.muted }
            UiText {
                id: undoButton
                text: "Отменить"
                font.pixelSize: 11; color: Theme.accent
                enabled: !archiver.running
                Accessible.role: Accessible.Button
                Accessible.name: "Вернуть последнюю скрытую сессию"
                function restore() {
                    if (root.lastArchived) root.archiveSession(root.lastArchived.provider, root.lastArchived.id, true);
                }
                Accessible.onPressAction: restore()
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: undoButton.restore() }
            }
        }
        UiText {
            visible: !root.current.sessions.length
            Layout.fillWidth: true
            text: !root.snapshot[root.selected] && collector.running ? "Читаю сессии…"
                : root.current.error || root.loadError ? "Сессии недоступны" : "Нет сохранённых сессий"
            font.pixelSize: 12; color: Theme.muted
        }
        UiText {
            visible: !!text
            Layout.fillWidth: true
            text: root.archiveError || root.copyError || root.loadError || root.current.error
            font.pixelSize: 10; color: Theme.danger
        }
    }
}
