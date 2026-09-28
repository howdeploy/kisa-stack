import {
  animationVariable, backdropSource, compileEffect, compileWindowEffect,
  createManagedPoll, dualKawaseBlur, loadShader, shaderStage, windowSource,
  type PollHandle, type WaylandWindow, type WindowMoveEvent, type WindowResizeEvent,
} from "shoji_wm";
import type { WindowEffectAssignment } from "shoji_wm/types";

const PHASE = animationVariable("ghostty.gel.phase");
const BEND_X = animationVariable("ghostty.gel.bendX");
const BEND_Y = animationVariable("ghostty.gel.bendY");
const BODY = loadShader("./src/effect/ghostty-jelly-volume.frag");
const PADDING = 16;

interface Body {
  window: WaylandWindow;
  poll?: PollHandle;
  closing: boolean;
  phase: number;
  x: number;
  y: number;
  vx: number;
  vy: number;
  targetX: number;
  targetY: number;
  pointer?: { x: number; y: number; time: number };
}
const bodies = new Map<string, Body>();

export function isGhostty(appId: string | undefined): boolean {
  return appId === "com.mitchellh.ghostty" || appId === "ghostty";
}

function bodyFor(window: WaylandWindow): Body {
  let body = bodies.get(window.id);
  if (!body) {
    body = { window, closing: false, phase: 0, x: 0, y: 0, vx: 0, vy: 0,
      targetX: 0, targetY: 0 };
    bodies.set(window.id, body);
  }
  return body;
}

function setActive(body: Body, active: boolean): void {
  if (!active || body.closing) {
    body.poll?.cancel();
    body.poll = undefined;
    body.targetX = body.targetY = 0;
    return;
  }
  if (body.poll && !body.poll.cancelled) return;
  let previousTime: number | undefined;
  body.poll = createManagedPoll(16, poll => {
    const dt = previousTime === undefined ? 0.016 : Math.max(0, Math.min(0.032, (poll.nowMs - previousTime) / 1000));
    previousTime = poll.nowMs;
    // Damped mass-spring response; substeps keep input bursts stable.
    const steps = Math.max(1, Math.ceil(dt / 0.008));
    const h = dt / steps;
    for (let i = 0; i < steps; i++) {
      body.vx += (110 * (body.targetX - body.x) - 13 * body.vx) * h;
      body.vy += (110 * (body.targetY - body.y) - 13 * body.vy) * h;
      body.x += body.vx * h;
      body.y += body.vy * h;
    }
    // A held pointer that stops moving must let the material relax too.
    body.targetX *= Math.exp(-9 * dt);
    body.targetY *= Math.exp(-9 * dt);
    body.phase = (body.phase + dt * 0.8) % (Math.PI * 2);
    body.window.animation.set(PHASE, body.phase);
    body.window.animation.set(BEND_X, Math.max(-6, Math.min(6, body.x)));
    body.window.animation.set(BEND_Y, Math.max(-6, Math.min(6, body.y)));
  }, "none");
}

export function ghosttyJellyInteraction(event: WindowMoveEvent | WindowResizeEvent): void {
  if (!isGhostty(event.window.appId())) return;
  const body = bodyFor(event.window);
  if (event.phase === "end" || event.phase === "cancel") {
    body.targetX = body.targetY = 0;
    body.pointer = undefined;
    return;
  }
  const pointer = event.currentPointer;
  if (event.phase === "update" && body.pointer) {
    const dt = Math.max(0.008, (event.timestamp - body.pointer.time) / 1000);
    body.targetX = Math.max(-5, Math.min(5, -(pointer.x - body.pointer.x) / dt * 0.004));
    body.targetY = Math.max(-5, Math.min(5, -(pointer.y - body.pointer.y) / dt * 0.004));
  }
  body.pointer = { x: pointer.x, y: pointer.y, time: event.timestamp };
}

function uniforms(window: WaylandWindow, pass: number, padding: number) {
  return {
    gel_pass: pass,
    gel_padding: padding,
    gel_extent: [window.rect.width, window.rect.height] as [number, number],
    gel_phase: window.animation.variable(PHASE),
    gel_bend: [window.animation.variable(BEND_X), window.animation.variable(BEND_Y)] as const,
  };
}

export function ghosttyJellyMaterial(window: WaylandWindow, active: boolean) {
  setActive(bodyFor(window), active);
  return compileEffect({
    input: backdropSource(), capturePadding: 48, alpha: "preserve",
    invalidate: { kind: "on-source-damage-box", damagePadding: 48 },
    pipeline: [
      dualKawaseBlur({ radius: 3, passes: 2 }),
      shaderStage(BODY, { uniforms: uniforms(window, 0, 0) }),
    ],
  });
}

export function ghosttyJellyShape(window: WaylandWindow, motion: WindowEffectAssignment | null) {
  if (!isGhostty(window.appId()) || !bodies.has(window.id)) return null;
  return {
    ...motion,
    replace: compileWindowEffect({
      input: windowSource({ include: "full" }),
      outsets: PADDING, alpha: "preserve",
      invalidate: { kind: "on-source-damage-box", damagePadding: PADDING },
      pipeline: [
        shaderStage(BODY, { uniforms: uniforms(window, 1, PADDING) }),
        ...(motion?.replace?.effect.pipeline ?? []),
      ],
    }),
  };
}

export function stopGhosttyJelly(window: WaylandWindow, remove = false): void {
  const body = bodies.get(window.id);
  if (!body) return;
  body.closing = true;
  setActive(body, false);
  if (remove) bodies.delete(window.id);
}

export function disposeGhosttyJelly(): void {
  for (const body of bodies.values()) body.poll?.cancel();
  bodies.clear();
}
