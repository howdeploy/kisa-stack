import {
    read,
    type EasingFunction,
    type WaylandWindow,
    type WindowStateKey,
} from "shoji_wm";
import type { ManagedWindowRect } from "shoji_wm/types";
import { playWindowJelly, stopWindowJelly } from "./effect/window-jelly";
import { trackLayoutMeltMotion, stopLayoutMeltMotion } from "./effect/layout-melt";
export { LAYOUT_TRANSITION_DURATION, LAYOUT_TRANSITION_EASING } from "./effect/layout-melt";

export interface RectAnimationOptions {
    suppressSSDRebuild?: boolean;
    squashOnMove?: boolean;
    layoutMeltOutput?: string;
}

interface RectAnimationTarget {
    target: ManagedWindowRect;
    token: number;
}

const activeRectAnimationTargetByWindow = new WeakMap<WaylandWindow, Map<symbol, RectAnimationTarget>>();
let rectAnimationToken = 0;

function rectAnimationChannel(windowRectState: WindowStateKey<ManagedWindowRect>): string {
    return `rect:${windowRectState.description ?? "anon"}`;
}

function snapshotRect(rect: ManagedWindowRect): ManagedWindowRect {
    return {
        x: read(rect.x),
        y: read(rect.y),
        width: read(rect.width),
        height: read(rect.height),
    };
}

function sameRect(a: ManagedWindowRect, b: ManagedWindowRect): boolean {
    return read(a.x) === read(b.x)
        && read(a.y) === read(b.y)
        && read(a.width) === read(b.width)
        && read(a.height) === read(b.height);
}

function activeRectTarget(window: WaylandWindow, windowRectState: WindowStateKey<ManagedWindowRect>): RectAnimationTarget | undefined {
    return activeRectAnimationTargetByWindow.get(window)?.get(windowRectState);
}

function setActiveRectTarget(
    window: WaylandWindow,
    windowRectState: WindowStateKey<ManagedWindowRect>,
    target: RectAnimationTarget | undefined,
): void {
    let perWindow = activeRectAnimationTargetByWindow.get(window);
    if (!perWindow) {
        perWindow = new Map();
        activeRectAnimationTargetByWindow.set(window, perWindow);
    }

    if (target) {
        perWindow.set(windowRectState, target);
    } else {
        perWindow.delete(windowRectState);
    }
}

function clearActiveRectTarget(
    window: WaylandWindow,
    windowRectState: WindowStateKey<ManagedWindowRect>,
    token: number,
): void {
    if (activeRectTarget(window, windowRectState)?.token === token) {
        setActiveRectTarget(window, windowRectState, undefined);
    }
}

export function playRectAnimation(
    window: WaylandWindow,
    windowRectState: WindowStateKey<ManagedWindowRect>,
    to: ManagedWindowRect,
    easing: EasingFunction,
    duration: number,
    options: RectAnimationOptions = {},
): void {
    const from = snapshotRect(window.state[windowRectState]());
    const target = snapshotRect(to);

    // Layout/focus updates can ask for the same target repeatedly while Rust is
    // already interpolating toward it. Re-scheduling the same channel in that
    // case races with focus-driven reevaluations and can leave one window using
    // an older animated rect for a frame. Treat rect animation requests as
    // idempotent at the declarative target level.
    const previousTarget = activeRectTarget(window, windowRectState)?.target;
    if (previousTarget && sameRect(previousTarget, target)) {
        return;
    }

    if (options.squashOnMove) {
        playWindowJelly(window, from, target, duration);
    } else {
        stopWindowJelly(window);
    }
    if (options.layoutMeltOutput) {
        trackLayoutMeltMotion(options.layoutMeltOutput, window.id, from, target, easing, duration);
    } else {
        stopLayoutMeltMotion(window.id);
    }

    // TS keeps the declarative target. Rust owns the frame-by-frame visual
    // interpolation and falls back to this target when the scheduled animation
    // finishes or is cancelled.
    window.state[windowRectState].set(target);
    const token = ++rectAnimationToken;
    setActiveRectTarget(window, windowRectState, { target, token });
    window.scheduleAnimation({
        channel: rectAnimationChannel(windowRectState),
        rect: {
            from,
            to: target,
            duration,
            easing,
            mode: "override",
        },
    });

    setTimeout(() => {
        clearActiveRectTarget(window, windowRectState, token);
    }, duration);
}

export function stopRectAnimation(
    window: WaylandWindow,
    windowRectState: WindowStateKey<ManagedWindowRect>,
): void {
    setActiveRectTarget(window, windowRectState, undefined);
    stopLayoutMeltMotion(window.id);
    stopWindowJelly(window);
    window.cancelAnimation(rectAnimationChannel(windowRectState));
}
