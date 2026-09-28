import {
  COMPOSITOR, animationVariable, compileWindowEffect, createWindowState, cubicBezier,
  dualKawaseBlur, get, loadShader, read, save, shaderStage, windowSource,
  type EasingFunction, type WaylandWindow,
} from "shoji_wm";
import type { ManagedWindowRect } from "shoji_wm/types";

export const WORKSPACE_PORTAL_DURATION = 520;
export const WORKSPACE_PORTAL_EASING = cubicBezier(0.33, 0, 0.67, 1);
const VISIBILITY = animationVariable("workspace.portal.visibility");
const SHADER = loadShader("./src/effect/workspace-portal.frag");
const PORTAL = createWindowState<{
  edge: number;
  hiding: boolean;
  viewport: [number, number, number, number];
} | null>("workspacePortal", { default: null });

export function setWorkspacePortal(
  window: WaylandWindow, monitor: string, offsetY: number, visibility: number,
  preserveCurrent = false,
): void {
  const edge = offsetY < 0 ? -1 : 1;
  if (preserveCurrent && window.state[PORTAL]()?.edge === edge) return;
  const usable = COMPOSITOR.layer.usableArea(monitor);
  const output = COMPOSITOR.output.current[monitor];
  const viewport: [number, number, number, number] = usable
    ? [read(usable.x), read(usable.y), read(usable.width), read(usable.height)]
    : [output?.position.x ?? 0, output?.position.y ?? 0,
       (output?.resolution?.width ?? 1) / (output?.scale ?? 1),
       (output?.resolution?.height ?? 1) / (output?.scale ?? 1)];
  window.state[PORTAL].set({ edge, viewport, hiding: false });
  window.animation.set(VISIBILITY, visibility);
}

export function playWorkspacePortal(
  window: WaylandWindow, monitor: string, offsetY: number,
  from: number, to: number, easing: EasingFunction, duration: number,
): void {
  setWorkspacePortal(window, monitor, offsetY, from, true);
  const portal = window.state[PORTAL]();
  if (portal) window.state[PORTAL].set({ ...portal, hiding: to === 0 });
  window.animation.start(VISIBILITY, {
    from: window.animation.variable(VISIBILITY).peek(), to, duration, easing,
  });
}

export function stopWorkspacePortal(window: WaylandWindow): void {
  window.animation.stop(VISIBILITY);
  window.state[PORTAL].set(null);
}

export function workspacePortalIsHiding(window: WaylandWindow): boolean {
  return window.state[PORTAL]()?.hiding ?? false;
}

export function workspacePortalEffect(window: WaylandWindow, rect: ManagedWindowRect) {
  const portal = window.state[PORTAL]();
  if (!portal) return null;
  const visibility = window.animation.variable(VISIBILITY);
  if (visibility() >= 1 && !window.animation.running(VISIBILITY)) return null;
  return {
    replace: compileWindowEffect({
      input: windowSource({ include: "full" }), alpha: "preserve",
      invalidate: { kind: "manual", dirtyWhen: true },
      pipeline: [
        save("workspace-portal-sharp"),
        dualKawaseBlur({ radius: 5, passes: 2 }),
        shaderStage(SHADER, {
          textures: { sharp_window: get("workspace-portal-sharp") },
          uniforms: {
            visibility, reveal_edge: portal.edge, viewport: portal.viewport,
            window_rect: [read(rect.x), read(rect.y), read(rect.width), read(rect.height)],
            pixel_size: 26,
          },
        }),
      ],
    }),
  };
}
