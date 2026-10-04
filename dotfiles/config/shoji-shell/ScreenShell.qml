pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.WindowManager
import Quickshell.Services.SystemTray

Scope {
    id: screenShell
    required property var output
    required property var shell
    property bool chromeFullscreen: false
    readonly property var projection: WindowManager.screenProjection(output)
    readonly property var workspaces: projection ? projection.windowsets.filter(w => w.shouldDisplay).slice().sort((a, b) => Number(a.name.split(":").pop()) - Number(b.name.split(":").pop())) : []
    readonly property bool panelOpen: shell.panelScreen === output.name && shell.panelPage !== ""
    readonly property string activeWorkspace: workspaces.filter(w => w.active).map(w => w.id).join(",")
    onActiveWorkspaceChanged: { if (panelOpen) shell.panelPage = ""; }
    onPanelOpenChanged: { if (panelOpen) panelLoader.active = true; }
    SystemClock { id: clock; precision: SystemClock.Minutes }

    Socket {
        id: dockSocket
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/shojiwm-" + Quickshell.env("WAYLAND_DISPLAY") + ".sock"
        connected: true
        function refresh() {
            write(JSON.stringify({ id: 1, method: "dock.get", params: {
                monitor: screenShell.output.name, width: dockWindow.width, height: dockWindow.height
            } }) + "\n");
            write(JSON.stringify({ method: "mateengine.shell", params: {
                monitor: screenShell.output.name,
                visible: dockPill.visible && dockPill.y < dockWindow.height,
                dock: {
                    x: (screenShell.output.width - dockWindow.width) / 2,
                    y: screenShell.output.height - dockWindow.height,
                    width: dockPill.width,
                    height: dockPill.height
                }
            } }) + "\n");
            flush();
        }
        onConnectionStateChanged: {
            if (connected) refresh();
            else { dockWindow.occluded = false; dockWindow.nearby = false; dockWindow.petSeated = false; screenShell.chromeFullscreen = false; }
        }
        parser: SplitParser {
            onRead: data => {
                try {
                    const message = JSON.parse(data);
                    if (message.id === 1 && message.result) {
                        dockWindow.occluded = message.result.occluded === true;
                        dockWindow.nearby = message.result.nearby === true;
                        dockWindow.petSeated = message.result.petSeated === true;
                        screenShell.chromeFullscreen = message.result.chromeFullscreen === true;
                    } else if (message.event === "dock.proximity" && message.payload.monitor === screenShell.output.name) {
                        dockWindow.nearby = message.payload.inside === true;
                    }
                } catch (error) { console.warn("Dock state:", error); }
            }
        }
    }
    // ponytail: sample overlap at 10 Hz; use geometry events if polling becomes costly.
    Timer { interval: 100; repeat: true; running: dockSocket.connected; onTriggered: dockSocket.refresh() }
    Timer { interval: 1000; repeat: true; running: !dockSocket.connected; onTriggered: dockSocket.connected = true }

    PanelWindow {
        screen: screenShell.output
        anchors.bottom: true
        margins.bottom: 126
        implicitWidth: 320; implicitHeight: 68
        visible: Osd.visible
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "shoji-shell"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}
        Rectangle {
            anchors.fill: parent; radius: 24; color: Theme.surface
            border.width: 1; border.color: Theme.hover
            RowLayout {
                anchors { fill: parent; margins: 14 }
                spacing: 12
                Rectangle {
                    Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 20; color: Theme.raised
                    PanelIcon { anchors.centerIn: parent; name: Osd.kind === "layout" ? "keyboard" : Services.muted ? "muted" : "volume"; tint: Theme.accent }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 8
                    UiText { text: Osd.kind === "layout" ? "РАСКЛАДКА" : Services.muted ? "ЗВУК ВЫКЛЮЧЕН" : "ГРОМКОСТЬ"; font.pixelSize: 10; font.letterSpacing: 1; color: Theme.muted }
                    Rectangle {
                        visible: Osd.kind === "volume"
                        Layout.fillWidth: true; implicitHeight: 6; radius: 3; color: Theme.line
                        Rectangle { width: parent.width * (Services.muted ? 0 : Math.min(1, Services.volume / 100)); height: parent.height; radius: 3; color: Theme.accent }
                    }
                    UiText { visible: Osd.kind === "layout"; text: Osd.layoutName; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.fillWidth: true }
                }
                UiText { visible: Osd.kind === "volume"; text: Services.volume + "%"; font.pixelSize: 14; font.weight: Font.DemiBold; Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight }
            }
        }
    }

    PanelWindow {
        id: bar
        screen: screenShell.output
        anchors { top: true; left: true; right: true }
        implicitHeight: 56
        exclusiveZone: 56
        color: "transparent"
        WlrLayershell.layer: screenShell.chromeFullscreen ? WlrLayer.Bottom : WlrLayer.Top
        WlrLayershell.namespace: "shoji-shell"
        // Native popup grabs require a keyboard-interactive parent.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        mask: Region {
            item: workspacePill
            Region { item: clockPill }
            Region { item: rightPills }
        }
        Rectangle {
            id: workspacePill
            x: 16; anchors.verticalCenter: parent.verticalCenter
            height: 34; radius: 17
            width: workspaceRow.width + 16
            color: Theme.surface
            Row {
                id: workspaceRow
                anchors.centerIn: parent; spacing: 2
                Repeater {
                    model: screenShell.workspaces
                    Button {
                        id: workspaceButton
                        required property var modelData
                        width: modelData.active ? 38 : 28; height: 28
                        hoverEnabled: true
                        Accessible.name: "Рабочий стол " + modelData.name.split(":").pop()
                        background: Rectangle { radius: 14; color: workspaceButton.hovered ? Theme.hover : "transparent" }
                        contentItem: Item {
                            Rectangle {
                                anchors.centerIn: parent
                                width: workspaceButton.modelData.active ? 26 : 8
                                height: 8; radius: 4
                                color: workspaceButton.modelData.active ? Theme.accent : workspaceButton.modelData.urgent ? Theme.danger : Theme.muted
                                opacity: workspaceButton.modelData.active ? 1 : 0.6
                                Behavior on width { NumberAnimation { duration: 140 } }
                            }
                        }
                        onClicked: modelData.activate()
                    }
                }
            }
        }
        Rectangle {
            id: clockPill
            anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
            width: timeText.implicitWidth + 32; height: 34; radius: 17
            color: Theme.surface
            TapHandler { onTapped: screenShell.shell.panelPage = "" }
            UiText {
                id: timeText; anchors.centerIn: parent
                text: clock.date.toLocaleString(Qt.locale("ru_RU"), "hh:mm  ·  d MMMM, ddd")
                font.pixelSize: 12; font.weight: Font.DemiBold
            }
        }
        Row {
            id: rightPills
            anchors.right: parent.right; anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            ActionButton {
                id: notificationButton
                hint: "Уведомления: " + Notifications.count + (Notifications.quiet ? " · Не беспокоить" : "")
                height: 34
                topPadding: 7; bottomPadding: 7
                highlighted: screenShell.panelOpen && screenShell.shell.panelPage === "notifications"
                contentItem: RowLayout {
                    spacing: 7
                    PanelIcon { name: Notifications.quiet ? "bell-off" : "bell"; implicitWidth: 17; implicitHeight: 17; Layout.alignment: Qt.AlignVCenter; tint: notificationButton.highlighted ? Theme.surface : Theme.ink }
                    Rectangle {
                        visible: Notifications.count > 0
                        implicitWidth: Math.max(18, notificationCount.implicitWidth + 8); implicitHeight: 18; radius: 9
                        Layout.alignment: Qt.AlignVCenter
                        color: notificationButton.highlighted ? Theme.surface : Theme.accent
                        UiText { id: notificationCount; anchors.centerIn: parent; text: Notifications.count > 99 ? "99+" : Notifications.count; font.pixelSize: 10; font.weight: Font.DemiBold; color: notificationButton.highlighted ? Theme.accent : Theme.surface }
                    }
                }
                background: Rectangle { radius: 17; color: notificationButton.highlighted ? Theme.accent : notificationButton.hovered ? Theme.hover : Theme.surface }
                onClicked: screenShell.shell.toggle(screenShell.output.name, "notifications")
            }
            ActionButton {
                id: systemButton
                hint: Services.wifiLabel + "\nBluetooth: " + Services.btLabel + "\n" + (Services.muted ? "Звук выключен" : "Громкость: " + Services.volume + "%") + (Keyboard.available ? "\nРаскладка: " + Keyboard.label : "")
                height: 34
                topPadding: 7; bottomPadding: 7
                highlighted: screenShell.panelOpen && screenShell.shell.panelPage === "controls"
                contentItem: RowLayout {
                    spacing: 10
                    PanelIcon { name: Services.wifiIcon; implicitWidth: 17; implicitHeight: 17; Layout.alignment: Qt.AlignVCenter; tint: systemButton.highlighted ? Theme.surface : Services.network ? Theme.accent : Theme.muted }
                    PanelIcon { name: Services.bluetoothIcon; implicitWidth: 16; implicitHeight: 16; Layout.alignment: Qt.AlignVCenter; tint: systemButton.highlighted ? Theme.surface : Services.bluetoothConnected.length > 0 ? Theme.accent : Theme.muted }
                    RowLayout {
                        spacing: 5
                        Layout.alignment: Qt.AlignVCenter
                        PanelIcon { name: Services.muted ? "muted" : "volume"; implicitWidth: 16; implicitHeight: 16; Layout.alignment: Qt.AlignVCenter; tint: systemButton.highlighted ? Theme.surface : Theme.ink }
                        UiText { text: Services.muted ? "Выкл" : Services.volume + "%"; font.pixelSize: 11; Layout.alignment: Qt.AlignVCenter; color: systemButton.highlighted ? Theme.surface : Theme.ink }
                    }
                    Rectangle { visible: Keyboard.available; implicitWidth: 1; implicitHeight: 14; Layout.alignment: Qt.AlignVCenter; color: systemButton.highlighted ? Theme.surface : Theme.line }
                    UiText { visible: Keyboard.available; text: Keyboard.shortName; font.pixelSize: 11; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignVCenter; color: systemButton.highlighted ? Theme.surface : Theme.ink }
                }
                background: Rectangle { radius: 17; color: systemButton.highlighted ? Theme.accent : systemButton.hovered ? Theme.hover : Theme.surface }
                onClicked: screenShell.shell.toggle(screenShell.output.name, "controls")
            }
        }
    }

    PanelWindow {
        id: dockWindow
        property bool petSeated: false
        property bool occluded: false
        property bool nearby: false
        readonly property bool shown: petSeated || !occluded || nearby || dockHover.hovered || dockMenu.visible
        screen: screenShell.output
        anchors.bottom: true
        implicitWidth: Math.min(screenShell.output.width - 32, Dock.entries.length * 48 + 68)
        implicitHeight: 72
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "shoji-dock"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region { x: 0; y: 0; width: dockWindow.shown ? dockWindow.width : 0; height: dockWindow.height }
        Rectangle {
            id: dockPill
            width: parent.width; height: 60
            y: dockWindow.shown ? 0 : dockWindow.height
            visible: y < dockWindow.height
            radius: 22; color: Theme.surface
            Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            HoverHandler { id: dockHover }
            RowLayout {
                anchors { fill: parent; margins: 6 }
                spacing: 6
                ActionButton {
                    icon.source: Qt.resolvedUrl("icons/applications.svg"); hint: "Все приложения"
                    icon.width: 24; icon.height: 24; padding: 9
                    Layout.preferredWidth: 42; Layout.preferredHeight: 42
                    onClicked: Quickshell.execDetached([Settings.configHome + "/shojiwm/scripts/launcher"])
                }
                Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 24; color: Theme.line }
                ListView {
                    id: appList
                    Layout.fillWidth: true; Layout.fillHeight: true
                    orientation: ListView.Horizontal
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    model: Dock.entries
                    delegate: Item {
                        id: app
                        required property var modelData
                        width: 48; height: 48
                        readonly property bool active: modelData.windows.indexOf(Dock.activeWindow) >= 0
                        Button {
                            id: appButton
                            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 3 }
                            height: 40; hoverEnabled: true
                            Accessible.name: app.modelData.name
                            background: Rectangle { radius: 13; color: app.active ? Theme.hover : appButton.hovered ? Theme.raised : "transparent" }
                            contentItem: Image {
                                source: app.modelData.icon
                                sourceSize { width: 32; height: 32 }
                                fillMode: Image.PreserveAspectFit
                            }
                            padding: 5
                            onClicked: Dock.activate(app.modelData)
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.RightButton | Qt.MiddleButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.MiddleButton) Dock.launch(app.modelData);
                                    else { dockMenu.entry = app.modelData; dockMenu.popup(); }
                                }
                            }
                        }
                        Rectangle {
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 1 }
                            width: app.active ? 14 : 4; height: 3; radius: 2
                            visible: app.modelData.windows.length > 0
                            color: app.active ? Theme.accent : Theme.muted
                        }
                    }
                }
            }
            Menu {
                id: dockMenu
                property var entry: null
                popupType: Popup.Window
                palette { window: Theme.surface; windowText: Theme.ink; highlight: Theme.hover; highlightedText: Theme.ink }
                MenuItem { text: "Новое окно"; enabled: dockMenu.entry && dockMenu.entry.entry; onTriggered: Dock.launch(dockMenu.entry) }
                MenuItem {
                    text: dockMenu.entry && Dock.isPinned(dockMenu.entry.key) ? "Открепить" : "Закрепить"
                    onTriggered: {
                        if (Dock.isPinned(dockMenu.entry.key)) Dock.unpin(dockMenu.entry.key);
                        else Dock.pin(dockMenu.entry.key);
                    }
                }
            }
        }
    }

    // Preload once so the opening click does not wait for QML construction.
    LazyLoader {
        id: panelLoader
        loading: true
        PopupWindow {
        id: popup
        Binding {
            target: screenShell.shell
            property: "panelReady"
            value: screenShell.panelOpen && !popup.dismissed && popup.backingWindowVisible && popup.reveal === 1
        }
        anchor.window: bar
        anchor.rect.x: bar.width - width - 16
        anchor.rect.y: 62
        grabFocus: true
        implicitWidth: 408
        implicitHeight: panelHeight
        readonly property string requestedPage: screenShell.panelOpen ? screenShell.shell.panelPage : ""
        property string displayedPage: ""
        property real reveal: 0
        property bool dismissed: true
        property real panelHeight: Math.max(1, Math.min(screenShell.output.height - 154, popupContent.implicitHeight + 40))
        visible: false
        onVisibleChanged: {
            if (visible) return;
            // Latch dismissal before changing animation or requested state.
            dismissed = true;
            revealAnimation.stop();
            reveal = 0;
            if (screenShell.panelOpen) screenShell.shell.panelPage = "";
        }
        color: "transparent"

        // Keep the page geometry stable until reveal resets after dismissal.
        function syncPanel() {
            revealAnimation.stop();
            const opening = requestedPage !== "";
            if (opening) {
                displayedPage = requestedPage;
                dismissed = false;
                visible = true;
                Qt.callLater(() => { if (!popup.dismissed && screenShell.panelOpen) panelFocus.forceActiveFocus(); });
            } else if (dismissed) {
                return;
            }
            revealAnimation.from = reveal;
            revealAnimation.to = opening ? 1 : 0;
            revealAnimation.duration = opening ? 220 : 160;
            revealAnimation.easing.type = opening ? Easing.OutCubic : Easing.InCubic;
            if (reveal === revealAnimation.to) {
                if (!opening) visible = false;
                return;
            }
            revealAnimation.start();
        }
        onRequestedPageChanged: syncPanel()
        onBackingWindowVisibleChanged: { if (backingWindowVisible && screenShell.panelOpen) panelFocus.forceActiveFocus(); }
        Component.onCompleted: syncPanel()
        NumberAnimation {
            id: revealAnimation
            target: popup
            property: "reveal"
            onFinished: { if (to === 0) popup.visible = false; }
        }

        mask: Region { item: screenShell.panelOpen ? panelReveal : null }
        Item {
            id: panelReveal
            width: popup.width
            height: popup.panelHeight * popup.reveal
            clip: true
            GrainSurface {
                width: parent.width
                height: popup.panelHeight
            }
            FocusScope {
                id: panelFocus
                width: parent.width; height: popup.panelHeight
                focus: true
                enabled: screenShell.panelOpen
                Keys.onEscapePressed: screenShell.shell.panelPage = ""
                ScrollView {
                    anchors { fill: parent; margins: 20 }
                    contentWidth: availableWidth
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ColumnLayout {
                        id: popupContent
                        width: panelReveal.width - 40
                        spacing: 18
                        RowLayout {
                            Layout.fillWidth: true
                            PanelIcon { name: "bell"; tint: Theme.accent; visible: popup.displayedPage === "notifications"; Layout.rightMargin: 4 }
                            UiText {
                                text: popup.displayedPage === "controls" ? "Системная панель" : "Уведомления"
                                font.pixelSize: 15; font.weight: Font.Medium; Layout.fillWidth: true
                            }
                            ActionButton { icon.source: Qt.resolvedUrl("icons/close.svg"); hint: "Закрыть"; implicitWidth: 32; padding: 7; onClicked: screenShell.shell.panelPage = "" }
                        }
                        ControlCentre {
                            Layout.fillWidth: true
                            visible: popup.displayedPage === "controls"
                            active: screenShell.shell.panelReady && popup.displayedPage === "controls"
                            stats: screenShell.shell.stats
                        }
                        RowLayout {
                            visible: popup.displayedPage === "controls" && SystemTray.items.values.length > 0
                            Layout.fillWidth: true
                            UiText { text: "В трее"; color: Theme.muted; font.pixelSize: 11; Layout.alignment: Qt.AlignVCenter }
                            Repeater {
                                model: SystemTray.items
                                ActionButton {
                                    id: trayButton
                                    required property var modelData
                                    property bool quitRequested: false
                                    Layout.alignment: Qt.AlignVCenter
                                    topPadding: 8; bottomPadding: 8
                                    hint: modelData.title || modelData.id
                                    icon.source: modelData.icon; icon.color: "transparent"
                                    function showMenu() {
                                        const point = popup.mapFromItem(trayButton, 0, trayButton.height);
                                        modelData.display(popup, point.x, point.y);
                                    }
                                    function findQuitAction(entries) {
                                        // ponytail: known RU/EN exit labels; extend when an app uses another label.
                                        return entries.find(entry => !entry.isSeparator && entry.enabled && !entry.hasChildren
                                            && /^(quit|exit|выход|выйти|завершить работу|закрыть telegram|quit telegram|выйти из steam)$/i.test(
                                                entry.text.replace(/[&_]/g, "").replace(/(?:\.{3}|…)$/, "").trim()));
                                    }
                                    function tryQuit() {
                                        if (!quitRequested) return;
                                        const action = findQuitAction(quitMenu.children ? quitMenu.children.values : []);
                                        if (!action) return;
                                        action.triggered();
                                        quitRequested = false;
                                        quitTimeout.stop();
                                    }
                                    function requestQuit() {
                                        if (quitRequested) return;
                                        if (!modelData.hasMenu) { modelData.activate(); return; }
                                        quitRequested = true;
                                        quitTimeout.restart();
                                        Qt.callLater(tryQuit);
                                    }
                                    QsMenuOpener {
                                        id: quitMenu
                                        menu: trayButton.quitRequested ? trayButton.modelData.menu : null
                                        onChildrenChanged: Qt.callLater(trayButton.tryQuit)
                                    }
                                    Connections {
                                        target: quitMenu.children
                                        function onValuesChanged() { Qt.callLater(trayButton.tryQuit); }
                                    }
                                    Timer {
                                        id: quitTimeout
                                        interval: 1500
                                        onTriggered: {
                                            trayButton.tryQuit();
                                            if (!trayButton.quitRequested) return;
                                            trayButton.quitRequested = false;
                                            trayButton.modelData.activate();
                                        }
                                    }
                                    onClicked: { if (modelData.onlyMenu) showMenu(); else modelData.activate(); }
                                    MouseArea {
                                        anchors.fill: parent
                                        acceptedButtons: Qt.RightButton | Qt.MiddleButton
                                        onClicked: mouse => {
                                            if (mouse.button === Qt.MiddleButton) trayButton.requestQuit();
                                            else trayButton.showMenu();
                                        }
                                    }
                                }
                            }
                            Item { Layout.fillWidth: true }
                        }
                        NotificationCentre {
                            visible: popup.displayedPage === "notifications"
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }

    }

    PanelWindow {
        id: toastWindow
        screen: screenShell.output
        anchors { top: true; right: true }
        margins { top: 62; right: 16 }
        implicitWidth: 368; implicitHeight: toastCard.implicitHeight + 16
        readonly property var requestedToast: screenShell.panelOpen ? null : Notifications.toast
        property var displayedToast: null
        property real reveal: requestedToast ? 1 : 0
        visible: requestedToast !== null || reveal > 0
        onRequestedToastChanged: { if (requestedToast) displayedToast = requestedToast; }
        onRevealChanged: { if (reveal === 0 && !requestedToast) displayedToast = null; }
        Component.onCompleted: { displayedToast = requestedToast; }
        RetainableLock { object: toastWindow.displayedToast; locked: true }
        Behavior on reveal {
            NumberAnimation {
                duration: toastWindow.requestedToast ? 220 : 160
                easing.type: toastWindow.requestedToast ? Easing.OutCubic : Easing.InCubic
            }
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "shoji-shell"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region { item: toastWindow.requestedToast ? toastReveal : null }
        Item {
            id: toastReveal
            width: toastWindow.width
            height: toastWindow.height * toastWindow.reveal
            clip: true
            enabled: toastWindow.requestedToast !== null
            GrainSurface { width: parent.width; height: toastWindow.height }
            NotificationCard {
                id: toastCard
                x: 8; y: 8; width: parent.width - 16
                notification: toastWindow.displayedToast
            }
        }
    }
}
