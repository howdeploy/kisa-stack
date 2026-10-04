import {
  COMPOSITOR, animationVariable, createAnimationController, markLayerDirty,
  compileLayerEffect, layerSource, shaderStage, loadShader, type WaylandLayer,
} from "shoji_wm";

// Set false and reload the compositor config to stop both planes.
export const SNOW_ENABLED = false;
const CYCLE_MS = 240_000;
const CLOCK = animationVariable("snow.phase");
const SHADER = loadShader("./src/effect/snow.frag");
const animation = createAnimationController(() => {
  for (const layer of Object.values(COMPOSITOR.layer.current)) {
    if (layer.namespace === "shoji-wallpaper-wave" || layer.namespace === "shoji-snow-near")
      markLayerDirty(layer.id);
  }
});

export function startSnow(): void {
  if (SNOW_ENABLED && !animation.running(CLOCK))
    animation.start(CLOCK, { from: 0, to: 1, duration: CYCLE_MS, repeat: "loop" });
}

export function stopSnow(): void {
  animation.stop(CLOCK);
}

export function snowEffect(layer: WaylandLayer) {
  if (!SNOW_ENABLED) return null;
  const output = COMPOSITOR.output.current[layer.outputName()];
  if (!output) return null;
  const phase = animation.variable(CLOCK);
  phase(); // Track the clock in this layer's composition, as with the portal effect.
  const near = layer.namespace() === "shoji-snow-near";
  // Use the snow surfaces' logical bounds, including output scale/rotation.
  let left = Infinity, top = Infinity, right = -Infinity, bottom = -Infinity;
  for (const surface of Object.values(COMPOSITOR.layer.current)) {
    if (surface.namespace !== "shoji-wallpaper-wave") continue;
    const screen = COMPOSITOR.output.current[surface.outputName];
    if (!screen) continue;
    const { x, y, width, height } = surface.position;
    left = Math.min(left, screen.position.x + x);
    top = Math.min(top, screen.position.y + y);
    right = Math.max(right, screen.position.x + x + width);
    bottom = Math.max(bottom, screen.position.y + y + height);
  }
  const desktop = Number.isFinite(left)
    ? [left, top, right - left, bottom - top]
    : [output.position.x, output.position.y, layer.position.width, layer.position.height];
  return compileLayerEffect({
    input: layerSource(), capturePadding: 0, alpha: "preserve",
    invalidate: { kind: "manual", dirtyWhen: animation.running(CLOCK) },
    pipeline: [shaderStage(SHADER, { uniforms: {
      // Retain the clock uniform name used by the previous snow revision.
      snow_phase_v2: phase,
      snow_near: near ? 1 : 0,
      snow_desktop: desktop,
      snow_extent: [layer.position.width, layer.position.height],
      // Layer positions are output-local; use logical desktop coordinates for seams/DPI.
      snow_origin: [output.position.x + layer.position.x, output.position.y + layer.position.y],
    } })],
  });
}
