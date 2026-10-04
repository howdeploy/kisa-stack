import { COMPOSITOR, markLayerDirty, compileLayerEffect, backdropSource, shaderStage, loadShader,
  stateTexture, stateSource, renderTo,
  type WaylandLayer } from "shoji_wm";

const shader = loadShader("./src/effect/live-wallpaper-wave.frag");
const copy = loadShader("./src/effect/workspace-wave-copy.frag");
type Wave = { active: boolean; progress: number; capture: boolean;
  preparing?: boolean;
  geometry: { x: number; y: number; width: number; height: number } };
let wave: Wave | null = null;
let expiry: ReturnType<typeof setTimeout> | undefined;
let previousLayers = new Set<string>();

function dirty() {
  for (const layer of Object.values(COMPOSITOR.layer.current))
    if (layer.namespace === "shoji-wallpaper-wave") markLayerDirty(layer.id);
}

export function stopWallpaperWave() {
  if (expiry !== undefined) clearTimeout(expiry);
  expiry = undefined;
  wave = null;
  previousLayers.clear();
  dirty();
}

export function setWallpaperWave(value: unknown) {
  const next = value as Wave | null;
  if (!next || typeof next.active !== "boolean") throw new Error("Invalid wallpaper wave");
  if (!next.active) { stopWallpaperWave(); return; }
  const g = next.geometry;
  if (!Number.isFinite(next.progress) || next.progress < 0 || next.progress > 1
      || typeof next.capture !== "boolean" || !g
      || (next.preparing !== undefined && typeof next.preparing !== "boolean")
      || ![g.x, g.y, g.width, g.height].every(Number.isFinite) || g.width <= 0 || g.height <= 0)
    throw new Error("Invalid wallpaper wave geometry");
  if (!wave) previousLayers = new Set(Object.values(COMPOSITOR.layer.current)
    .filter(layer => layer.namespace === "linux-wallpaperengine").map(layer => layer.id));
  wave = next;
  if (expiry !== undefined) clearTimeout(expiry);
  // A dead shell must never leave an opaque curtain above the desktop.
  expiry = setTimeout(stopWallpaperWave, 10000);
  dirty();
}

export function wallpaperWaveEffect(layer: WaylandLayer) {
  if (!wave) return null;
  const output = COMPOSITOR.output.current[layer.outputName()];
  if (!output) return null;
  const previous = stateTexture("wallpaper-before-v1", { resize: "clear" });
  // Keep old video moving during decoder startup. Mapping a candidate freezes
  // the last old frame before that new surface can enter the saved backdrop.
  const candidateMapped = Object.values(COMPOSITOR.layer.current).some(candidate =>
    candidate.namespace === "linux-wallpaperengine" && candidate.outputName === layer.outputName()
    && !previousLayers.has(candidate.id));
  const capture = wave.capture || (wave.preparing && !candidateMapped);
  return compileLayerEffect({
    input: backdropSource(), capturePadding: 0, alpha: "opaque",
    invalidate: { kind: "on-source-damage-box", damagePadding: 0 },
    pipeline: [
      ...(capture ? [renderTo(previous, {
        input: backdropSource(), alpha: "opaque", pipeline: [shaderStage(copy)],
      })] : []),
      shaderStage(shader, { textures: { previous: stateSource(previous) }, uniforms: {
      viewportSize: [wave.geometry.width, wave.geometry.height],
      outputOrigin: [output.position.x + layer.position.x - wave.geometry.x,
        output.position.y + layer.position.y - wave.geometry.y],
      outputSize: [layer.position.width, layer.position.height],
      progress: wave.progress,
      accent: [0.796, 0.651, 0.969, 1], warm: [0.961, 0.761, 0.906, 1],
      backgroundColor: [0.118, 0.118, 0.180, 1],
    } })],
  });
}
