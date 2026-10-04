pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: root
    implicitWidth: 582; implicitHeight: 228
    property var github: ({})
    property string githubError: ""
    property var account: ({ state: "loading" })
    property var instances: ({ state: "loading" })
    property var providers: [
        { id: "codex", name: "ChatGPT", state: "loading", windows: [] },
        { id: "grok", name: "Grok", state: "loading", windows: [] },
        { id: "kimi", name: "Kimi", state: "loading", windows: [] }
    ]
    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property bool githubStale: !!githubError || !!github.fetchedAt && clock.date.getTime() - github.fetchedAt > 300000
    readonly property bool vastStale: [account, instances].some(v => v.state === "unavailable" || !!v.fetchedAt && clock.date.getTime() - v.fetchedAt > 120000)
    function number(value) { return typeof value === "number" && isFinite(value) ? String(value) : "—"; }
    function status(provider) {
        if (provider.state === "auth") return "Нужен вход";
        if (provider.state === "missing") return "Нет источника";
        if (provider.state === "loading") return "Загрузка…";
        if (provider.state === "available") return "Нет квоты";
        return "Недоступно";
    }
    Process {
        id: gh
        property bool received: false
        running: Settings.enabled("github")
        command: ["python3", decodeURIComponent(Qt.resolvedUrl("github-widget.py").toString().replace("file://", ""))]
        onStarted: received = false
        stdout: SplitParser {
            onRead: data => {
                try {
                    const value = JSON.parse(data);
                    if (!Array.isArray(value.errors)) throw new Error("Invalid status");
                    if (value.login && root.github.login && value.login !== root.github.login) root.github = {};
                    root.github = Object.assign({}, root.github, value);
                    root.githubError = value.errors.join(" · ");
                    gh.received = true;
                } catch (error) { root.githubError = "GitHub недоступен"; }
            }
        }
        onExited: exitCode => { if (exitCode !== 0 || !received) root.githubError = "GitHub недоступен"; }
    }
    Timer { interval: 120000; running: Settings.enabled("github"); repeat: true; onTriggered: { if (!gh.running) gh.running = true; } }
    Process {
        id: vast
        property var received: []
        running: Settings.enabled("vast")
        command: ["python3", decodeURIComponent(Qt.resolvedUrl("vast-widget.py").toString().replace("file://", "")), "status"]
        onStarted: received = []
        stdout: SplitParser {
            onRead: data => {
                try {
                    const value = JSON.parse(data);
                    if (!["account", "instances"].includes(value.kind)) return;
                    root[value.kind] = value.state === "available" ? value
                        : Object.assign({}, root[value.kind], { state: "unavailable" });
                    vast.received = vast.received.concat([value.kind]);
                } catch (error) { console.warn("Invalid Home Zone Vast response"); }
            }
        }
        onExited: {
            for (const kind of ["account", "instances"])
                if (!received.includes(kind)) root[kind] = Object.assign({}, root[kind], { state: "unavailable" });
        }
    }
    Process {
        id: limits
        property var received: []
        running: Settings.enabled("limits")
        command: ["node", decodeURIComponent(Qt.resolvedUrl("ai-limits.mjs").toString().replace("file://", ""))]
        onStarted: received = []
        stdout: SplitParser {
            onRead: data => {
                try {
                    const value = JSON.parse(data);
                    if (!["codex", "grok", "kimi"].includes(value.id) || !Array.isArray(value.windows)) return;
                    limits.received = limits.received.concat([value.id]);
                    root.providers = root.providers.map(provider => provider.id !== value.id ? provider
                        : value.state !== "available" && provider.windows.length
                            ? Object.assign({}, provider, { state: value.state }) : Object.assign({}, provider, value));
                } catch (error) { console.warn("Invalid Home Zone limits response"); }
            }
        }
        onExited: {
            root.providers = root.providers.map(provider => received.includes(provider.id) ? provider
                : Object.assign({}, provider, { state: provider.windows.length ? "stale" : "unavailable" }));
        }
    }
    Timer {
        interval: 60000; running: true; repeat: true
        onTriggered: {
            if (Settings.enabled("vast") && !vast.running) vast.running = true;
            if (Settings.enabled("limits") && !limits.running) limits.running = true;
        }
    }
    readonly property color githubSurface: "#d8cdea"
    readonly property color vastSurface: "#efd0c0"
    readonly property var quotaSurfaces: ["#c7e0d7", "#e6cddd", "#cbdcf0"]
    readonly property color tileInk: "#302b3b"

    component Counter: Button {
        id: counter
        required property string caption
        required property string value
        required property string symbol
        required property string target
        property bool stale: false
        property string error: ""
        hoverEnabled: true
        padding: 12
        Accessible.name: caption + ": " + value + (stale ? ", данные устарели" : "")
        Accessible.description: error
        onClicked: Qt.openUrlExternally(target)
        background: Rectangle {
            radius: 16
            color: counter.hovered ? "#18ffffff" : "transparent"
            border.width: counter.visualFocus ? 2 : 0
            border.color: root.tileInk
        }
        contentItem: Item {
            PanelIcon { y: 14; width: 21; height: 21; name: counter.symbol; tint: root.tileInk }
            UiText {
                x: 29; width: parent.width - 29; height: parent.height
                text: counter.value; color: root.tileInk
                font.pixelSize: 30; font.weight: Font.Bold
                fontSizeMode: Text.Fit; minimumPixelSize: 15
                verticalAlignment: Text.AlignVCenter
            }
            UiText {
                anchors { right: parent.right; top: parent.top }
                visible: counter.stale
                text: "!"; font.pixelSize: 12; font.weight: Font.Bold; color: root.tileInk
            }
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }
    WidgetSurface {
        id: githubTile
        x: 0; y: 0; width: (root.width - 12) / 2; height: 84
        radius: 22; color: root.githubSurface; border.width: 0
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true; shadowColor: "#30243e"; shadowOpacity: 0.28
            shadowVerticalOffset: 4; shadowBlur: 0.8; blurMax: 12
        }
        Counter {
            x: 4; y: 4; width: (githubTile.width - 8) / 2; height: 76
            caption: "GitHub · открытые PR"; symbol: "git-pull-request"
            value: root.number(root.github.prCount)
            target: root.github.login ? "https://github.com/pulls?q=" + encodeURIComponent("is:pr is:open user:" + root.github.login) : "https://github.com/pulls"
            stale: root.githubStale; error: root.githubError
        }
        Counter {
            x: githubTile.width / 2; y: 4; width: (githubTile.width - 8) / 2; height: 76
            caption: "GitHub · комментарии"; symbol: "message-circle"
            value: root.number(root.github.commentCount); target: "https://github.com/notifications"
            stale: root.githubStale; error: root.githubError
        }
    }
    WidgetSurface {
        id: vastTile
        x: githubTile.width + 12; y: 8; width: githubTile.width; height: 84
        radius: 22; color: root.vastSurface; border.width: 0
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true; shadowColor: "#30243e"; shadowOpacity: 0.28
            shadowVerticalOffset: 4; shadowBlur: 0.8; blurMax: 12
        }
        Counter {
            x: 4; y: 4; width: (vastTile.width - 8) * 0.40; height: 76
            caption: "Vast.ai · инстансы"; symbol: "cloud"
            value: root.instances.fetchedAt ? root.number(root.instances.total) : "—"
            target: "https://cloud.vast.ai/instances/"; stale: root.vastStale
        }
        Counter {
            x: 4 + (vastTile.width - 8) * 0.40; y: 4; width: (vastTile.width - 8) * 0.60; height: 76
            caption: "Vast.ai · баланс"; symbol: "home-wallet"
            value: typeof root.account.credit === "number" && isFinite(root.account.credit) ? "$" + root.account.credit.toFixed(2) : "—"
            target: "https://cloud.vast.ai/"; stale: root.vastStale
        }
    }
    Row {
        x: 0; y: 104; width: root.width; spacing: 10
        Repeater {
            model: root.providers
            Control {
                id: provider
                required property int index
                required property var modelData
                readonly property bool known: modelData.windows.length > 0 && modelData.windows.every(w => typeof w.remaining === "number" && isFinite(w.remaining))
                readonly property bool stale: modelData.state !== "available" || !!modelData.fetchedAt && clock.date.getTime() - modelData.fetchedAt > 120000
                readonly property real used: known ? Math.max(0, Math.min(100, 100 - Math.min.apply(null, modelData.windows.map(w => w.remaining)))) : 0
                readonly property string detail: modelData.name + " · расход лимита"
                    + (known ? "\n" + modelData.windows.map(w => w.label + ": " + Math.floor(100 - w.remaining) + "% · "
                        + (w.resetsAt ? "сброс " + Qt.formatDateTime(new Date(w.resetsAt), "dd.MM HH:mm") : "сброс неизвестен")).join("\n") : "\n" + root.status(modelData))
                    + (stale && known ? "\nДанные устарели" : "")
                width: (root.width - 20) / 3; height: 124
                hoverEnabled: true; focusPolicy: Qt.StrongFocus
                Accessible.role: Accessible.Indicator
                Accessible.name: detail
                background: WidgetSurface {
                    radius: 22; color: root.quotaSurfaces[provider.index]
                    border.width: provider.activeFocus ? 2 : 0; border.color: root.tileInk
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true; shadowColor: "#30243e"; shadowOpacity: 0.28
                        shadowVerticalOffset: 4; shadowBlur: 0.8; blurMax: 12
                    }
                }
                PanelIcon { x: 16; y: 15; width: 27; height: 27; name: "session-" + provider.modelData.id; tint: root.tileInk }
                UiText {
                    anchors { right: parent.right; top: parent.top; margins: 16 }
                    text: "!"; visible: provider.stale
                    color: root.tileInk; font.pixelSize: 16; font.weight: Font.Bold
                }
                UiText {
                    x: 15; y: 52; width: parent.width - 30; height: 52
                    text: provider.known ? Math.floor(provider.used) + "%" : "—"
                    color: root.tileInk; font.pixelSize: 40; font.weight: Font.Bold
                    fontSizeMode: Text.Fit; minimumPixelSize: 26
                }
            }
        }
    }
}
