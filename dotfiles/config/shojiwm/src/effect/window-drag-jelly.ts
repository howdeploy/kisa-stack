import {
  animationVariable, compileWindowEffect, loadShader, shaderStage, windowSource,
  type WaylandWindow, type WindowMoveEvent,
} from "shoji_wm";

const PROGRESS = animationVariable("window.dragJelly.progress");
const SHADER = loadShader("./src/effect/window-drag-spring.frag");
const PADDING = 24;
const BEND_X = animationVariable("window.dragJelly.bendX");
const BEND_Y = animationVariable("window.dragJelly.bendY");
const VELOCITY_X = animationVariable("window.dragJelly.velocityX");
const VELOCITY_Y = animationVariable("window.dragJelly.velocityY");
const motion = new WeakMap<WaylandWindow, {
  pointer: { x: number; y: number }; grab: [number, number]; bend: [number, number];
  velocity: [number, number];
}>();

function spring(bend: number, velocity: number, progress: number): [number, number] {
  if (progress >= 1) return [0, 0];
  const t = progress * 0.6, decay = Math.exp(-8 * t);
  const c = Math.cos(20 * t), s = Math.sin(20 * t);
  const b = (velocity + 8 * bend) / 20;
  const position = decay * (bend * c + b * s);
  return [position, decay * (-20 * bend * s + 20 * b * c) - 8 * position];
}

export function stopDragJelly(window: WaylandWindow): void {
  motion.delete(window);
  if (window.animation.running(PROGRESS)) window.animation.set(PROGRESS, 1);
}

export function updateDragJelly(event: WindowMoveEvent): void {
  const window = event.window;
  if (event.phase === "cancel") { stopDragJelly(window); return; }
  let state = motion.get(window);
  if (event.phase === "start" || !state) {
    if (event.phase === "end") return;
    stopDragJelly(window);
    const clamp = (v: number) => Math.max(0, Math.min(1, v));
    state = {
      pointer: { ...event.currentPointer }, bend: [0, 0], velocity: [0, 0],
      grab: [clamp((event.startPointer.x - event.startRect.x) / Math.max(1, event.startRect.width)),
        clamp((event.startPointer.y - event.startRect.y) / Math.max(1, event.startRect.height))],
    };
    motion.set(window, state);
    return;
  }
  if (event.phase === "end") return; // The last bend settles after release.
  const dx = event.currentPointer.x - state.pointer.x;
  const dy = event.currentPointer.y - state.pointer.y;
  state.pointer = { ...event.currentPointer };
  if (dx === 0 && dy === 0) return;
  const time = window.animation.running(PROGRESS) ? window.animation.variable(PROGRESS).peek() : 1;
  const x = spring(state.bend[0], state.velocity[0], time);
  const y = spring(state.bend[1], state.velocity[1], time);
  const clamp = (v: number, limit: number) => Math.max(-limit, Math.min(limit, v));
  // Retain both displacement and velocity, so mouse events do not reset the wobble.
  state.bend = [clamp(x[0], 14), clamp(y[0], 14)];
  state.velocity = [clamp(x[1] - dx * 60, 600), clamp(y[1] - dy * 60, 600)];
  window.animation.set(BEND_X, state.bend[0]);
  window.animation.set(BEND_Y, state.bend[1]);
  window.animation.set(VELOCITY_X, state.velocity[0]);
  window.animation.set(VELOCITY_Y, state.velocity[1]);
  window.animation.start(PROGRESS, { from: 0, to: 1, duration: 600 });
}

export function dragJellyEffect(window: WaylandWindow) {
  const progress = window.animation.variable(PROGRESS);
  const time = progress();
  const state = motion.get(window);
  if (!state || time >= 1 || !window.animation.running(PROGRESS)) return null;
  return { replace: compileWindowEffect({
    input: windowSource({ include: "full" }), alpha: "preserve",
    outsets: { left: PADDING, right: PADDING, top: PADDING, bottom: PADDING },
    invalidate: { kind: "manual", dirtyWhen: window.animation.running(PROGRESS) },
    pipeline: [shaderStage(SHADER, { uniforms: {
      drag_progress: progress, drag_grab: state.grab,
      drag_bend: [window.animation.variable(BEND_X)(), window.animation.variable(BEND_Y)()],
      drag_velocity: [window.animation.variable(VELOCITY_X)(), window.animation.variable(VELOCITY_Y)()],
      drag_extent: [window.rect.width + PADDING * 2, window.rect.height + PADDING * 2],
    } })],
  }) };
}
