import {
  COMPOSITOR, animationVariable, createAnimationController, cubicBezier,
  type AnimationController,
} from "shoji_wm";

export const WORKSPACE_WAVE_DURATION = 940;
export const WORKSPACE_WAVE_EASING = cubicBezier(0.22, 0.1, 0.36, 1);
const PROGRESS = animationVariable("workspace.wave.progress");
const SESSION = Date.now().toString(36);
interface Wave {
  animation: AnimationController;
  generation: number;
  direction: number;
  unsubscribe: () => void;
  timer?: ReturnType<typeof setTimeout>;
}
const waves = new Map<string, Wave>();

function publish(output: string): void {
  const wave = waves.get(output);
  if (!wave) return;
  COMPOSITOR.workspace.transition(output, {
    id: `${SESSION}-${wave.generation}`,
    progress: wave.animation.variable(PROGRESS).peek(),
    direction: wave.direction,
    accent: [203 / 255, 166 / 255, 247 / 255],
  });
}

function waveFor(output: string): Wave {
  let wave = waves.get(output);
  if (!wave) {
    const animation = createAnimationController(() => publish(output));
    wave = { animation, generation: 0, direction: 1,
      unsubscribe: animation.variable(PROGRESS).subscribe(() => publish(output)) };
    waves.set(output, wave);
    animation.set(PROGRESS, 1);
  }
  return wave;
}

export function beginWorkspaceWave(output: string, direction: number): void {
  const wave = waveFor(output);
  clearTimeout(wave.timer);
  wave.generation++;
  wave.direction = direction;
  wave.animation.set(PROGRESS, 0);
  publish(output);
}

export function setWorkspaceWaveProgress(output: string, progress: number): void {
  waveFor(output).animation.set(PROGRESS, Math.max(0, Math.min(1, progress)));
}

export function finishWorkspaceWave(output: string, commit = true, completed?: () => void): void {
  const wave = waveFor(output);
  clearTimeout(wave.timer);
  const to = commit ? 1 : 0;
  const duration = Math.max(1, WORKSPACE_WAVE_DURATION
    * Math.abs(to - wave.animation.variable(PROGRESS).peek()));
  wave.animation.start(PROGRESS, { to, duration });
  wave.timer = setTimeout(() => {
    completed?.();
    wave.animation.set(PROGRESS, 1);
    wave.timer = undefined;
  }, duration + 34);
}

export function stopWorkspaceWave(output: string): void {
  const wave = waves.get(output);
  if (!wave) return;
  clearTimeout(wave.timer);
  wave.animation.set(PROGRESS, 1);
}

export function stopWorkspaceWaves(): void {
  for (const [output, wave] of waves) {
    stopWorkspaceWave(output);
    wave.unsubscribe();
  }
  waves.clear();
}
