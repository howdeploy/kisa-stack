import {
  COMPOSITOR, animationVariable, createAnimationController, signal, markLayerDirty,
  compileLayerEffect, compileOverlayEffect, backdropSource, shaderStage,
  loadShader, type WaylandLayer,
} from "shoji_wm";

const SHADER = loadShader("./src/effect/aquarium-water.frag");
const CLOCK = animationVariable("aquarium.phase");
const enabled = signal(0);

function dirtyMist(): void {
  for (const layer of Object.values(COMPOSITOR.layer.current))
    if (layer.namespace === "shoji-aquarium-mist") markLayerDirty(layer.id);
}
const animation = createAnimationController(dirtyMist);
const phase = animation.variable(CLOCK);

type WaterMotion = {
  value: ReturnType<typeof signal<[number, number]>>;
  at: number;
  waveId: string;
  progress: number;
};
const motions = new Map<string, WaterMotion>();

function waterMotion(output: string): WaterMotion {
  let motion = motions.get(output);
  if (!motion) {
    motion = { value: signal<[number, number]>([0, 0]), at: Date.now(), waveId: "", progress: 0 };
    motions.set(output, motion);
  }
  return motion;
}

function advanceWater(motion: WaterMotion, now: number): void {
  const dt = Math.max(0, now - motion.at) / 1000;
  if (dt === 0) return;
  const [position, velocity] = motion.value.peek();
  // Exact damped oscillator: frame stalls cannot destabilize the water.
  const damping = 1.35, frequency = 5.5;
  const decay = Math.exp(-damping * dt);
  const c = Math.cos(frequency * dt), s = Math.sin(frequency * dt);
  motion.value.value = [
    decay * (position * c + (velocity + damping * position) * s / frequency),
    decay * (velocity * c - (damping * velocity
      + (frequency * frequency + damping * damping) * position) * s / frequency),
  ];
  motion.at = now;
}

phase.subscribe(() => {
  const now = Date.now();
  for (const [output, motion] of motions) {
    if (!COMPOSITOR.output.list.includes(output)) motions.delete(output);
    else advanceWater(motion, now);
  }
  if (enabled.peek()) dirtyMist();
});

export function driveAquariumWorkspaceWave(output: string, id: string, progress: number, direction: number): void {
  if (!enabled.peek()) return;
  const motion = waterMotion(output);
  advanceWater(motion, Date.now());
  if (motion.waveId !== id) {
    motion.waveId = id;
    motion.progress = progress;
    return;
  }
  const delta = progress - motion.progress;
  motion.progress = progress;
  // Completion/cleanup must not inject a synthetic last jump into the water.
  if (progress >= 1 || delta === 0) return;
  const [position, velocity] = motion.value.peek();
  motion.value.value = [position, Math.max(-0.4, Math.min(0.4, velocity + direction * delta * 0.7))];
}

export function setAquariumEnabled(value: boolean): void {
  if (enabled.peek() === (value ? 1 : 0)) return;
  enabled.value = value ? 1 : 0;
  if (value) animation.start(CLOCK, { from: 0, to: 1, duration: 96_000, repeat: "loop" });
  else {
    animation.stop(CLOCK);
    for (const motion of motions.values()) motion.value.value = [0, 0];
    motions.clear();
  }
  dirtyMist();
}

export function aquariumOverlayEffect(outputName: string) {
  const output = COMPOSITOR.output.current[outputName];
  if (!output?.resolution || output.scale <= 0) throw new Error("Aquarium output disappeared");
  return compileOverlayEffect({
    input: backdropSource(), alpha: "preserve",
    invalidate: { kind: "always" },
    pipeline: [shaderStage(SHADER, { uniforms: {
      aquarium_enabled: enabled, aquarium_phase: phase, aquarium_plane: 1,
      aquarium_slosh: waterMotion(outputName).value,
      aquarium_origin: [output.position.x, output.position.y],
      aquarium_extent: [output.resolution.width / output.scale, output.resolution.height / output.scale],
    } })],
  });
}

export function aquariumMistEffect(layer: WaylandLayer) {
  if (!enabled()) return null;
  const output = COMPOSITOR.output.current[layer.outputName()];
  if (!output) return null;
  phase();
  return compileLayerEffect({
    input: backdropSource(), alpha: "preserve", capturePadding: 0,
    invalidate: { kind: "manual", dirtyWhen: animation.running(CLOCK) },
    pipeline: [shaderStage(SHADER, { uniforms: {
      aquarium_enabled: enabled, aquarium_phase: phase, aquarium_plane: 0,
      aquarium_slosh: waterMotion(layer.outputName()).value,
      aquarium_origin: [output.position.x + layer.position.x, output.position.y + layer.position.y],
      aquarium_extent: [layer.position.width, layer.position.height],
    } })],
  });
}
