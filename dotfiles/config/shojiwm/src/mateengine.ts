import { COMPOSITOR, read, type WaylandWindow, type PointerMoveEvent } from "shoji_wm";
import type { IpcServer } from "shoji_wm/ipc";
import {
  HybridWindowManager,
  isMateEngineWindow,
  WINDOW_STATE_RECT,
  WINDOW_STATE_MINIMIZED,
  WINDOW_STATE_MAXIMIZED,
  WINDOW_STATE_FULLSCREEN,
  WINDOW_STATE_FULLSCREEN_WITH_CHROME,
  WINDOW_STATE_WORKSPACE_VISIBLE,
  WINDOW_STATE_WORKSPACE_OFFSET_Y,
  WINDOW_STATE_WORKSPACE_OPACITY,
} from "./window-manager";

// MateEngine runs through xwayland-satellite: X11 sees neither its real window
// position nor the pointer outside its own surfaces, and satellite ignores
// _NET_MOVERESIZE_WINDOW. The bridge inside MateEngine reads the real geometry
// here and moves the pet through the window manager. Global logical pixels.
//   mateengine.state -> { window, moving, pointer, outputs, surfaces, covered }
//   mateengine.move  { x, y, dragging, anchor? } / mateengine.drag { dragging }
//   mateengine.shell { monitor, dock } (visible output-local ledge from QML)

type Rect = { x: number; y: number; width: number; height: number };

let pointer: { x: number; y: number } | null = null;
let pointerTarget: PointerMoveEvent["target"] = { kind: "none" };
const shellDocks = new Map<string, { rect: Rect | null; visible: boolean; updated: number }>();
let seating: { target: string | null; probe: { x: number; y: number } | null; updated: number } =
  { target: null, probe: null, updated: 0 };

export function petKeepsDockVisible(monitor: string, wm: HybridWindowManager): boolean {
  const pet = petWindow(wm);
  const dock = shellDocks.get(monitor);
  if (!pet || !pet.state[WINDOW_STATE_WORKSPACE_VISIBLE]() || pet.state[WINDOW_STATE_MINIMIZED]() ||
      Date.now() - seating.updated > 1500 || !dock?.rect || Date.now() - dock.updated > 1500) return false;
  if (seating.target === `dock:${monitor}`) return true;
  const output = COMPOSITOR.output.current[monitor];
  if (!output || !seating.probe) return false;
  const x = output.position.x + dock.rect.x;
  const y = output.position.y + dock.rect.y;
  return seating.probe.x >= x - 24 && seating.probe.x <= x + dock.rect.width + 24 &&
    Math.abs(seating.probe.y - y) <= 96;
}

function contains(rect: Rect, point: { x: number; y: number }): boolean {
  return point.x >= rect.x && point.x < rect.x + rect.width &&
    point.y >= rect.y && point.y < rect.y + rect.height;
}

type Surface = { id: string; appId: string; rect: Rect; visualRect?: Rect; z: number;
  self: boolean; dock: boolean; visible: boolean; maximized: boolean; fullscreen: boolean };

function surfaces(wm: HybridWindowManager, zIndex: (window: WaylandWindow) => number): Surface[] {
  const result: Surface[] = [];
  for (const window of wm.listWindows()) {
    const rect = windowRect(window);
    const visible = !window.state[WINDOW_STATE_MINIMIZED]() && window.state[WINDOW_STATE_WORKSPACE_VISIBLE]() &&
      window.state[WINDOW_STATE_WORKSPACE_OPACITY]() > 0;
    const visualRect = { ...rect, y: rect.y + window.state[WINDOW_STATE_WORKSPACE_OFFSET_Y]() };
    result.push({ id: `window:${window.id}`, appId: window.appId() ?? "shoji-window", rect,
      visualRect, visible, z: zIndex(window), self: isMateEngineWindow(window), dock: false,
      maximized: window.state[WINDOW_STATE_MAXIMIZED](),
      fullscreen: window.state[WINDOW_STATE_FULLSCREEN]() || window.state[WINDOW_STATE_FULLSCREEN_WITH_CHROME]() });
  }
  // The upper bar reserves usableArea. Only bottom surfaces are sitting
  // ledges: sitting above the upper bar would put the avatar off screen.
  for (const [name, dock] of shellDocks) {
    if (!dock.rect || Date.now() - dock.updated > 1500) continue;
    const output = COMPOSITOR.output.current[name];
    if (!output) continue;
    const rect = { ...dock.rect, x: output.position.x + dock.rect.x, y: output.position.y + dock.rect.y };
    if (rect.width <= 0 || rect.height <= 0) continue;
    const pet = petWindow(wm);
    result.push({ id: `dock:${name}`, appId: "shoji-dock", rect, z: pet ? zIndex(pet) - 1 : 3_000_000_000,
      visible: dock.visible || petKeepsDockVisible(name, wm),
      self: false, dock: true, maximized: false, fullscreen: false });
  }
  return result.sort((a, b) => a.z - b.z);
}

function petWindow(wm: HybridWindowManager): WaylandWindow | undefined {
  return wm.listWindows().find(isMateEngineWindow);
}

function windowRect(window: WaylandWindow): Rect {
  const rect = window.state[WINDOW_STATE_RECT]();
  return {
    x: read(rect.x),
    y: read(rect.y),
    width: read(rect.width),
    height: read(rect.height),
  };
}

function outputs() {
  const result: (Rect & { name: string; usable: Rect | null })[] = [];
  for (const name of COMPOSITOR.output.list) {
    const output = COMPOSITOR.output.current[name];
    if (!output?.resolution || output.scale <= 0) continue;
    result.push({
      name,
      x: output.position.x,
      y: output.position.y,
      width: output.resolution.width / output.scale,
      height: output.resolution.height / output.scale,
      usable: COMPOSITOR.layer.usableArea(name),
    });
  }
  return result;
}

export function registerMateEngineIpc(
  ipc: IpcServer,
  wm: HybridWindowManager,
  zIndex: (window: WaylandWindow) => number,
): void {
  COMPOSITOR.event.onPointerMoveAsync((event) => {
    pointer = { x: event.position.x, y: event.position.y };
    pointerTarget = event.target;
  });

  ipc.handle("mateengine.state", (params) => {
    const request = params as { seat?: unknown; probe?: { x?: unknown; y?: unknown } | null } | undefined;
    if (request && Object.prototype.hasOwnProperty.call(request, "seat")) {
      const target = request.seat;
      const probe = request.probe;
      if (target !== null && (typeof target !== "string" || !/^(window:0x[0-9a-f]+|dock:.+)$/.test(target)))
        throw new TypeError("invalid seating target");
      if (probe !== null && (!probe || typeof probe.x !== "number" || typeof probe.y !== "number" ||
          !Number.isFinite(probe.x) || !Number.isFinite(probe.y))) throw new TypeError("invalid seating probe");
      seating = { target: target as string | null, probe: probe as { x: number; y: number } | null, updated: Date.now() };
    }
    const window = petWindow(wm);
    const visibleSurfaces = surfaces(wm, zIndex);
    const petZ = window ? zIndex(window) : Infinity;
    let covered = pointer !== null && visibleSurfaces.some(surface => surface.visible && !surface.self && !surface.dock &&
      surface.z > petZ && contains(surface.visualRect ?? surface.rect, pointer!));
    if (pointerTarget.kind === "layer") {
      const layer = COMPOSITOR.layer.current[pointerTarget.layerId];
      const output = layer && COMPOSITOR.output.current[layer.outputName];
      if (pointer && layer && output && (layer.layer === "top" || layer.layer === "overlay")) {
        covered ||= contains({ ...layer.position, x: output.position.x + layer.position.x,
          y: output.position.y + layer.position.y }, pointer);
      }
    }
    return {
      window: window ? windowRect(window) : null,
      windowVisible: !!window && window.state[WINDOW_STATE_WORKSPACE_VISIBLE]() && !window.state[WINDOW_STATE_MINIMIZED](),
      seatingVersion: 4,
      moving: window ? wm.isMovingWindow(window) : false,
      pointer,
      outputs: outputs(),
      surfaces: visibleSurfaces,
      covered,
    };
  });

  ipc.handle("mateengine.move", (params) => {
    const request = params as { x?: unknown; y?: unknown; dragging?: unknown; anchor?: unknown } | undefined;
    const x = request?.x;
    const y = request?.y;
    if (typeof x !== "number" || typeof y !== "number" ||
        !Number.isFinite(x) || !Number.isFinite(y)) {
      throw new TypeError("mateengine.move requires finite x and y");
    }
    const window = petWindow(wm);
    if (window) {
      let monitor: string | undefined;
      const anchor = request?.anchor;
      if (anchor !== undefined && anchor !== null) {
        if (typeof anchor !== "string") throw new TypeError("invalid movement anchor");
        if (anchor.startsWith("dock:")) {
          monitor = anchor.slice(5);
          const dock = shellDocks.get(monitor);
          if (!dock?.rect || Date.now() - dock.updated > 1500) return;
        } else if (anchor.startsWith("output:")) {
          monitor = anchor.slice(7);
        } else if (/^window:0x[0-9a-f]+$/.test(anchor)) {
          const support = wm.listWindows().find(candidate => `window:${candidate.id}` === anchor);
          if (!support || isMateEngineWindow(support) || support.state[WINDOW_STATE_MINIMIZED]() ||
              !support.state[WINDOW_STATE_WORKSPACE_VISIBLE]()) return;
          monitor = wm.getWindowMonitor(support);
        } else throw new TypeError("invalid movement anchor");
        if (!monitor || !COMPOSITOR.output.list.includes(monitor)) return;
      }
      if (typeof request?.dragging === "boolean") wm.setClientWindowDragging(window, request.dragging);
      wm.moveFloatingWindowTo(window, Math.round(x), Math.round(y), monitor);
    }
  });

  ipc.handle("mateengine.drag", (params) => {
    const dragging = (params as { dragging?: unknown } | undefined)?.dragging;
    if (typeof dragging !== "boolean") throw new TypeError("mateengine.drag requires a boolean dragging");
    const window = petWindow(wm);
    if (window) wm.setClientWindowDragging(window, dragging);
  });

  ipc.handle("mateengine.shell", (params) => {
    const request = params as { monitor?: unknown; dock?: Rect | null; visible?: unknown } | undefined;
    if (typeof request?.monitor !== "string" || !COMPOSITOR.output.list.includes(request.monitor)) return;
    const rect = request.dock;
    if (rect !== null && (!rect || ![rect.x, rect.y, rect.width, rect.height].every(Number.isFinite) ||
        rect.width <= 0 || rect.height <= 0)) throw new TypeError("invalid dock geometry");
    shellDocks.set(request.monitor, { rect, visible: request.visible === true, updated: Date.now() });
  });
}
