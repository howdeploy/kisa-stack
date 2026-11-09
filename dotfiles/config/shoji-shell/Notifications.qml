pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root
    readonly property bool quiet: !loaded || document.quiet
    property bool loaded: false
    property string error: ""
    property bool compositorReady: false
    property bool saving: false
    property string savingText: ""
    property var document: ({ version: 1, quiet: false, exceptions: [] })
    readonly property var applications: {
        const apps = DesktopEntries.applications.values.slice();
        for (const id of document.exceptions) {
            if (!apps.some(entry => entry.id === id))
                apps.push(DesktopEntries.byId(id) || { id: id, name: id, icon: "application-x-executable" });
        }
        return apps.sort((a, b) => a.name.localeCompare(b.name));
    }
    readonly property var allowedApplications: {
        const allowed = [];
        for (const id of document.exceptions) {
            const entry = DesktopEntries.byId(id);
            const aliases = entry ? [id, id.replace(/\._[a-f0-9]{32}$/i, ""), entry.name, entry.startupClass] : [id];
            // Generic launchers must never grant an exception to every Electron/Python app.
            const binary = entry && entry.command.length ? entry.command[0].split("/").pop() : "";
            if (binary && !/^(env|sh|bash|flatpak|electron(?:\d+)?|python(?:\d+(?:\.\d+)*)?|node|gtk-launch|apprun)$/i.test(binary))
                aliases.push(binary);
            for (const alias of aliases) {
                const key = appKey(alias);
                if (key && key.length <= 256 && !/[\x00-\x1f]/.test(key) && !allowed.includes(key)) allowed.push(key);
            }
        }
        return allowed;
    }
    property bool clearing: false
    property var toast: null
    readonly property int historyLimit: 30
    readonly property var items: clearing ? [] : server.trackedNotifications.values
    readonly property int count: items.length
    function appKey(value) { return String(value || "").trim().toLowerCase().replace(/\.desktop$/, ""); }
    function permits(desktopEntry, appName) {
        return !quiet || allowedApplications.includes(appKey(desktopEntry || appName));
    }
    function isException(id) { return document.exceptions.includes(id); }
    function setException(id, allowed) {
        if (!loaded || typeof allowed !== "boolean" || (allowed && !DesktopEntries.byId(id))) return;
        const ids = document.exceptions.filter(value => value !== id);
        if (allowed) ids.push(id);
        if (ids.length > 128) { error = "Слишком много исключений"; return; }
        document = Object.assign({}, document, { exceptions: ids });
        save();
    }
    function setQuiet(value) {
        if (!loaded || typeof value !== "boolean") return;
        document = Object.assign({}, document, { quiet: value });
        save();
    }
    function save() {
        if (!loaded || saving) return;
        error = "";
        savingText = JSON.stringify(document, null, 2) + "\n";
        saving = true;
        policyFile.setText(savingText);
    }
    function synchronize() {
        if (toast && !permits(toast.desktopEntry, toast.appName)) { toast = null; expiry.stop(); }
        if (!policySocket.connected || !loaded) return;
        compositorReady = false;
        policySocket.write(JSON.stringify({ id: ++sequence, method: "notifications.setPolicy",
            params: { quiet: quiet, allowedApplications: allowedApplications } }) + "\n");
        policySocket.flush();
    }
    property int sequence: 0
    onQuietChanged: synchronize()
    onAllowedApplicationsChanged: synchronize()
    onLoadedChanged: synchronize()
    function isBlocked(notification) {
        return !allowedApplications.includes(appKey(notification.desktopEntry || notification.appName))
            && [notification.appName, notification.desktopEntry].some(value =>
            /^(org\.flameshot\.)?flameshot(?:\.desktop)?$/i.test((value || "").trim()));
    }
    function trackNotification(notification) {
        if (isBlocked(notification) || !permits(notification.desktopEntry, notification.appName)) {
            notification.tracked = false;
            return false;
        }
        // Make room before the server appends the new notification.
        for (const item of items.slice(0, Math.max(0, items.length - historyLimit + 1)))
            item.expire();
        notification.tracked = true;
        return true;
    }
    NotificationServer {
        id: server
        keepOnReload: true
        allowedApplications: root.allowedApplications
        inhibited: root.quiet
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        imageSupported: true
        persistenceSupported: true
        onNotification: notification => {
            if (!root.trackNotification(notification)) return;
            if (!notification.lastGeneration) {
                root.toast = notification;
                expiry.interval = notification.expireTimeout > 0 ? notification.expireTimeout : 6000;
                expiry.restart();
                if (notification.urgency === NotificationUrgency.Critical)
                    expiry.stop();
            }
        }
    }
    Timer { id: expiry; onTriggered: root.toast = null }
    Connections {
        target: root.toast
        function onClosed(): void { root.toast = null; }
    }
    FileView {
        id: policyFile
        path: Settings.configHome + "/shoji-shell/notification-policy.json"
        preload: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            if (root.loaded) return;
            try {
                const data = JSON.parse(text());
                if (!data || data.version !== 1 || typeof data.quiet !== "boolean"
                    || !Array.isArray(data.exceptions) || data.exceptions.length > 128
                    || !data.exceptions.every(id => typeof id === "string" && id.length > 0
                        && id.length <= 256 && !/[\x00-\x1f]/.test(id)))
                    throw new Error("Invalid notification policy");
                root.document = data;
                root.loaded = true;
            } catch (failure) { root.error = "Не удалось прочитать настройки уведомлений. Файл сохранён, уведомления заблокированы."; }
        }
        onLoadFailed: failure => {
            if (failure === FileViewError.FileNotFound) root.loaded = true;
            else root.error = "Нет доступа к настройкам уведомлений";
        }
        onSaved: {
            root.saving = false;
            if (JSON.stringify(root.document, null, 2) + "\n" !== root.savingText) root.save();
        }
        onSaveFailed: { root.saving = false; root.error = "Настройки действуют, но сохранить их не удалось."; }
    }
    Socket {
        id: policySocket
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/shojiwm-" + Quickshell.env("WAYLAND_DISPLAY") + ".sock"
        connected: true
        onConnectionStateChanged: {
            root.compositorReady = false;
            if (connected) root.synchronize();
        }
        parser: SplitParser {
            onRead: line => {
                try {
                    const reply = JSON.parse(line);
                    if (reply.id !== root.sequence) return;
                    root.compositorReady = !reply.error && reply.result && reply.result.version === 1;
                } catch (failure) { root.compositorReady = false; }
            }
        }
    }
    Timer { interval: 2000; repeat: true; running: !policySocket.connected; onTriggered: policySocket.connected = true }
    function clearAll() {
        const pending = items.slice();
        toast = null;
        expiry.stop();
        clearing = true;
        for (const item of pending) item.dismiss();
        clearing = false;
    }
    IpcHandler {
        target: "notifications"
        function toggle(): void { root.setQuiet(!root.quiet); }
        function setEnabled(enabled: bool): void { root.setQuiet(!enabled); }
        function status(): string {
            return JSON.stringify({ version: 1, enabled: !root.quiet, loaded: root.loaded,
                exceptions: root.document.exceptions, compositorReady: root.compositorReady, error: root.error });
        }
    }
}
