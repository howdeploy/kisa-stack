pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// What the dock shows, and what clicking it does.
//
// The windows come from zwlr_foreign_toplevel_management_v1, through
// Quickshell's ToplevelManager: a generic protocol, so this knows nothing
// about ShojiWM beyond the fact that it speaks it.
//
// A singleton because the dock is built per screen and the list of windows is
// not: one grouping, one set of pins, every screen showing the same row.
//
// Nothing here animates. The dock owns its drivers, the way every other panel
// in this shell does.
Singleton {
    id: root

    // Every open window, newest last.
    readonly property var windows: ToplevelManager.toplevels
        ? ToplevelManager.toplevels.values : []
    // Which one has the keyboard. A property of the manager rather than
    // something read off each window, so a binding on it actually updates.
    readonly property var activeWindow: ToplevelManager.activeToplevel

    // Desktop entry ids, in the order they were pinned. Owned here rather than
    // read back out of the file: the adapter is repopulated asynchronously
    // after a write, so two pins in quick succession had the second one read a
    // list the first had already replaced, and one of them was lost.
    property var pinned: ["brave-browser", "com.mitchellh.ghostty", "org.kde.dolphin", "codex-desktop", "Happ", "steam"]

    // The row, left to right:
    //   { key, name, icon, entry, pinned, windows: [Toplevel] }
    // Pinned applications first in the order they were pinned, then whatever
    // else is open in the order it opened.
    property var entries: []
    // How many of them are pinned, which is where the divider goes.
    property int split: 0

    // ----- grouping ---------------------------------------------------------

    // The .desktop file for an app id. The compositor reports what the client
    // set, which is usually but not always the entry's own id, so the
    // heuristic is the fallback rather than the first try.
    function lookup(appId) {
        if (!appId)
            return null;
        // The recorder's window class differs from its desktop entry id.
        if (appId === "gsr-ui")
            return DesktopEntries.byId("gpu-screen-recorder");
        var entry = DesktopEntries.byId(appId);
        if (!entry)
            entry = DesktopEntries.heuristicLookup(appId);
        return entry;
    }

    // What two windows have to agree on to be the same application. The
    // entry's id when there is one, so that a pin written last week still
    // matches a window that opened a moment ago.
    function keyFor(appId) {
        var entry = lookup(appId);
        return entry ? entry.id : String(appId || "").toLowerCase();
    }

    function iconFor(entry, appId) {
        if (entry && entry.icon)
            return Quickshell.iconPath(entry.icon, "application-x-executable");
        if (appId)
            return Quickshell.iconPath(String(appId).toLowerCase(),
                                       "application-x-executable");
        return Quickshell.iconPath("application-x-executable", true);
    }

    function rebuild() {
        var list = [];
        var index = {};

        function add(key, entry, appId, isPinned) {
            var item = {
                key: key,
                entry: entry,
                pinned: isPinned,
                name: entry && entry.name ? entry.name
                    : String(appId || key),
                icon: iconFor(entry, appId || key),
                windows: []
            };
            index[key] = item;
            list.push(item);
            return item;
        }

        var pins = pinned;
        for (var i = 0; i < pins.length; i++) {
            var key = String(pins[i]);
            if (key === "" || index[key])
                continue;
            add(key, lookup(key), key, true);
        }
        var pinnedCount = list.length;

        var open = windows;
        for (var j = 0; j < open.length; j++) {
            var window = open[j];
            if (!window)
                continue;
            var id = window.appId;
            var k = keyFor(id);
            var item = index[k];
            if (!item)
                item = add(k, lookup(id), id, false);
            item.windows.push(window);
        }

        entries = list;
        split = pinnedCount;
    }

    onWindowsChanged: rebuild()
    onPinnedChanged: rebuild()
    Component.onCompleted: rebuild()

    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { root.rebuild(); }
    }

    // A window's app id can arrive after the window itself does, and the
    // grouping is built from it. The list changing is not enough to catch
    // that: the object is already in it.
    Instantiator {
        model: ToplevelManager.toplevels

        delegate: QtObject {
            required property var modelData
            readonly property string appId: modelData ? modelData.appId : ""
            onAppIdChanged: root.rebuild()
        }
    }

    // ----- what a click does ------------------------------------------------

    function launch(item) {
        if (item && item.entry)
            item.entry.execute();
    }

    // Nothing open: start it. One window: show it, or put it away if it is
    // already the one you are looking at. Several: step to the next one, so
    // repeated clicks walk the application's windows rather than fighting over
    // which is "the" window.
    function activate(item) {
        if (!item)
            return;
        var open = item.windows;
        if (open.length === 0) {
            launch(item);
            return;
        }
        // ShojiWM owns the toggle. Its Wayland minimized flag follows visual
        // idle (including animations), not the window manager's logical state.
        // One activate request lets the WM restore/focus/minimize atomically.
        if (open.length === 1) {
            open[0].activate();
            return;
        }

        var at = open.indexOf(activeWindow);
        if (at < 0) {
            // wlr reports no stacking order, so "the one you last used" is not
            // available; the first one that is not put away is the closest
            // honest answer.
            var target = open[0];
            for (var i = 0; i < open.length; i++) {
                if (!open[i].minimized) {
                    target = open[i];
                    break;
                }
            }
            target.activate();
            return;
        }

        var next = open[(at + 1) % open.length];
        next.activate();
    }

    function closeAll(item) {
        if (!item)
            return;
        // Over a copy: closing a window takes it out of the list being walked.
        var open = item.windows.slice();
        for (var i = 0; i < open.length; i++)
            open[i].close();
    }

    // ----- pins -------------------------------------------------------------

    function isPinned(key) {
        return pinned.indexOf(key) >= 0;
    }

    // The one place the list changes: in memory first, because that is what
    // the dock reads, and on disk second, because that is only where it waits
    // for the next session.
    function savePins(list) {
        pinned = list;
        adapter.pins = list;
        view.writeAdapter();
    }

    function pin(key) {
        if (!key || isPinned(key))
            return;
        var list = pinned.slice();
        list.push(key);
        savePins(list);
    }

    function unpin(key) {
        var list = pinned.slice();
        var at = list.indexOf(key);
        if (at < 0)
            return;
        list.splice(at, 1);
        savePins(list);
    }

    // Move a pin to another place in the row. The dock's pinned entries are
    // built from this list in order, so its index and theirs are the same
    // number and the caller can name the slot it dropped on.
    function reorder(key, position) {
        var list = pinned.slice();
        var at = list.indexOf(key);
        if (at < 0)
            return;
        var to = Math.max(0, Math.min(list.length - 1, position));
        if (to === at)
            return;
        list.splice(at, 1);
        list.splice(to, 0, key);
        savePins(list);
    }

    FileView {
        id: view

        path: Quickshell.statePath("dock.json")
        // Not watched: this file is the shell's own, and a reload landing
        // between two pins would carry the older of them back.
        //
        // There is none until something is pinned, which is not an error.
        printErrors: false

        onLoaded: root.pinned = adapter.pins || []

        JsonAdapter {
            id: adapter

            // Desktop entry ids. The order is the order of the row.
            property var pins: []
        }
    }
}
