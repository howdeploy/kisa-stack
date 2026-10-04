import {
  COMPOSITOR, backdropSource, compileOverlayEffect, loadShader, shaderStage, signal,
  type OverlayHandle, type WaylandLayer,
} from "shoji_wm";
import type { IpcServer } from "shoji_wm/ipc";
import { aquariumOverlayEffect, setAquariumEnabled } from "./aquarium";

const SHADER = loadShader("./src/effect/retro-screen.frag");
const active = new Map<string, { id: string; handle?: OverlayHandle }>();
const enabled = signal(0);
const items = [
  { id: "none", title: "Без эффекта", description: "Обычный рабочий стол",
    details: "Исходное изображение без постобработки" },
  { id: "retro", title: "CRT Pixel", description: "Пиксели · полосы · выпуклый экран",
    details: "768 строк, исходные цвета, мягкое свечение и лёгкая выпуклость CRT" },
  { id: "aquarium", title: "Аквариум", description: "Толща воды · стекло · объёмные пузырьки",
    details: "Оптика стеклянного резервуара, расфокус по глубине и объёмное освещение" },
];
let selected = "none";
let preview: string | null = null;
let previewSession: string | null = null;
const pickerSessions = new Map<string, string | null>();
let error = "";
let notify = () => {};

function currentId(): string { return preview ?? selected; }
function wanted(): boolean { return currentId() !== "none"; }
function state() { return { items, selected, preview: currentId(), active: currentId(), previewing: preview !== null, error }; }

function sync(): void {
  const id = currentId();
  enabled.value = id === "retro" ? 1 : 0;
  setAquariumEnabled(id === "aquarium");
  // Pending openings finish before the next shader can occupy the same slot.
  for (const [output, entry] of active) {
    if (entry.id !== id && entry.handle) {
      active.delete(output);
      entry.handle.dispose();
    }
  }
  if (!wanted()) return;
  for (const output of COMPOSITOR.output.list) {
    if (active.has(output)) continue;
    void enableScreenShader(output, id).catch(failure => {
      error = "Не удалось показать эффект: " + String(failure);
      console.error("Screen shader overlay failed:", output, failure);
      notify();
    });
  }
}

async function enableScreenShader(output: string, id: string): Promise<void> {
  const entry: { id: string; handle?: OverlayHandle } = { id };
  active.set(output, entry);
  try {
    const handle = await COMPOSITOR.effect.overlay(output, {
      persistent: true,
      placement: "top",
      effect: id === "aquarium" ? aquariumOverlayEffect(output) : compileOverlayEffect({
        input: backdropSource(),
        alpha: "preserve",
        pipeline: [shaderStage(SHADER, { uniforms: { rows: 768, enabled } })],
      }),
    });
    if (active.get(output) !== entry || currentId() !== id || !COMPOSITOR.output.list.includes(output)) {
      if (active.get(output) === entry) active.delete(output);
      handle.dispose();
      sync();
      return;
    }
    entry.handle = handle;
    void handle.closed.then(() => {
      if (active.get(output) !== entry) return;
      active.delete(output);
      // Another top overlay or native cleanup ended this effect; do not fight it.
      if (wanted()) stopRetroScreen();
    });
  } catch (error) {
    if (active.get(output) === entry) {
      active.delete(output);
      if (currentId() === id) throw error;
      sync();
    }
  }
}

export function stopRetroScreen(): void {
  selected = "none";
  preview = null;
  previewSession = null;
  sync();
  notify();
}

export function cancelScreenShaderPreview(): void {
  if (preview === null) return;
  preview = null;
  previewSession = null;
  error = "";
  sync();
  notify();
}

export function screenShaderPickerMapped(layer: WaylandLayer): void {
  if (layer.namespace() === "shoji-shader-picker") pickerSessions.set(layer.id, previewSession);
}

export function screenShaderPickerClosed(layer: WaylandLayer): void {
  if (layer.namespace() !== "shoji-shader-picker") return;
  const session = pickerSessions.get(layer.id);
  pickerSessions.delete(layer.id);
  // A delayed destroy from the previous opening must not cancel the new preview.
  if (session && session === previewSession) cancelScreenShaderPreview();
}

export function registerScreenShaderIpc(ipc: IpcServer,
  previewScene: (output: string) => { origin: number[]; extent: number[]; windows: number[][] } | null): void {
  notify = () => ipc.broadcast("screen-shaders.changed", state());
  ipc.handle("screen-shaders.get", params => {
    const output = (params as { output?: unknown } | undefined)?.output;
    return { ...state(), scene: typeof output === "string" ? previewScene(output) : null };
  });
  ipc.handle("screen-shaders.preview", params => {
    const request = params as { id?: string; session?: string } | undefined;
    const id = request?.id;
    if (!items.some(item => item.id === id)) throw new TypeError("Unknown screen shader");
    if (typeof request?.session !== "string" || !request.session) throw new TypeError("Missing picker session");
    previewSession = request.session;
    for (const layer of Object.values(COMPOSITOR.layer.current)) {
      if (layer.namespace === "shoji-shader-picker" && !pickerSessions.get(layer.id))
        pickerSessions.set(layer.id, previewSession);
    }
    preview = id!;
    error = "";
    sync();
    notify();
    return state();
  });
  ipc.handle("screen-shaders.apply", () => {
    selected = preview ?? selected;
    preview = null;
    previewSession = null;
    sync();
    notify();
    return state();
  });
  ipc.handle("screen-shaders.cancel", () => { cancelScreenShaderPreview(); return state(); });
}
