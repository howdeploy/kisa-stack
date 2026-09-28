pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root
    property bool quiet: false
    property var toast: null
    readonly property var items: server.trackedNotifications.values
    readonly property int count: items.length
    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        imageSupported: true
        persistenceSupported: true
        onNotification: notification => {
            notification.tracked = true;
            if (!root.quiet) {
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
        toast = null;
        for (const item of items.slice()) item.dismiss();
    }
}
