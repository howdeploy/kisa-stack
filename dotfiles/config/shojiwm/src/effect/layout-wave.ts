import {
  COMPOSITOR, animationVariable, createAnimationController, markLayerDirty,
  compileLayerEffect, backdropSource, shaderStage, loadShader, cubicBezier, read,
  stateTexture, stateSource, renderTo, uniformArray,
  type AnimationController, type WaylandLayer, type EasingFunction,
} from "shoji_wm";
import type { ManagedWindowRect } from "shoji_wm/types";
import { flowHistory, sampleFlowMotion as sample, FLOW_SETTLE_SECONDS,
  type FlowMotion as Motion, type FlowRect as Rect } from "./layout-flow-history";

// Short travel. The previous 1100 ms ease-in felt sluggish.
export const LAYOUT_TRANSITION_DURATION = 480;
export const LAYOUT_TRANSITION_EASING = cubicBezier(0.22, 0.9, 0.28, 1.0);
const SETTLE_DURATION = FLOW_SETTLE_SECONDS * 1000;
const CLOCK = animationVariable("layout.water.clock");
const CLEAR = loadShader("./src/effect/layout-flow-clear.frag");
const SOURCE = loadShader("./src/effect/layout-flow-source.frag");
const MASK = loadShader("./src/effect/layout-flow-mask.frag");
const COMPOSE = loadShader("./src/effect/layout-flow-compose.frag");
interface Water {
  animation: AnimationController;
  motions: Map<string, Motion>;
  trails: Motion[];
  end: number;
}
const surfaces = new Map<string, Water>();

function waterFor(output: string): Water {
  let water = surfaces.get(output);
  if (!water) {
    const animation = createAnimationController(() => {
      for (const layer of COMPOSITOR.layer.forOutput(output)) {
        if (layer.namespace === "shoji-water" && layer.layer === "bottom"
          && layer.anchor.top && layer.anchor.bottom && layer.anchor.left && layer.anchor.right) {
          markLayerDirty(layer.id);
        }
      }
    });
    water = { animation, motions: new Map(), trails: [], end: 0 };
    surfaces.set(output, water);
  }
  return water;
}

function rectValues(rect: ManagedWindowRect): Rect {
  return [read(rect.x), read(rect.y), read(rect.width), read(rect.height)];
}

export function startLayoutWave(output: string): void {
  const water = waterFor(output);
  const active = water.animation.running(CLOCK);
  const from = active ? water.animation.variable(CLOCK).peek() : 0;
  if (!active) {
    water.motions.clear();
    water.trails = [];
  }
  water.end = from + (LAYOUT_TRANSITION_DURATION + SETTLE_DURATION) / 1000;
  water.animation.start(CLOCK, {
    from, to: water.end, duration: LAYOUT_TRANSITION_DURATION + SETTLE_DURATION,
  });
}

export function trackLayoutWaterMotion(
  output: string, id: string, from: ManagedWindowRect, to: ManagedWindowRect,
  easing: EasingFunction, duration: number,
): void {
  const water = waterFor(output);
  const time = water.animation.variable(CLOCK).peek();
  const previous = water.motions.get(id);
  // Match native rect-channel retargeting: resume from the interpolated rect.
  const start = previous ? sample(previous, time) : rectValues(from);
  if (previous) previous.stopped = Math.min(time, previous.started + previous.duration);
  const motion: Motion = { from: start, to: rectValues(to), started: time,
    duration: Math.max(1, duration) / 1000, easing };
  water.motions.set(id, motion);
  water.trails.push(motion);
}

export function stopLayoutWaterMotion(id: string): void {
  for (const water of surfaces.values()) {
    const motion = water.motions.get(id);
    if (motion) motion.stopped = Math.min(water.animation.variable(CLOCK).peek(), motion.started + motion.duration);
    water.motions.delete(id);
  }
}

export function stopLayoutWaves(): void {
  for (const water of surfaces.values()) water.animation.stop(CLOCK);
  surfaces.clear();
}

export function layoutWaveEffect(layer: WaylandLayer, visibleWindows: () => { id: string; rect: ManagedWindowRect }[]) {
  const anchor = layer.anchor();
  // shoji-water sits above the wallpaper and below windows.
  if (layer.namespace() !== "shoji-water" || layer.layer() !== "bottom"
    || !anchor.top || !anchor.bottom || !anchor.left || !anchor.right) return null;
  const output = layer.outputName();
  const water = waterFor(output);
  const time = water.animation.variable(CLOCK)();
  if (time >= water.end || !water.animation.running(CLOCK)) return null;
  const size: [number, number] = [layer.position.width, layer.position.height];
  const outputScale = COMPOSITOR.output.current[output]?.scale ?? 1;
  // History supplies the wake; this texture only combines it for the current frame.
  const field = stateTexture("layout-parting-lines-v1", {
    scale: 1 / outputScale, format: "rgba16f", resize: "clear",
  });
  const local = (rect: Rect): Rect => [
    rect[0] - layer.position.x, rect[1] - layer.position.y, rect[2], rect[3],
  ];
  water.trails = water.trails.filter(motion =>
    time < (motion.stopped ?? motion.started + motion.duration) + FLOW_SETTLE_SECONDS);
  return {
    behind: compileLayerEffect({
      input: backdropSource(),
      capturePadding: 16,
      alpha: "preserve",
      invalidate: { kind: "manual", dirtyWhen: true },
      pipeline: [
        renderTo(field, {
          input: stateSource(field), alpha: "preserve",
          pipeline: [shaderStage(CLEAR)],
        }),
        ...water.trails.map(motion => {
          const history = flowHistory(motion, time);
          return renderTo(field, {
            input: stateSource(field), alpha: "preserve",
            pipeline: [shaderStage(SOURCE, { uniforms: {
              water_size: size,
              flow_rects: uniformArray.vec4(history.rects.map(local)),
              flow_deltas: uniformArray.vec4(history.deltas),
              flow_ages: uniformArray.float(history.ages),
            } })],
          });
        }),
        ...visibleWindows().map(window => {
          const motion = water.motions.get(window.id);
          const rect = local(motion ? sample(motion, time) : rectValues(window.rect));
          return renderTo(field, {
            input: stateSource(field), alpha: "preserve",
            pipeline: [shaderStage(MASK, { uniforms: { water_size: size, window_rect: rect } })],
          });
        }),
        shaderStage(COMPOSE, {
          textures: { water_field: stateSource(field) },
          uniforms: { water_size: size },
        }),
      ],
    }),
  };
}
