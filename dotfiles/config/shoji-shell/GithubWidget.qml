pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "GithubTime.js" as GithubTime

Item {
    id: root
    implicitWidth: 340
    implicitHeight: content.implicitHeight + 32
    width: implicitWidth
    height: implicitHeight
    property var snapshot: ({ recent: [] })
    property string error: ""
    property bool received: false
    property double fetchedAt: 0
    property string clearError: ""
    property var clearedAt: ({})
    readonly property var recent: root.snapshot.recent.filter(row =>
        Date.parse(row.updatedAt) > Number(root.clearedAt[root.snapshot.login] || 0))
    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property bool stale: !!error || fetchedAt > 0 && clock.date.getTime() - fetchedAt > 300000

    function open(url) {
        if (typeof url === "string" && url.startsWith("https://github.com/")) Qt.openUrlExternally(url);
    }
    FileView {
        id: dismissalState
        path: Quickshell.statePath("github-dismissed.json")
        preload: true
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const saved = JSON.parse(text()).clearedAt;
                if (!saved || typeof saved !== "object" || Array.isArray(saved)
                        || !Object.values(saved).every(value => typeof value === "number" && Number.isFinite(value)))
                    throw new Error("Invalid GitHub dismissal state");
                root.clearedAt = saved;
                root.clearError = "";
            } catch (error) {
                root.clearError = "Не удалось прочитать сохранённую очистку";
            }
        }
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound) root.clearError = "Не удалось прочитать сохранённую очистку";
        }
        onSaveFailed: root.clearError = "Не удалось сохранить очистку"
        onSaved: root.clearError = ""
    }
    Process {
        id: collector
        running: true
        command: ["python3", Qt.resolvedUrl("github-widget.py").toString().replace("file://", "")]
        onStarted: root.received = false
        stdout: SplitParser {
            onRead: data => {
                try {
                    const value = JSON.parse(data);
                    if (!Array.isArray(value.errors)) throw new Error("Missing status");
                    if (value.login && root.snapshot.login && value.login !== root.snapshot.login)
                        root.snapshot = { recent: [] };
                    root.snapshot = Object.assign({}, root.snapshot, value);
                    root.error = value.errors.join(" · ");
                    if (!root.error && typeof value.fetchedAt === "number") root.fetchedAt = value.fetchedAt;
                    root.received = true;
                } catch (error) { root.error = "Не удалось прочитать ответ GitHub"; }
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0 || !root.received) root.error = "Не удалось обновить GitHub";
        }
    }
    Timer { interval: 120000; running: true; repeat: true; onTriggered: { if (!collector.running) collector.running = true; } }

    WidgetSurface { anchors.fill: parent }
    ColumnLayout {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            UiText { text: "GitHub"; font.pixelSize: 14; font.weight: Font.DemiBold; Layout.fillWidth: true }
            UiText { text: root.snapshot.login ? "@" + root.snapshot.login : ""; font.pixelSize: 11; color: Theme.muted }
            ActionButton {
                implicitWidth: 32; implicitHeight: 32; padding: 7
                icon.source: Qt.resolvedUrl("icons/clear.svg")
                hint: "Очистить записи GitHub в виджете"
                enabled: !!root.snapshot.login && root.recent.length > 0
                ToolTip.visible: hovered
                ToolTip.text: hint
                onClicked: {
                    root.clearedAt = Object.assign({}, root.clearedAt, { [root.snapshot.login]: Date.now() });
                    dismissalState.setText(JSON.stringify({ clearedAt: root.clearedAt }, null, 4) + "\n");
                }
            }
            Rectangle {
                visible: root.stale
                implicitWidth: 6; implicitHeight: 6; radius: 3; color: Theme.danger
                Accessible.role: Accessible.Indicator
                Accessible.name: "Данные GitHub устарели"
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            Repeater {
                model: [
                    { icon: "git-pull-request", label: "Открытые PR", field: "prCount" },
                    { icon: "message-circle", label: "Комментарии", field: "commentCount" }
                ]
                delegate: Item {
                    id: counter
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: counterContent.implicitHeight
                    readonly property var value: root.snapshot[modelData.field]
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.label + ": " + (typeof value === "number" ? value : "нет данных")
                    Accessible.onPressAction: counter.activate()
                    function activate() {
                        root.open(modelData.field === "prCount" && root.snapshot.login
                            ? "https://github.com/pulls?q=" + encodeURIComponent("is:pr is:open user:" + root.snapshot.login)
                            : "https://github.com/notifications");
                    }
                    RowLayout {
                        id: counterContent
                        anchors { left: parent.left; right: parent.right }
                        spacing: 9
                        Item { Layout.fillWidth: true; visible: counter.modelData.field === "commentCount" }
                        PanelIcon { name: counter.modelData.icon; tint: counter.value > 0 ? Theme.accent : Theme.muted }
                        UiText {
                            text: typeof counter.value === "number" ? counter.value : "—"
                            font.pixelSize: 30; font.weight: Font.DemiBold
                            color: counterHover.hovered ? Theme.accent : Theme.ink
                        }
                        Item { Layout.fillWidth: true; visible: counter.modelData.field === "prCount" }
                    }
                    HoverHandler { id: counterHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: counter.activate() }
                }
            }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.10) }
        Repeater {
            model: root.recent
            delegate: Item {
                id: notificationRow
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: rowContent.implicitHeight + 4
                Accessible.role: Accessible.Link
                Accessible.name: modelData.repository + ": " + modelData.title + ", " + GithubTime.ago(modelData.updatedAt, clock.date.getTime())
                Accessible.onPressAction: root.open(notificationRow.modelData.url)
                Rectangle {
                    anchors.fill: parent; anchors.margins: -4
                    radius: 4; color: Theme.raised; visible: rowHover.hovered
                }
                RowLayout {
                    id: rowContent
                    width: parent.width
                    spacing: 8
                    PanelIcon {
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 2
                        Layout.preferredWidth: 14; Layout.preferredHeight: 14
                        name: notificationRow.modelData.type === "PullRequest" ? "git-pull-request" : "message-circle"
                        tint: notificationRow.modelData.unread ? Theme.accent : Theme.muted
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        UiText {
                            Layout.fillWidth: true
                            text: notificationRow.modelData.title
                            font.pixelSize: 12
                            font.weight: notificationRow.modelData.unread ? Font.DemiBold : Font.Normal
                        }
                        UiText {
                            Layout.fillWidth: true
                            text: notificationRow.modelData.repository + " #" + notificationRow.modelData.number
                            font.pixelSize: 10; color: Theme.muted
                        }
                        UiText {
                            Layout.fillWidth: true
                            text: GithubTime.ago(notificationRow.modelData.updatedAt, clock.date.getTime())
                            font.pixelSize: 10; color: Theme.muted
                        }
                    }
                }
                HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.open(notificationRow.modelData.url) }
            }
        }
        UiText {
            visible: !root.recent.length
            Layout.fillWidth: true
            text: collector.running && !root.received ? "Получаю уведомления…"
                : root.error ? "Уведомления недоступны" : "Пока нет уведомлений"
            font.pixelSize: 12; color: Theme.muted
        }
        UiText {
            visible: root.stale || !!root.clearError
            Layout.fillWidth: true
            text: root.clearError || root.error || "Данные устарели"
            font.pixelSize: 10; color: Theme.danger
        }
    }
}
