pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

Singleton {
    id: root
    property string primaryOutputName: Settings.primaryOutput
    readonly property var primaryOutput: Quickshell.screens.find(s => s.name === primaryOutputName)
        || Quickshell.screens[0] || null
    // Each entry owns its output and edge offsets. Add future arrangements here.
    readonly property var configuredLayouts: [
        { id: "empty", name: "Без виджетов", widgets: {} },
        { id: "default", name: "Текущая раскладка", widgets: {
            limits: { output: "primary", horizontal: "left", vertical: "top", x: 16, y: 68 },
            sessions: { output: "primary", horizontal: "left", vertical: "center", x: 16, y: 0 },
            neko: { output: "primary", horizontal: "right", vertical: "bottom", x: 314, y: 16 },
            github: { output: "primary", horizontal: "right", vertical: "top", x: 16, y: 68 },
            hermes: { output: "primary", horizontal: "center", vertical: "top", x: 0, y: 68 },
            vast: { output: "primary", horizontal: "left", vertical: "bottom", x: 16, y: 16 },
            music: { output: "primary", horizontal: "right", vertical: "bottom", x: 16, y: 16 }
        } },
        { id: "bottom-hud", name: "Hermes снизу", widgets: {
            hermes: { output: "primary", horizontal: "center", vertical: "bottom", x: 0, y: 84 },
            limits: { output: "primary", horizontal: "right", vertical: "bottom", x: 16, y: 16 },
            music: { output: "primary", horizontal: "right", vertical: "bottom", x: 16, y: 12, above: "limits" },
            github: { output: "primary", horizontal: "right", vertical: "top", x: 16, y: 68 },
            sessions: { output: "primary", horizontal: "left", vertical: "bottom", x: 16, y: 16 }
        } }
    ]
    readonly property var hiddenPlacement: ({ output: "", horizontal: "left", vertical: "top", x: 0, y: 0 })
    readonly property var layouts: validLayouts(configuredLayouts)
    readonly property var current: layout(Wallpapers.layoutId)
    property var transitions: ({})

    function setTransition(outputName, transition) {
        const next = Object.assign({}, transitions);
        if (transition) next[outputName] = transition;
        else delete next[outputName];
        transitions = next;
    }

    function validPlacement(entry) {
        return !!entry && typeof entry === "object" && !Array.isArray(entry)
            && typeof entry.output === "string" && entry.output.trim().length > 0
            && ["left", "center", "right"].includes(entry.horizontal)
            && ["top", "center", "bottom"].includes(entry.vertical)
            && typeof entry.x === "number" && Number.isFinite(entry.x)
            && typeof entry.y === "number" && Number.isFinite(entry.y);
    }
    function validLayouts(configured) {
        const result = [];
        for (const value of Array.isArray(configured) ? configured : []) {
            if (!value || typeof value.id !== "string" || !value.id.trim()
                    || result.some(item => item.id === value.id)
                    || !value.widgets || typeof value.widgets !== "object" || Array.isArray(value.widgets)) continue;
            const widgets = {};
            for (const id of Object.keys(value.widgets)) {
                if (validPlacement(value.widgets[id]))
                    Object.defineProperty(widgets, id, { value: value.widgets[id], enumerable: true });
            }
            result.push({ id: value.id, name: typeof value.name === "string" ? value.name : value.id, widgets });
        }
        return result.length ? result : [{ id: "empty", name: "Без виджетов", widgets: {} }];
    }
    function layout(id) {
        return layouts.find(value => value.id === id)
            || layouts.find(value => value.id === "default") || layouts[0];
    }
    function placement(id, layoutId) {
        const selected = layoutId === undefined ? current : layout(layoutId);
        return Object.prototype.hasOwnProperty.call(selected.widgets, id)
            ? selected.widgets[id] : hiddenPlacement;
    }
    function outputFor(id, layoutId) {
        const entry = placement(id, layoutId);
        if (!entry.output) return null;
        return entry.output === "primary" ? primaryOutput
            : Quickshell.screens.find(s => s.name === entry.output) || null;
    }
    function enabledOn(id, output, layoutId) {
        if (!Settings.enabled(id)) return false;
        const screen = outputFor(id, layoutId);
        return !!screen && !!output && screen.name === output.name;
    }
    function changesPlacement(id, output, before, after) {
        return enabledOn(id, output, before) && enabledOn(id, output, after)
            && JSON.stringify(placement(id, before)) !== JSON.stringify(placement(id, after));
    }
    function horizontalPosition(entry, available, size) {
        if (!validPlacement(entry)) return 0;
        return entry.horizontal === "right" ? available - size - entry.x
            : entry.horizontal === "center" ? (available - size) / 2 + entry.x : entry.x;
    }
    function verticalPosition(entry, available, size) {
        if (!validPlacement(entry)) return 0;
        return entry.vertical === "bottom" ? available - size - entry.y
            : entry.vertical === "center" ? (available - size) / 2 + entry.y : entry.y;
    }
}
