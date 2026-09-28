import {
  COMPOSITOR, animationVariable, createAnimationController, markLayerDirty,
  compileLayerEffect, backdropSource, xrayBackdropSource, shaderStage, loadShader,
  cubicBezier, read, save, get, stateTexture, stateSource, renderTo, dualKawaseBlur,
  type AnimationController, type WaylandLayer, type EasingFunction,
} from "shoji_wm";
import type { ManagedWindowRect } from "shoji_wm/types";
import { sampleFlowMotion as sample, type FlowMotion as Motion,
  type FlowRect as Rect } from "./layout-flow-history";

export const LAYOUT_TRANSITION_DURATION = 760;
export const LAYOUT_TRANSITION_EASING = cubicBezier(0.45, 0, 0.55, 1);
const CLOCK = animationVariable("layout.melt.clock");
const CLEAR = loadShader("./src/effect/layout-melt-clear.frag");
const SOURCE = loadShader("./src/effect/layout-melt-source.frag");
const WARP = loadShader("./src/effect/layout-melt-warp.frag");
const COMPOSE = loadShader("./src/effect/layout-fog-compose.frag");
interface Transition {
  animation: AnimationController;
  motions: Map<string, Motion>;
  started: number;
  initialMelt: number;
}
const transitions = new Map<string, Transition>();

function transitionFor(output: string): Transition {
  let transition = transitions.get(output);
  if (!transition) {
    const animation = createAnimationController(() => {
      for (const layer of COMPOSITOR.layer.forOutput(output)) {
        if (layer.namespace === "shoji-layout-melt") markLayerDirty(layer.id);
      }
    });
    transition = { animation, motions: new Map(), started: 0, initialMelt: 0 };
    transitions.set(output, transition);
  }
  return transition;
}

function meltAmount(transition: Transition, time: number): number {
  const progress = Math.max(0, (time - transition.started) * 1000 / LAYOUT_TRANSITION_DURATION);
  const rise = Math.min(1, progress / 0.35);
  const fall = Math.max(0, Math.min(1, (progress - 0.55) / 0.45));
  return (transition.initialMelt + (1 - transition.initialMelt) * rise * rise * (3 - 2 * rise))
    * (1 - fall * fall * (3 - 2 * fall));
}

function rectValues(rect: ManagedWindowRect): Rect {
  return [read(rect.x), read(rect.y), read(rect.width), read(rect.height)];
}

export function startLayoutMelt(output: string): void {
  const transition = transitionFor(output);
  const active = transition.animation.running(CLOCK);
  const time = transition.animation.variable(CLOCK).peek();
  transition.initialMelt = active ? meltAmount(transition, time) : 0;
  if (!active) transition.motions.clear();
  transition.started = time;
  transition.animation.start(CLOCK, {
    from: time, to: time + LAYOUT_TRANSITION_DURATION / 1000,
    duration: LAYOUT_TRANSITION_DURATION,
  });
}

export function trackLayoutMeltMotion(
  output: string, id: string, from: ManagedWindowRect, to: ManagedWindowRect,
  easing: EasingFunction, duration: number,
): void {
  const transition = transitionFor(output);
  const time = transition.animation.variable(CLOCK).peek();
  const previous = transition.motions.get(id);
  transition.motions.set(id, {
    from: previous ? sample(previous, time) : rectValues(from),
    to: rectValues(to), started: time, duration: Math.max(1, duration) / 1000, easing,
  });
}

export function stopLayoutMelts(): void {
  for (const transition of transitions.values()) transition.animation.stop(CLOCK);
  transitions.clear();
}

export function stopLayoutMeltMotion(id: string): void {
  for (const transition of transitions.values()) transition.motions.delete(id);
}

export function layoutMeltEffect(
  layer: WaylandLayer, visibleWindows: () => { id: string; rect: ManagedWindowRect }[],
) {
  const anchor = layer.anchor();
  if (layer.namespace() !== "shoji-layout-melt" || layer.layer() !== "top"
    || !anchor.top || !anchor.bottom || !anchor.left || !anchor.right) return null;
  const output = layer.outputName();
  const transition = transitionFor(output);
  const time = transition.animation.variable(CLOCK)();
  if (!transition.animation.running(CLOCK)) return null;
  const size: [number, number] = [layer.position.width, layer.position.height];
  if (size[0] <= 0 || size[1] <= 0) return null;
  const local = (rect: Rect): Rect => [
    rect[0] - layer.position.x, rect[1] - layer.position.y, rect[2], rect[3],
  ];
  const usable = COMPOSITOR.layer.usableArea(output);
  const work: Rect = usable ? local(rectValues(usable)) : [0, 0, ...size];
  const rects = visibleWindows().map(window => {
    const motion = transition.motions.get(window.id);
    return local(motion ? sample(motion, time) : rectValues(window.rect));
  }).filter(rect => rect[2] > 0 && rect[3] > 0 && rect[0] < size[0]
    && rect[1] < size[1] && rect[0] + rect[2] > 0 && rect[1] + rect[3] > 0);
  if (!rects.length) return null;
  const left = Math.max(work[0], Math.min(...rects.map(rect => rect[0])));
  const top = Math.max(work[1], Math.min(...rects.map(rect => rect[1])));
  const right = Math.min(work[0] + work[2], Math.max(...rects.map(rect => rect[0] + rect[2])));
  const bottom = Math.min(work[1] + work[3], Math.max(...rects.map(rect => rect[1] + rect[3])));
  if (right <= left || bottom <= top) return null;
  const scale = 1 / (COMPOSITOR.output.current[output]?.scale ?? 1);
  // All windows share these textures. Overlap blends their colors before warping.
  const foreground = stateTexture("layout-melt-windows-v1", { scale, resize: "clear" });
  const colors = stateTexture("layout-melt-colors-v1", { scale: scale * 0.5, resize: "clear" });
  const mixedColors = stateTexture("layout-melt-mixed-colors-v1", {
    scale: scale * 0.25, format: "rgba16f", resize: "clear",
  });
  const flow = stateTexture("layout-melt-flow-v1", { scale: scale * 0.25, resize: "clear" });
  return {
    behind: compileLayerEffect({
      input: backdropSource(), capturePadding: 0, alpha: "preserve",
      invalidate: { kind: "manual", dirtyWhen: true },
      pipeline: [
        save("layout-melt-live"),
        renderTo(foreground, {
          input: stateSource(foreground), alpha: "preserve",
          pipeline: [shaderStage(CLEAR)],
        }),
        ...rects.map(rect => renderTo(foreground, {
          input: stateSource(foreground), alpha: "preserve",
          pipeline: [shaderStage(SOURCE, {
            textures: { scene: get("layout-melt-live") },
            uniforms: { screen_size: size, window_rect: rect },
          })],
        })),
        renderTo(colors, {
          input: stateSource(foreground), alpha: "preserve",
          pipeline: [dualKawaseBlur({ radius: 6, passes: 3 })],
        }),
        renderTo(flow, {
          input: stateSource(flow), alpha: "preserve",
          pipeline: [shaderStage(WARP, { uniforms: { screen_size: size, flow_time: time } })],
        }),
        // Carry window colors across the gaps without substituting theme colors.
        renderTo(mixedColors, {
          input: stateSource(colors), alpha: "preserve",
          pipeline: [dualKawaseBlur({ radius: 2, passes: 6 })],
        }),
        shaderStage(COMPOSE, {
          textures: {
            windows: stateSource(foreground), colors: stateSource(colors),
            mixed_colors: stateSource(mixedColors),
            flow: stateSource(flow), wallpaper: xrayBackdropSource(),
          },
          uniforms: {
            screen_size: size, work_rect: work,
            group_rect: [left, top, right - left, bottom - top] as Rect,
            melt: meltAmount(transition, time),
          },
        }),
      ],
    }),
  };
}
