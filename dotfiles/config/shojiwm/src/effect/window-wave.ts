import {
  animationVariable,
  compileWindowEffect,
  cubicBezier,
  loadShader,
  shaderStage,
  uniformArray,
  windowSource,
  type WaylandWindow,
} from "shoji_wm";

export const WINDOW_WAVE_DURATION = 460;
export const WINDOW_DISSOLVE_DURATION = 512;
const CLOSED = animationVariable("window.wave.closed");
const DIRECTION = animationVariable("window.wave.direction");
const DISSOLVE = animationVariable("window.wave.dissolve");
const REVEAL_AT_CLOSE = animationVariable("window.wave.revealAtClose");
const CHANNEL = "window.wave";
const FINISH_HIDE = cubicBezier(1, 0, 1, 0);
const SHADER = loadShader("./src/effect/window-wave-sparse.frag");
const THEME_ACCENT = [203 / 255, 166 / 255, 247 / 255] as const;
type WaveOrigin = [number, number, number, number];
const closeWaves = new WeakMap<WaylandWindow, WaveOrigin[]>();
const DEFAULT_WAVES: WaveOrigin[] = Array.from({ length: 6 }, (_, i) =>
  [((i % 3) + 0.5) / 3, (Math.floor(i / 3) + 0.5) / 2, 0, 1]);

export function playWindowWave(
  window: WaylandWindow,
  opening: boolean,
  alreadyHidden = false,
  effect: "wave" | "dissolve" = "wave",
): void {
  const dissolve = !opening && effect === "dissolve";
  const running = window.animation.running(CLOSED);
  const current = window.animation.variable(CLOSED).peek();
  const hidden = alreadyHidden && !running;
  let from = !running && (opening || hidden) ? 1 : current;
  if (dissolve) {
    // Closing during a reveal/minimize must not bring missing pixels back.
    window.animation.set(REVEAL_AT_CLOSE, hidden ? 0 : 1 - current);
    // Fixed for this close: random placement is not recomputed per pixel/frame.
    closeWaves.set(window, DEFAULT_WAVES.map(([x, y]) => [
      x + (Math.random() - 0.5) * 0.20,
      y + (Math.random() - 0.5) * 0.30,
      Math.random() * 0.08,
      0.94 + Math.random() * 0.12,
    ]));
    from = hidden || current >= 1 ? 1 : 0;
  }
  const to = opening ? 0 : 1;
  const duration = Math.max(1, Math.round(
    (dissolve ? WINDOW_DISSOLVE_DURATION : WINDOW_WAVE_DURATION) * Math.abs(to - from),
  ));
  window.animation.set(DIRECTION, opening ? 1 : -1);
  window.animation.set(DISSOLVE, dissolve ? 1 : 0);
  // Radial easing lives in GLSL: reversing this clock retraces the same wave.
  window.animation.start(CLOSED, { from, to, duration });
  if (!opening) window.setCloseAnimationDuration(duration + 34);
  // Native activity keeps the surface alive even after logical minimization.
  window.scheduleAnimation({
    channel: CHANNEL,
    opacity: {
      from: hidden ? 0 : 1,
      to: opening ? 1 : 0,
      duration,
      easing: FINISH_HIDE,
      mode: "multiply",
    },
  });
}

export function windowWaveIsHiding(window: WaylandWindow): boolean {
  return window.animation.variable(DIRECTION)() < 0
    && window.animation.variable(CLOSED)() < 1;
}

export function windowWaveClosedProgress(window: WaylandWindow) {
  return window.animation.variable(CLOSED);
}

export function windowWaveEffect(window: WaylandWindow) {
  const closed = window.animation.variable(CLOSED);
  if (closed() <= 0 && !window.animation.running(CLOSED)) return null;
  return {
    replace: compileWindowEffect({
      input: windowSource({ include: "full" }),
      alpha: "preserve",
      invalidate: { kind: "manual", dirtyWhen: window.animation.running(CLOSED) },
      pipeline: [shaderStage(SHADER, {
        uniforms: {
          closed,
          dissolving: window.animation.variable(DISSOLVE),
          reveal_at_close: window.animation.variable(REVEAL_AT_CLOSE),
          wave_origins: uniformArray.vec4(closeWaves.get(window) ?? DEFAULT_WAVES),
          surface_size: [window.rect.width, window.rect.height] as [number, number],
          theme_accent: THEME_ACCENT,
        },
      })],
    }),
  };
}
