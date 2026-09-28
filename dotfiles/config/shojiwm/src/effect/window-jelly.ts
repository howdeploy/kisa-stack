import {
  animationVariable,
  compileWindowEffect,
  loadShader,
  read,
  shaderStage,
  windowSource,
  type WaylandWindow,
} from "shoji_wm";
import type { ManagedWindowRect } from "shoji_wm/types";

const PROGRESS = animationVariable("window.jelly.progress");
const CONTACT_X = animationVariable("window.jelly.contactX");
const CONTACT_Y = animationVariable("window.jelly.contactY");
const NORMAL_X = animationVariable("window.jelly.normalX");
const NORMAL_Y = animationVariable("window.jelly.normalY");
const STRENGTH = animationVariable("window.jelly.strength");
const PADDING = 16;
const SHADER = loadShader("./src/effect/window-jelly-edge-soft.frag");

export function playWindowJelly(
  window: WaylandWindow,
  from: ManagedWindowRect,
  to: ManagedWindowRect,
  duration: number,
): void {
  // Track the edge itself, not just motion direction: a contracting right edge
  // still receives its impulse on the right. Equal deltas select the leading edge.
  const left = read(to.x) - read(from.x);
  const right = left + read(to.width) - read(from.width);
  const top = read(to.y) - read(from.y);
  const bottom = top + read(to.height) - read(from.height);
  const hitRight = Math.abs(right) > Math.abs(left)
    || (Math.abs(right) === Math.abs(left) && right > 0);
  const hitBottom = Math.abs(bottom) > Math.abs(top)
    || (Math.abs(bottom) === Math.abs(top) && bottom > 0);
  const dx = hitRight ? right : left;
  const dy = hitBottom ? bottom : top;
  const horizontal = Math.abs(dx) >= Math.abs(dy);
  const travel = Math.max(Math.abs(dx), Math.abs(dy));
  if (travel < 1) {
    stopWindowJelly(window);
    return;
  }
  window.animation.set(CONTACT_X, horizontal ? (hitRight ? 1 : 0) : 0.5);
  window.animation.set(CONTACT_Y, horizontal ? 0.5 : (hitBottom ? 1 : 0));
  window.animation.set(NORMAL_X, horizontal ? (hitRight ? -1 : 1) : 0);
  window.animation.set(NORMAL_Y, horizontal ? 0 : (hitBottom ? -1 : 1));
  window.animation.set(STRENGTH, Math.min(6, 1.4 + travel * 0.008));
  // Let the material settle just after the rigid layout lands, without dragging
  // the window's position or requesting additional sizes from the client.
  window.animation.start(PROGRESS, { from: 0, to: 1, duration: duration + 100 });
}

export function stopWindowJelly(window: WaylandWindow): void {
  if (window.animation.running(PROGRESS)) window.animation.set(PROGRESS, 1);
}

export function windowJellyEffect(window: WaylandWindow) {
  const progress = window.animation.variable(PROGRESS);
  // Read the endpoint even when the timeline is idle, so the effect detaches.
  if (progress() >= 1 || !window.animation.running(PROGRESS)) return null;
  return {
    replace: compileWindowEffect({
      input: windowSource({ include: "full" }),
      outsets: { left: PADDING, right: PADDING, top: PADDING, bottom: PADDING },
      alpha: "preserve",
      invalidate: { kind: "manual", dirtyWhen: window.animation.running(PROGRESS) },
      pipeline: [shaderStage(SHADER, {
        uniforms: {
          jelly_progress: progress,
          jelly_contact: [window.animation.variable(CONTACT_X)(),
            window.animation.variable(CONTACT_Y)()] as [number, number],
          jelly_normal: [window.animation.variable(NORMAL_X)(),
            window.animation.variable(NORMAL_Y)()] as [number, number],
          jelly_strength: window.animation.variable(STRENGTH),
          jelly_extent: [window.rect.width + PADDING * 2,
            window.rect.height + PADDING * 2] as [number, number],
        },
      })],
    }),
  };
}
