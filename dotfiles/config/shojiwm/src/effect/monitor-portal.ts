import {
  COMPOSITOR, animationVariable, createAnimationController, markLayerDirty,
  compileLayerEffect, layerSource, shaderStage, loadShader,
  type WindowMoveEvent, type WaylandLayer,
} from "shoji_wm";

const CLOCK = animationVariable("monitor.portal.clock");
const OPACITY = animationVariable("monitor.portal.opacity");
const SHADER = loadShader("./src/effect/monitor-window-portal.frag");
let outputs: string[] = [];
let center: [number, number] = [0, 0];
let normal: [number, number] = [1, 0];
let halfLength = 1;
let fadeTimer: ReturnType<typeof setTimeout> | undefined;
function dirty(): void {
  for (const output of outputs) {
    for (const layer of COMPOSITOR.layer.forOutput(output)) {
      if (layer.namespace === "shoji-layout-melt") markLayerDirty(layer.id);
    }
  }
}
const animation = createAnimationController(dirty);

function outputRect(name: string): number[] | null {
  const output = COMPOSITOR.output.current[name];
  if (!output?.resolution || output.scale <= 0) return null;
  return [output.position.x, output.position.y,
    output.resolution.width / output.scale, output.resolution.height / output.scale];
}

function intersection(a: number[], b: number[], window: number[]) {
  for (const axis of [0, 1]) {
    const tangent = 1 - axis;
    const edge = Math.abs(a[axis] + a[axis + 2] - b[axis]) <= 1 ? b[axis]
      : Math.abs(b[axis] + b[axis + 2] - a[axis]) <= 1 ? a[axis] : null;
    if (edge === null || window[axis] >= edge || window[axis] + window[axis + 2] <= edge) continue;
    const low = Math.max(a[tangent], b[tangent], window[tangent]);
    const high = Math.min(a[tangent] + a[tangent + 2], b[tangent] + b[tangent + 2],
      window[tangent] + window[tangent + 2]);
    if (high <= low) continue;
    const along = (low + high) / 2;
    return { center: (axis === 0 ? [edge, along] : [along, edge]) as [number, number],
      normal: (axis === 0 ? [1, 0] : [0, 1]) as [number, number], halfLength: (high - low) / 2 };
  }
  return null;
}

export function stopMonitorPortals(): void {
  if (fadeTimer !== undefined) clearTimeout(fadeTimer);
  fadeTimer = undefined;
  animation.stop(CLOCK);
  animation.set(OPACITY, 0);
  outputs = [];
}

function fadeOut(): void {
  if (!outputs.length || fadeTimer !== undefined) return;
  animation.start(OPACITY, { to: 0, duration: 180 });
  fadeTimer = setTimeout(stopMonitorPortals, 190);
}

export function updateMonitorPortal(event: WindowMoveEvent): void {
  if (event.phase === "end" || event.phase === "cancel") { fadeOut(); return; }
  const rect = event.currentRect;
  const window = [rect.x, rect.y, rect.width, rect.height];
  const monitors = COMPOSITOR.output.list;
  let best: (NonNullable<ReturnType<typeof intersection>> & { outputs: string[] }) | null = null;
  for (let i = 0; i < monitors.length; i++) {
    for (let j = i + 1; j < monitors.length; j++) {
      const a = outputRect(monitors[i]), b = outputRect(monitors[j]);
      const seam = a && b ? intersection(a, b, window) : null;
      if (seam && (!best || seam.halfLength > best.halfLength))
        best = { ...seam, outputs: [monitors[i], monitors[j]] };
    }
  }
  if (!best) { fadeOut(); return; }
  const wasFading = fadeTimer !== undefined;
  if (fadeTimer !== undefined) clearTimeout(fadeTimer);
  fadeTimer = undefined;
  dirty(); // Retire the old output's cached effect if the seam changed.
  outputs = best.outputs;
  center = best.center;
  normal = best.normal;
  halfLength = best.halfLength;
  if (!animation.running(CLOCK))
    animation.start(CLOCK, { from: 0, to: 1, duration: 1000, repeat: "loop" });
  if (wasFading || (!animation.running(OPACITY) && animation.variable(OPACITY).peek() < 1))
    animation.start(OPACITY, { to: 1, duration: 100 });
  dirty();
}

export function monitorPortalEffect(layer: WaylandLayer) {
  const opacity = animation.variable(OPACITY);
  const visible = opacity();
  const clock = animation.variable(CLOCK);
  clock();
  const outputName = layer.outputName();
  const output = COMPOSITOR.output.current[outputName];
  if ((visible <= 0 && !animation.running(OPACITY)) || !outputs.includes(outputName) || !output) return null;
  return compileLayerEffect({
    input: layerSource(), alpha: "preserve",
    invalidate: { kind: "manual", dirtyWhen: animation.running(CLOCK) || animation.running(OPACITY) },
    pipeline: [shaderStage(SHADER, { uniforms: {
      portal_time: clock, portal_opacity: opacity, portal_normal: normal,
      // Native layer snapshots are output-local (despite the TS type comment).
      portal_center: [center[0] - output.position.x - layer.position.x,
        center[1] - output.position.y - layer.position.y],
      portal_half_length: halfLength,
      portal_extent: [layer.position.width, layer.position.height],
    } })],
  });
}
