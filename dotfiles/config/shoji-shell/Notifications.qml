pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root
    property bool quiet: false
    property bool clearing: false
    property var toast: null
    readonly property int historyLimit: 30
    readonly property var items: clearing ? [] : server.trackedNotifications.values
    readonly property int count: items.length
    function isBlocked(notification) {
        return [notification.appName, notification.desktopEntry].some(value =>
            /^(org\.flameshot\.)?flameshot(?:\.desktop)?$/i.test((value || "").trim()));
    }
    function trackNotification(notification) {
        if (isBlocked(notification)) {
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
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        imageSupported: true
        persistenceSupported: true
        onNotification: notification => {
            if (!root.trackNotification(notification)) return;
            if (!root.quiet && !notification.lastGeneration) {
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
    onQuietChanged: { if (quiet) toast = null; }
    function clearAll() {
        const pending = items.slice();
        toast = null;
        expiry.stop();
        clearing = true;
        for (const item of pending) item.dismiss();
        clearing = false;
    }
}
