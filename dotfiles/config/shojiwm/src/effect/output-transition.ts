import {
  COMPOSITOR, compileOverlayEffect, loadShader, shaderStage, signal, snapshotSource,
} from "shoji_wm";

// Copy both example files into your config's src/effect directory.
const dissolve = loadShader("./src/effect/output-dissolve.frag");

export async function transition(output: string, changeScene: () => void): Promise<void> {
  // Each invocation owns its progress, so interrupted transitions cannot update each other.
  const progress = signal(0);
  const handle = await COMPOSITOR.effect.overlay(output, {
    placement: "top",
    maxDuration: 2_000,
    effect: compileOverlayEffect({
      input: snapshotSource(),
      alpha: "preserve",
      pipeline: [shaderStage(dissolve, { uniforms: { progress } })],
    }),
  });
  let active = true;
  void handle.closed.then(() => { active = false; });
  try {
    changeScene();
    const start = performance.now();
    while (active) {
      const value = Math.min(1, (performance.now() - start) / 450);
      progress.value = value;
      if (value === 1) break;
      await new Promise<void>((resolve) => setTimeout(resolve, 8));
    }
  } finally {
    handle.dispose();
  }
}
