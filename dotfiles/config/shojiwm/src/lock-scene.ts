import { COMPOSITOR, signal, compileOverlayEffect, backdropSource, snapshotSource,
  shaderStage, loadShader, type OverlayHandle } from "shoji_wm";
import type { IpcServer } from "shoji_wm/ipc";

type Scene = { native: boolean; locked: boolean; backgroundOutputs: string[] };
const shader = loadShader("./src/effect/live-wallpaper-wave.frag");
const DURATION = 680;

export function registerLockSceneIpc(ipc: IpcServer, scene: () => Scene): void {
  let generation = 0;
  let batch: { generation: number; state: string; handles: OverlayHandle[];
    progress: ReturnType<typeof signal<number>>; timer?: ReturnType<typeof setTimeout> } | null = null;

  function cancel() {
    if (!batch) return;
    clearTimeout(batch.timer);
    for (const handle of batch.handles) handle.dispose();
    batch = null;
  }
  function current(raw: unknown) {
    const id = (raw as { generation?: unknown } | null)?.generation;
    if (!batch || id !== batch.generation) throw new Error("Unlock transition expired");
    return batch;
  }
  ipc.handle("lock.scene", scene);
  ipc.handle("lock.release.prepare", () => {
    cancel();
    const backend = scene();
    if (!backend.native || !backend.locked) throw new Error("Native lock-scene support is unavailable");
    const next = { generation: ++generation, state: "preparing", handles: [] as OverlayHandle[], progress: signal(0),
      timer: undefined as ReturnType<typeof setTimeout> | undefined };
    batch = next;
    const outputs = COMPOSITOR.output.outputs.filter(output => output.enabled && output.resolution);
    const left = Math.min(...outputs.map(output => output.position.x));
    const top = Math.min(...outputs.map(output => output.position.y));
    const width = Math.max(...outputs.map(output => output.position.x + output.resolution!.width / output.scale)) - left;
    const height = Math.max(...outputs.map(output => output.position.y + output.resolution!.height / output.scale)) - top;
    // Detached: awaiting capture inside an IPC/render callback deadlocks.
    void Promise.allSettled(outputs.map(output => COMPOSITOR.effect.overlay(output, {
      placement: "unlock", maxDuration: 2500,
      effect: compileOverlayEffect({ input: backdropSource(), alpha: "opaque", capturePadding: 0,
        invalidate: { kind: "always" }, pipeline: [shaderStage(shader, {
          textures: { previous: snapshotSource() }, uniforms: {
            progress: next.progress, viewportSize: [width, height],
            outputOrigin: [output.position.x - left, output.position.y - top],
            outputSize: [output.resolution!.width / output.scale, output.resolution!.height / output.scale],
            accent: [0.796, 0.651, 0.969, 1], warm: [0.961, 0.761, 0.906, 1],
            backgroundColor: [0.118, 0.118, 0.180, 1],
          },
        })],
      }),
    }))).then(results => {
      const handles = results.flatMap(result => result.status === "fulfilled" ? [result.value] : []);
      if (batch !== next) { for (const handle of handles) handle.dispose(); return; }
      next.handles = handles;
      next.state = handles.length ? "ready" : "failed";
      for (const handle of handles) void handle.closed.then(() => {
        if (batch === next && next.state !== "playing") next.state = "failed";
      });
    });
    next.timer = setTimeout(cancel, 2300);
    return { generation: next.generation };
  });
  ipc.handle("lock.release.status", raw => {
    const next = current(raw);
    return { generation: next.generation, state: next.state };
  });
  ipc.handle("lock.release.start", raw => {
    const next = current(raw);
    if (next.state !== "ready" || scene().locked) throw new Error("Session has not unlocked yet");
    next.state = "playing";
    clearTimeout(next.timer);
    const start = Date.now();
    function tick() {
      if (batch !== next) return;
      const progress = Math.min(1, (Date.now() - start) / DURATION);
      next.progress.set(progress);
      if (progress >= 1) { cancel(); return; }
      next.timer = setTimeout(tick, 16);
    }
    tick();
    return { started: true };
  });
  ipc.handle("lock.release.cancel", () => { cancel(); return true; });
  COMPOSITOR.onDisable(cancel);
}
