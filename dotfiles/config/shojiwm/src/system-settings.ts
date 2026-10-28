import { COMPOSITOR } from "shoji_wm";
import type { DisplayConfigDraft, InputDeviceConfig, OutputExtendConfigEntry } from "shoji_wm/types";
import { type IpcServer, wakeRust } from "shoji_wm/ipc";

const clone = <T>(value: T): T => JSON.parse(JSON.stringify(value));
const STATE_KEY = "shoji.system-settings.v1";

interface Settings {
  keyboard: Required<Pick<NonNullable<InputDeviceConfig["keyboard"]>, "layout" | "variant" | "options" | "repeatRate" | "repeatDelay">>;
  pointer: Required<Pick<NonNullable<InputDeviceConfig["pointer"]>, "pointerAccel" | "accelProfile" | "motionSpace" | "leftHanded" | "naturalScroll">>;
  touchpad: Required<Pick<NonNullable<InputDeviceConfig["touchpad"]>, "tapToClick" | "naturalScroll" | "disableWhileTyping" | "scrollFactor">>;
  outputs: Record<string, OutputExtendConfigEntry>;
}

function defaults(): Settings {
  return {
    keyboard: { layout: "us,ru", variant: ",ruintl_ru", options: "grp:alt_shift_toggle", repeatRate: 60, repeatDelay: 250 },
    pointer: { pointerAccel: 0, accelProfile: "flat", motionSpace: "logical", leftHanded: false, naturalScroll: false },
    touchpad: { tapToClick: true, naturalScroll: true, disableWhileTyping: true, scrollFactor: 0.3 },
    outputs: {},
  };
}

function object(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("Ожидается объект настроек");
  return value as Record<string, unknown>;
}
function number(value: unknown, min: number, max: number, integer = false): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value < min || value > max || (integer && !Number.isInteger(value)))
    throw new Error(`Значение должно быть ${integer ? "целым " : ""}числом от ${min} до ${max}`);
  return value;
}
function boolean(value: unknown): boolean {
  if (typeof value !== "boolean") throw new Error("Ожидается переключатель true/false");
  return value;
}
function choice<T extends string>(value: unknown, options: readonly T[]): T {
  if (typeof value !== "string" || !options.includes(value as T)) throw new Error("Неподдерживаемое значение настройки");
  return value as T;
}
function inputSettings(value: unknown): Pick<Settings, "keyboard" | "pointer" | "touchpad"> {
  const data = object(value), k = object(data.keyboard), p = object(data.pointer), t = object(data.touchpad);
  const layout = choice(k.layout, ["us,ru", "us"] as const);
  const variant = choice(k.variant, [",ruintl_ru", ",", ""] as const);
  if (layout !== "us,ru" && variant === ",ruintl_ru") throw new Error("Русский вариант требует раскладки us,ru");
  if (layout === "us" && variant !== "") throw new Error("Для одной раскладки нужен один вариант");
  return {
    keyboard: { layout, variant, options: choice(k.options, ["grp:alt_shift_toggle", "grp:ctrl_shift_toggle", "grp:caps_toggle"] as const),
      repeatRate: number(k.repeatRate, 1, 100, true), repeatDelay: number(k.repeatDelay, 150, 1500, true) },
    pointer: { pointerAccel: number(p.pointerAccel, -1, 1), accelProfile: choice(p.accelProfile, ["flat", "adaptive"] as const),
      motionSpace: choice(p.motionSpace, ["logical", "physical"] as const), leftHanded: boolean(p.leftHanded), naturalScroll: boolean(p.naturalScroll) },
    touchpad: { tapToClick: boolean(t.tapToClick), naturalScroll: boolean(t.naturalScroll),
      disableWhileTyping: boolean(t.disableWhileTyping), scrollFactor: number(t.scrollFactor, 0.1, 3) },
  };
}
function outputSettings(value: unknown): Settings["outputs"] {
  const result: Settings["outputs"] = {};
  const entries = Object.entries(object(value));
  if (entries.length > 16) throw new Error("Слишком много мониторов");
  for (const [name, raw] of entries) {
    if (!/^[a-zA-Z0-9_.-]{1,64}$/.test(name) || ["__proto__", "prototype", "constructor"].includes(name)) throw new Error("Некорректное имя монитора");
    const o = object(raw);
    const entry: OutputExtendConfigEntry = { mode: "extend", scale: number(o.scale, 0.75, 3) };
    if (o.resolution === "best") entry.resolution = "best";
    else {
      const mode = object(o.resolution);
      const resolution = { width: number(mode.width, 320, 16384, true), height: number(mode.height, 200, 16384, true),
        refreshRate: number(mode.refreshRate, 1, 1000) };
      const connected = COMPOSITOR.output.get(name);
      if (connected && !connected.availableModes.some(m => m.width === resolution.width && m.height === resolution.height
          && Math.abs(m.refreshRate - resolution.refreshRate) < 0.01)) throw new Error(`Режим недоступен для ${name}`);
      entry.resolution = resolution;
    }
    if (o.position === "auto") entry.position = "auto";
    else {
      const position = object(o.position);
      entry.position = { x: number(position.x, -32768, 32768, true), y: number(position.y, -32768, 32768, true) };
    }
    result[name] = entry;
  }
  return result;
}

export function registerSystemSettings(ipc: IpcServer, fallbackOutput: () => string): () => string {
  let values = defaults();
  let pointer: { x: number; y: number } | null = null;
  const pointerStateKey = `${STATE_KEY}.pointer`;
  let trial: { token: string; deadline: number; previous: Settings["outputs"] } | null = null;
  let expiry: ReturnType<typeof setTimeout> | undefined;
  let trialSequence = 0;
  function outputAtPointer(): string {
    const outputs = COMPOSITOR.output.outputs;
    const point = pointer;
    const underPointer = point && outputs.find(output => output.resolution && output.scale > 0
      && point.x >= output.position.x && point.y >= output.position.y
      && point.x < output.position.x + output.resolution.width / output.scale
      && point.y < output.position.y + output.resolution.height / output.scale);
    if (underPointer) return underPointer.name;
    const fallback = fallbackOutput();
    return outputs.find(output => output.name === fallback)?.name ?? outputs[0]?.name ?? "";
  }
  COMPOSITOR.event.onPointerMove(event => { pointer = { x: event.position.x, y: event.position.y }; });

  COMPOSITOR.input.configure(input => {
    input.global = { keyboard: values.keyboard, pointer: values.pointer,
      touchpad: { ...values.touchpad, scrollMethod: "twoFinger" } };
  });
  COMPOSITOR.output.configure(context => {
    const display: DisplayConfigDraft = {};
    for (const output of context.connected)
      display[output.name] = values.outputs[output.name] ?? { mode: "extend", resolution: "best", position: "auto", scale: 1 };
    return display;
  });

  function snapshot() {
    return { version: 1, values: clone(values), outputs: COMPOSITOR.output.outputs,
      devices: COMPOSITOR.input.devices, trial: trial ? { token: trial.token, deadline: trial.deadline } : null };
  }
  function changed() { ipc.broadcast("settings.changed", snapshot()); wakeRust(); }
  function revert() {
    if (!trial) return;
    values.outputs = trial.previous;
    trial = null;
    if (expiry !== undefined) clearTimeout(expiry);
    expiry = undefined;
    COMPOSITOR.output.reconfigure();
    changed();
  }
  ipc.handle("settings.get", snapshot);
  ipc.handle("settings.target", () => ({ output: outputAtPointer() }));
  ipc.handle("settings.input", raw => {
    if (trial) throw new Error("Сначала подтверди или отмени настройки мониторов");
    values = { ...values, ...inputSettings(raw) };
    COMPOSITOR.input.reconfigure();
    changed();
    return snapshot();
  });
  ipc.handle("settings.displays", raw => {
    if (trial) throw new Error("Предыдущая проверка мониторов ещё не завершена");
    const outputs = outputSettings(object(raw).outputs);
    trial = { token: `${Date.now()}-${++trialSequence}`, deadline: Date.now() + 20000, previous: clone(values.outputs) };
    values.outputs = outputs;
    expiry = setTimeout(revert, 20000);
    COMPOSITOR.output.reconfigure();
    changed();
    return snapshot();
  });
  ipc.handle("settings.confirm", raw => {
    if (!trial || object(raw).token !== trial.token || Date.now() >= trial.deadline)
      throw new Error("Время подтверждения истекло; прежние настройки возвращаются");
    trial = null;
    if (expiry !== undefined) clearTimeout(expiry);
    expiry = undefined;
    changed();
    return snapshot();
  });
  ipc.handle("settings.revert", () => { revert(); return snapshot(); });
  ipc.handle("settings.restore", raw => {
    if (trial) throw new Error("Нельзя восстановить настройки во время проверки мониторов");
    const data = object(raw);
    const next = { ...inputSettings(data), outputs: outputSettings(data.outputs) };
    values = next;
    COMPOSITOR.input.reconfigure();
    COMPOSITOR.output.reconfigure();
    changed();
    return snapshot();
  });
  COMPOSITOR.event.onOutputChange(changed);
  COMPOSITOR.event.onInputDeviceChange(changed);
  COMPOSITOR.onDisable(event => {
    if (expiry !== undefined) clearTimeout(expiry);
    if (trial) values.outputs = trial.previous;
    if (event.isReloading) {
      event.persist(STATE_KEY, clone(values));
      event.persist(pointerStateKey, pointer);
    }
  });
  COMPOSITOR.onEnable(event => {
    if (event.isReloading) pointer = event.restore<{ x: number; y: number } | null>(pointerStateKey) ?? null;
    const saved = event.isReloading ? event.restore<Settings>(STATE_KEY) : null;
    if (!saved) return;
    try {
      values = { ...inputSettings(saved), outputs: outputSettings(saved.outputs) };
      COMPOSITOR.input.reconfigure();
      COMPOSITOR.output.reconfigure();
    } catch (error) { console.warn("System settings restore rejected", String(error)); }
  });
  return outputAtPointer;
}
