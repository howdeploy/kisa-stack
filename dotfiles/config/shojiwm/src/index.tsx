import {
  AppIcon,
  Box,
  Button,
  ClientWindow,
  Image,
  ShaderEffect,
  Label,
  COMPOSITOR,
  WindowBorder,
  backdropSource,
  compileEffect,
  compileLayerEffect,
  dualKawaseBlur,
  type SSDStyle,
  type WaylandWindow,
  computed,
  useState,
  shaderStage,
  loadShader,
  layerSource,
  ManagedWindow,
  read,
  type DisplayConfigDraft,
  compilePopupEffect,
  popupSource,
} from "shoji_wm";
import type { CompositionRenderable, ManagedWindowRect } from "shoji_wm/types";
import { createIpcServer } from "shoji_wm/ipc";
import {
  HybridWindowManager,
  isFloatingUtilityWindow,
  PERSISTENT_WORKSPACE_COUNT,
  TITLEBAR_HEIGHT,
  WINDOW_BORDER_PX,
  WINDOW_STATE_FULLSCREEN,
  WINDOW_STATE_FULLSCREEN_WITH_CHROME,
  WINDOW_STATE_MINIMIZED,
  WINDOW_STATE_MINIMIZE_VISUAL_IDLE,
  WINDOW_STATE_TILE_DRAGGING,
  WINDOW_STATE_TILE_REORDERING,
  WINDOW_STATE_TILED,
  WINDOW_STATE_WORKSPACE_TILED,
  WINDOW_STATE_VISIBLE_OUTPUTS,
  WINDOW_STATE_RECT,
  WINDOW_STATE_WORKSPACE_VISIBLE,
  WINDOW_STATE_WORKSPACE_OFFSET_Y,
  WINDOW_STATE_WORKSPACE_OPACITY,
} from "./window-manager";
import { ISLAND_GLASS } from "./effect/island-glass";
import { windowWaveEffect, windowWaveIsHiding } from "./effect/window-wave";
import { windowJellyEffect } from "./effect/window-jelly";
import { dragJellyEffect } from "./effect/window-drag-jelly";
import { monitorPortalEffect, stopMonitorPortals } from "./effect/monitor-portal";
import { layoutMeltEffect, stopLayoutMelts } from "./effect/layout-melt";
import { stopWorkspaceWaves } from "./effect/workspace-wave";

const home = COMPOSITOR.env.get("HOME")!;
const configHome = COMPOSITOR.env.get("XDG_CONFIG_HOME") || `${home}/.config`;
const scripts = `${configHome}/shojiwm/scripts`;

COMPOSITOR.effect.window = (window) => windowWaveEffect(window)
  ?? dragJellyEffect(window)
  ?? windowJellyEffect(window);

COMPOSITOR.env.apply({
  QT_QPA_PLATFORM: "wayland;xcb",
  XDG_MENU_PREFIX: "plasma-",
  ELECTRON_OZONE_PLATFORM_HINT: "wayland",
});
COMPOSITOR.env.publish();

COMPOSITOR.cursor.configure({
  theme: COMPOSITOR.env.get("XCURSOR_THEME") || "Adwaita",
  size: 24,
});

COMPOSITOR.window.decoration.configure((_window, context) => {
  return { mode: context.clientPreference ?? "server" };
});

const HYBRID_WINDOW_MANAGER = new HybridWindowManager(naturalRootRect);
const HOT_RELOAD_WINDOW_MANAGER_STATE = "config.hybrid-window-manager";
const FULLSCREEN_Z_INDEX = 2_000_000_000;
const FLOATING_WINDOW_Z_INDEX_BASE = 1_500_000_000;
const WINDOW_STACK_Z_INDEX_RANGE = 100_000_000;
const FOCUSED_TILED_WINDOW_Z_INDEX = 1_000_000_000;
const REORDERING_TILED_WINDOW_Z_INDEX = -2_000_000_000;

COMPOSITOR.onDisable((event) => {
  stopLayoutMelts();
  stopMonitorPortals();
  stopWorkspaceWaves();
  if (event.isReloading) {
    const snapshot = HYBRID_WINDOW_MANAGER.snapshot();
    event.persist(HOT_RELOAD_WINDOW_MANAGER_STATE, snapshot);
  }
  HYBRID_WINDOW_MANAGER.dispose();
});

COMPOSITOR.onEnable((event) => {
  if (event.isReloading) {
    const snapshot = event.restore<
      ReturnType<typeof HYBRID_WINDOW_MANAGER.snapshot>
    >(HOT_RELOAD_WINDOW_MANAGER_STATE);
    if (snapshot) {
      HYBRID_WINDOW_MANAGER.restore(snapshot);
    }
  }
});

// ---------------------------------------------------------------------------
// External IPC: expose the workspace layout to clients such as the bar.
//   workspaces.get           -> WorkspacesView                     (request/response)
//   workspaces.switch        { direction: -1 | 1 }                 (command)
//   workspaces.activate      { monitor: string, index: number }    (command)
//   workspaces.toggleTiling  { monitor?: string }                  (command)
//   workspaces.changed       -> WorkspacesView                     (broadcast)
//   windows.activate         { windowId: string }                  (command)
//   dock.proximity           { monitor: string, inside: bool }    (broadcast)
// ---------------------------------------------------------------------------
const WORKSPACE_IPC = createIpcServer();
let lastWorkspacesJson = "";
let workspaceBroadcastQueued = false;

function broadcastWorkspaces() {
  const view = HYBRID_WINDOW_MANAGER.viewForIpc();
  const json = JSON.stringify(view);
  if (json === lastWorkspacesJson) {
    return;
  }
  lastWorkspacesJson = json;
  WORKSPACE_IPC.broadcast("workspaces.changed", view);
}

function reconfigureProtocolWorkspaces() {
  COMPOSITOR.workspace.reconfigure();
}

// Coalesce many state mutations within one tick into a single diffed broadcast.
function scheduleWorkspaceBroadcast() {
  // Protocol state must be staged before the current runtime response is
  // written; otherwise key bindings/Waybar activations only reach external
  // bars on a later, unrelated runtime request.
  reconfigureProtocolWorkspaces();
  if (workspaceBroadcastQueued) {
    return;
  }
  workspaceBroadcastQueued = true;
  void Promise.resolve().then(() => {
    workspaceBroadcastQueued = false;
    broadcastWorkspaces();
  });
}

COMPOSITOR.workspace.configure(() => {
  const view = HYBRID_WINDOW_MANAGER.viewForIpc();
  return {
    groups: view.monitors.map((monitor) => ({
      id: monitor.name,
      outputs: [monitor.name],
      workspaces: monitor.workspaces.map((workspace) => ({
        id: `${monitor.name}:${workspace.index}`,
        name: String(workspace.index),
        coordinates: [Math.max(0, workspace.index - 1)],
        active: workspace.active,
        hidden:
          workspace.index > PERSISTENT_WORKSPACE_COUNT &&
          !workspace.active && workspace.windowCount === 0,
      })),
    })),
  };
});

COMPOSITOR.workspace.event.onActivate((event) => {
  const [monitor, rawIndex] = event.workspaceId.split(":");
  const index = Number(rawIndex);
  if (!monitor || !Number.isInteger(index) || index < 1) {
    return;
  }
  HYBRID_WINDOW_MANAGER.activate(monitor, index);
  scheduleWorkspaceBroadcast();
});

WORKSPACE_IPC.handle("workspaces.get", () =>
  HYBRID_WINDOW_MANAGER.viewForIpc(),
);
WORKSPACE_IPC.handle("workspaces.switch", (params) => {
  const direction = (params as { direction?: number } | undefined)?.direction;
  HYBRID_WINDOW_MANAGER.switchWorkspace(direction === -1 ? -1 : 1);
  scheduleWorkspaceBroadcast();
});
WORKSPACE_IPC.handle("workspaces.activate", (params) => {
  const request = params as { monitor?: string; index?: number } | undefined;
  if (request?.monitor && typeof request.index === "number") {
    HYBRID_WINDOW_MANAGER.activate(request.monitor, request.index);
    scheduleWorkspaceBroadcast();
  }
});
WORKSPACE_IPC.handle("workspaces.toggleTiling", (params) => {
  const monitor = (params as { monitor?: string } | undefined)?.monitor;
  if (monitor) {
    HYBRID_WINDOW_MANAGER.toggleWorkspaceTilingForMonitor(monitor);
  } else {
    HYBRID_WINDOW_MANAGER.toggleCurrentWorkspaceTiling();
  }
  scheduleWorkspaceBroadcast();
});
WORKSPACE_IPC.handle("windows.activate", (params) => {
  const windowId = (params as { windowId?: string } | undefined)?.windowId;
  if (typeof windowId === "string") {
    HYBRID_WINDOW_MANAGER.activateWindowById(windowId);
    scheduleWorkspaceBroadcast();
  }
});

// ---------------------------------------------------------------------------
// Dock proximity: watch the pointer and broadcast enter/leave for the bottom
// strip of each monitor. The bar uses this in place of a layer-shell trigger
// surface (which would otherwise capture clicks meant for the windows below).
// ---------------------------------------------------------------------------
// Two thresholds with hysteresis:
//   - SHOW: pointer must be in the bottom 10px to trigger reveal
//   - HIDE: once visible, pointer must leave the bottom 120px to dismiss
// This gives a precise "reach for the dock" trigger while keeping the dock
// stable once the user is interacting with it (so brushing the cursor a few
// dozen pixels above the dock body does not flicker it away).
const DOCK_SHOW_ZONE_PX = 10;
const DOCK_HIDE_ZONE_PX = 120;
const dockProximityByMonitor = new Map<string, boolean>();

WORKSPACE_IPC.handle("dock.get", (params) => {
  const request = params as { monitor?: string; width?: number; height?: number } | undefined;
  if (!request || typeof request.monitor !== "string" ||
      typeof request.width !== "number" || !Number.isFinite(request.width) || request.width <= 0 ||
      typeof request.height !== "number" || !Number.isFinite(request.height) || request.height <= 0) {
    throw new Error("dock.get requires a monitor and positive finite dimensions");
  }
  return {
    occluded: HYBRID_WINDOW_MANAGER.dockOccluded(request.monitor, request.width, request.height),
    nearby: dockProximityByMonitor.get(request.monitor) === true,
    chromeFullscreen: HYBRID_WINDOW_MANAGER.hasChromeFullscreen(request.monitor),
  };
});

function pointerInBottomStrip(
  monitor: string,
  pointerX: number,
  pointerY: number,
  stripPx: number,
): boolean {
  const output = COMPOSITOR.output.get(monitor);
  if (!output || !output.resolution) {
    return false;
  }
  const width = output.resolution.width / output.scale;
  const height = output.resolution.height / output.scale;
  const left = output.position.x;
  const top = output.position.y;
  const right = left + width;
  const bottom = top + height;
  return (
    pointerX >= left &&
    pointerX < right &&
    pointerY >= bottom - stripPx &&
    pointerY < bottom
  );
}

function nextDockProximity(
  monitor: string,
  pointerX: number,
  pointerY: number,
  onTrackedMonitor: boolean,
): boolean {
  if (!onTrackedMonitor) return false;
  const wasInside = dockProximityByMonitor.get(monitor) === true;
  // While outside, only the narrow show-zone counts (10px).
  // While inside, the wide hide-zone keeps it open (120px).
  return pointerInBottomStrip(
    monitor,
    pointerX,
    pointerY,
    wasInside ? DOCK_HIDE_ZONE_PX : DOCK_SHOW_ZONE_PX,
  );
}

function updateDockProximity(monitor: string, inside: boolean) {
  if (dockProximityByMonitor.get(monitor) === inside) {
    return;
  }
  dockProximityByMonitor.set(monitor, inside);
  WORKSPACE_IPC.broadcast("dock.proximity", { monitor, inside });
}

// Snap-zone preview: broadcast the active snap rect (floating edge zones, or the
// opened tiling slot) to the bar, which renders the rounded preview overlay.
//   snap.preview  { monitor, rect: {x,y,w,h} | null, kind: "floating"|"tiling" }
let lastSnapJson = "";
HYBRID_WINDOW_MANAGER.setSnapPreviewBroadcaster((preview) => {
  const json = JSON.stringify(preview);
  if (json === lastSnapJson) {
    return;
  }
  lastSnapJson = json;
  WORKSPACE_IPC.broadcast("snap.preview", preview);
});

HYBRID_WINDOW_MANAGER.setWorkspaceChangeBroadcaster(() => {
  scheduleWorkspaceBroadcast();
});

COMPOSITOR.onDisable(() => {
  WORKSPACE_IPC.close();
});

// A portal activated before login keeps its old environment and backend list.
COMPOSITOR.process.once("session-portals", {
  command: ["bash", `${scripts}/session-portals`],
  runPolicy: "once-per-session",
});

COMPOSITOR.process.once("ghostty", {
  command: ["ghostty", "--gtk-single-instance=false"],
  cwd: home,
  runPolicy: "once-per-session",
});

COMPOSITOR.process.once("polkit-agent", {
  command: ["/usr/lib/polkit-kde-authentication-agent-1"],
  runPolicy: "once-per-session",
});

COMPOSITOR.process.service("dock", {
  command: ["bash", `${scripts}/start-shell`],
  restart: "on-failure",
});

COMPOSITOR.key.bind("screenshot-region", "Super+Shift+S", () => {
  COMPOSITOR.process.spawn({
    command: [`${scripts}/screenshot-region`],
  });
});

COMPOSITOR.key.bind("terminal", "Super+Return", () => {
  COMPOSITOR.process.spawn({ command: ["ghostty", "--gtk-single-instance=false"], cwd: home });
});

COMPOSITOR.key.bind("dolphin", "Super+E", () => {
  COMPOSITOR.process.spawn({ command: "dolphin" });
});

COMPOSITOR.key.bind("mute", "XF86AudioMute", () => {
  COMPOSITOR.process.spawn({ command: "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" });
});
COMPOSITOR.key.bind("volume-up", "XF86AudioRaiseVolume", () => {
  COMPOSITOR.process.spawn({ command: "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+" });
});
COMPOSITOR.key.bind("volume-down", "XF86AudioLowerVolume", () => {
  COMPOSITOR.process.spawn({ command: "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-" });
});

function toggleLauncher() {
  COMPOSITOR.process.spawn({
    command: [`${scripts}/launcher`],
  });
}
COMPOSITOR.key.bind("launcher", "Super+Space", toggleLauncher);
COMPOSITOR.key.bind("wallpaper-picker", "Super+W", () => {
  COMPOSITOR.process.spawn({ command: [
    "quickshell", "ipc", "--path", `${configHome}/shoji-shell`,
    "call", "wallpaper", "toggle", HYBRID_WINDOW_MANAGER.getCurrentMonitorName(),
  ] });
});
COMPOSITOR.key.bind("toggle-tiling-mode", "Super+S", () => {
  HYBRID_WINDOW_MANAGER.toggleCurrentWorkspaceTiling();
  scheduleWorkspaceBroadcast();
});
COMPOSITOR.key.bind("close-focused-window", "Super+Q", () => {
  HYBRID_WINDOW_MANAGER.closeFocusedWindow();
});
COMPOSITOR.key.bind("toggle-focused-window-maximize", "Super+M", () => {
  HYBRID_WINDOW_MANAGER.toggleFocusedWindowMaximize();
});
COMPOSITOR.key.bind("toggle-focused-window-fullscreen", "Super+F", () => {
  HYBRID_WINDOW_MANAGER.toggleFocusedWindowFullscreen();
});
COMPOSITOR.key.bind("tile-focus-left-quick", "Super+Left", () => {
  HYBRID_WINDOW_MANAGER.focusTile(-1);
});
COMPOSITOR.key.bind("tile-focus-right-quick", "Super+Right", () => {
  HYBRID_WINDOW_MANAGER.focusTile(1);
});
COMPOSITOR.key.bind("tile-focus-left", "Super+Ctrl+Left", () => {
  HYBRID_WINDOW_MANAGER.focusTile(-1);
});
COMPOSITOR.key.bind("tile-focus-right", "Super+Ctrl+Right", () => {
  HYBRID_WINDOW_MANAGER.focusTile(1);
});
COMPOSITOR.key.bind("tile-move-left", "Super+Shift+Left", () => {
  HYBRID_WINDOW_MANAGER.moveFocusedTile(-1);
  scheduleWorkspaceBroadcast();
});
COMPOSITOR.key.bind("tile-move-right", "Super+Shift+Right", () => {
  HYBRID_WINDOW_MANAGER.moveFocusedTile(1);
  scheduleWorkspaceBroadcast();
});
COMPOSITOR.key.bind("window-move-workspace-prev", "Super+Shift+Up", () => {
  HYBRID_WINDOW_MANAGER.moveFocusedWindowToWorkspace(-1);
  scheduleWorkspaceBroadcast();
});
COMPOSITOR.key.bind("window-move-workspace-next", "Super+Shift+Down", () => {
  HYBRID_WINDOW_MANAGER.moveFocusedWindowToWorkspace(1);
  scheduleWorkspaceBroadcast();
});
COMPOSITOR.key.bind("workspace-prev", "Super+Ctrl+Up", () => {
  HYBRID_WINDOW_MANAGER.switchWorkspace(-1);
  scheduleWorkspaceBroadcast();
});
COMPOSITOR.key.bind("workspace-next", "Super+Ctrl+Down", () => {
  HYBRID_WINDOW_MANAGER.switchWorkspace(1);
  scheduleWorkspaceBroadcast();
});

for (let index = 1; index <= PERSISTENT_WORKSPACE_COUNT; index++) {
  COMPOSITOR.key.bind(`workspace-${index}`, `Alt+${index}`, () => {
    HYBRID_WINDOW_MANAGER.activate(
      HYBRID_WINDOW_MANAGER.getCurrentMonitorName(),
      index,
    );
    scheduleWorkspaceBroadcast();
  });
}

let fpsCounter = false;
COMPOSITOR.key.bind("fps", "Super+Shift+F", () => {
  fpsCounter = !fpsCounter;
  COMPOSITOR.debug.fpsCounter = fpsCounter;
});

let profileEnabled = false;
COMPOSITOR.key.bind("profile", "Super+Shift+T", () => {
  profileEnabled = !profileEnabled;
  COMPOSITOR.debug.enableProfile(profileEnabled);
});

COMPOSITOR.output.configure((context) => {
  const display: DisplayConfigDraft = {};

  for (const output of context.connected) {
    display[output.name] = {
      mode: "extend",
      resolution: "best",
      position: "auto",
      scale: 1,
    };
  }

  return display;
});

COMPOSITOR.input.configure((input, _context) => {
  input.global = {
    touchpad: {
      tapToClick: true,
      naturalScroll: true,
      scrollMethod: "twoFinger",
      disableWhileTyping: true,
      scrollFactor: 0.3,
    },
    pointer: {
      pointerAccel: 0.0,
      accelProfile: "flat",
      motionSpace: "logical",
    },
    keyboard: {
      layout: "us,ru",
      variant: ",ruintl_ru",
      options: "grp:alt_shift_toggle",
      repeatRate: 60,
      repeatDelay: 250,
    },
  };

});

HYBRID_WINDOW_MANAGER.configureWorkspaceGestureSpeed({
  workspaceScrollFactor: 1.5,
  workspaceScrollKineticFactor: 1,
  workspaceSwitchFactor: 1,
  workspaceSwitchVelocityFactor: 1,
  // At or below this scroll speed (logical px/s) the workspace scroll
  // catches on tile snap positions (fully-on-screen edges; center for
  // maximized tiles). 0 disables snapping.
  workspaceScrollSnapMaxVelocity: 600,
  // Finger travel (logical px) needed to break out of a caught position.
  workspaceScrollSnapBreakoutPx: 48,
});

COMPOSITOR.effect.background_effect = compileEffect({
  input: backdropSource(),
  capturePadding: 24,
  invalidate: { kind: "on-source-damage-box", damagePadding: 8 },
  pipeline: [dualKawaseBlur({ radius: 4, passes: 2 })],
});

const LAYER_BLUR_MASK = compileLayerEffect({
  input: backdropSource(),
  capturePadding: 24,
  invalidate: { kind: "on-source-damage-box", damagePadding: 8 },
  // The mask stage intentionally outputs transparency (the blur is clipped
  // to the layer's own alpha), so the pipeline's alpha must survive the
  // finish/display passes instead of being forced opaque.
  alpha: "preserve",
  pipeline: [
    dualKawaseBlur({ radius: 4, passes: 2 }),
    shaderStage(loadShader("./src/effect/layer-blur-mask.frag"), {
      textures: {
        layer_mask: layerSource(),
      },
      uniforms: {
        opacity_threshold: 0.25,
        mask_feather: 0.04,
      },
    }),
  ],
});

COMPOSITOR.effect.layer = (layer) => {
  const namespace = layer.namespace();
  // Both the LiquidIsland experiment and shoji-bar-3 draw only a translucent
  // silhouette and let the compositor recover the shape from its alpha.
  if (namespace === "liquid-island-qs" || namespace === "shoji-bar-3") {
    return { behind: ISLAND_GLASS };
  }
  if (namespace === "shoji-layout-melt") {
    const output = layer.outputName();
    const transition = layoutMeltEffect(layer, () => {
      const windows: { id: string; rect: ManagedWindowRect }[] = [];
      for (const window of HYBRID_WINDOW_MANAGER.listWindows()) {
        if (window.state[WINDOW_STATE_MINIMIZED]()) continue;
        if (!window.state[WINDOW_STATE_WORKSPACE_VISIBLE]()) continue;
        const outputs = window.state[WINDOW_STATE_VISIBLE_OUTPUTS]();
        if (outputs && !outputs.includes(output)) continue;
        windows.push({ id: window.id, rect: window.state[WINDOW_STATE_RECT]() });
      }
      return windows;
    });
    return { ...transition, inFront: monitorPortalEffect(layer) };
  }
  if (namespace === "shoji-shell" || namespace === "no_blur" || namespace === "shoji-water") {
    return {};
  }

  return {
    behind: LAYER_BLUR_MASK,
  };
};

const POPUP_BLUR = compilePopupEffect({
  input: backdropSource(),
  capturePadding: 4 * 2 * 2 + 24 + 32,
  invalidate: { kind: "on-source-damage-box", damagePadding: 8 },
  // The mask stage intentionally outputs transparency (the blur is clipped
  // to the layer's own alpha), so the pipeline's alpha must survive the
  // finish/display passes instead of being forced opaque.
  alpha: "preserve",
  pipeline: [
    dualKawaseBlur({ radius: 4, passes: 2 }),
    shaderStage(loadShader("./src/effect/layer-blur-mask.frag"), {
      textures: {
        layer_mask: popupSource(),
      },
      uniforms: {
        opacity_threshold: 0.25,
        mask_feather: 0.04,
      },
    }),
  ],
});

COMPOSITOR.effect.popup = (popup) => {
  if (popup.parentKind === "window") {
    return {};
  }

  return {
    behind: POPUP_BLUR,
  };
};

// Chromium-family clients repaint their CSD shadow margins as transparent
// black — while still declaring the whole surface opaque — the moment they
// send set_minimized, assuming the surface will never be shown again. Honoring
// that declaration skips blending and paints the margins as a solid black
// ring during the minimize animation.
const isChromiumFamily = (appId: string): boolean => {
  const id = appId.toLowerCase();
  return (
    id.includes("chrome") || id.includes("chromium") || id.includes("electron")
  );
};

// GTK3 tooltips (waybar) declare their whole rect opaque despite transparent
// rounded corners, which paints the corners as a solid fill and culls the
// behind-blur. Ignore the declaration for layer-shell popups.
COMPOSITOR.rendering.surfacePolicy = (surface) => {
  if (surface.kind === "popup" && surface.parentKind === "layer") {
    return { opaqueRegion: "ignore" };
  }
  if (surface.kind === "toplevel") {
    const window = surface.window;
    // Minimized only: the restore animation fades in from opacity 0, so the
    // few frames where a stale black-margin buffer could still be on screen
    // after unminimize are effectively invisible.
    if (
      isChromiumFamily(window.appId() ?? "") &&
      (window.state[WINDOW_STATE_MINIMIZED]() ||
        window.state[WINDOW_STATE_MINIMIZE_VISUAL_IDLE]())
    ) {
      return { opaqueRegion: "ignore" };
    }
  }
  return null;
};

COMPOSITOR.event.onOpen((window) => {
  HYBRID_WINDOW_MANAGER.onOpen(window);
});

COMPOSITOR.event.onInitialConfigure((window) => {
  HYBRID_WINDOW_MANAGER.onInitialConfigure(window);
});

COMPOSITOR.event.onFirstCommit((window) => {
  HYBRID_WINDOW_MANAGER.onFirstCommit(window);
  scheduleWorkspaceBroadcast();
});

COMPOSITOR.event.onStartClose((window) => {
  HYBRID_WINDOW_MANAGER.onStartClose(window);
  scheduleWorkspaceBroadcast();
});

COMPOSITOR.event.onClose((window) => {
  HYBRID_WINDOW_MANAGER.onClose(window);
  scheduleWorkspaceBroadcast();
});

COMPOSITOR.event.onFocus((window, focused) => {
  HYBRID_WINDOW_MANAGER.onFocus(window, focused);
  if (focused) {
    HYBRID_WINDOW_MANAGER.recordFocus(window.id);
    scheduleWorkspaceBroadcast();
  }
});

// Hover focus and dock proximity must not block the compositor's input loop.
COMPOSITOR.event.onPointerMoveAsync((event) => {
  HYBRID_WINDOW_MANAGER.onPointerMove(event);

  // Dock proximity: update only the monitor the pointer is currently on,
  // and emit "leave" for other monitors that were previously inside. The
  // narrow/wide threshold is hysteretic per current state.
  const pointerX = event.position.x;
  const pointerY = event.position.y;
  for (const monitor of COMPOSITOR.output.list) {
    const inside = nextDockProximity(
      monitor,
      pointerX,
      pointerY,
      monitor === event.outputName,
    );
    updateDockProximity(monitor, inside);
  }
});

COMPOSITOR.event.onGestureSwipe((event) => {
  HYBRID_WINDOW_MANAGER.onGestureSwipe(event);
  scheduleWorkspaceBroadcast();
});

COMPOSITOR.event.onOutputChange((event) => {
  HYBRID_WINDOW_MANAGER.onOutputChange(event);
  scheduleWorkspaceBroadcast();
});

COMPOSITOR.event.onCreateLayer(() => {
  HYBRID_WINDOW_MANAGER.refreshUsableAreaLayouts();
});

COMPOSITOR.event.onUpdateLayer(() => {
  HYBRID_WINDOW_MANAGER.refreshUsableAreaLayouts();
});

COMPOSITOR.event.onDestroyLayer(() => {
  HYBRID_WINDOW_MANAGER.refreshUsableAreaLayouts();
});

COMPOSITOR.event.onWindowResize((event) => {
  HYBRID_WINDOW_MANAGER.onWindowResize(event);
});

COMPOSITOR.pointer.bindWindowMoveModifier("Super");
COMPOSITOR.pointer.bindWindowResizeModifier("Super");

COMPOSITOR.event.onWindowMove((event) => {
  HYBRID_WINDOW_MANAGER.onWindowMove(event);
});

COMPOSITOR.event.onWindowMaximizeRequest((event) => {
  HYBRID_WINDOW_MANAGER.onWindowMaximizeRequest(event);
});

COMPOSITOR.event.onWindowMinimizeRequest((event) => {
  HYBRID_WINDOW_MANAGER.onWindowMinimizeRequest(event);
});

COMPOSITOR.event.onWindowFullscreenRequest((event) => {
  HYBRID_WINDOW_MANAGER.onWindowFullscreenRequest(event);
});

COMPOSITOR.event.onWindowActivateRequest((event) => {
  HYBRID_WINDOW_MANAGER.onWindowActivateRequest(event);
  scheduleWorkspaceBroadcast();
});

function usesClientDecoration(window: WaylandWindow): boolean {
  const decoration = window.decoration();
  return decoration.mode === "client" && !(
    decoration.clientPreference === "server" &&
    decoration.configuredMode === "server"
  );
}

function naturalRootRect(window: WaylandWindow): ManagedWindowRect {
  const client = window.position;
  const titlebarHeight = usesClientDecoration(window) ? 0 : TITLEBAR_HEIGHT;
  return {
    x: client.x - WINDOW_BORDER_PX,
    y: client.y - titlebarHeight - WINDOW_BORDER_PX,
    width: client.width + WINDOW_BORDER_PX * 2,
    height: client.height + titlebarHeight + WINDOW_BORDER_PX * 2,
  };
}

COMPOSITOR.window.composition = (window: WaylandWindow) => {
  const useClientDecoration = usesClientDecoration(window);
  const workspaceVisible = window.state[WINDOW_STATE_WORKSPACE_VISIBLE];
  const workspaceOffsetY = window.state[WINDOW_STATE_WORKSPACE_OFFSET_Y];
  const workspaceOpacity = window.state[WINDOW_STATE_WORKSPACE_OPACITY];
  const tileDragging = window.state[WINDOW_STATE_TILE_DRAGGING];
  const managedRect = computed(() => {
    const rect = window.state[WINDOW_STATE_RECT]();
    return {
      x: read(rect.x),
      y: read(rect.y) + workspaceOffsetY(),
      width: read(rect.width),
      height: read(rect.height),
    };
  });
  const forceRectSize = computed(
    () => window.isResizable() && !window.isTransient(),
  );

  // force no corner rounding CSD
  const tiled = true;

  const stackZIndex = HYBRID_WINDOW_MANAGER.getWindowZIndex(window);
  const zIndex = computed(() => {
    // Capture and audio controls stay above normal and fullscreen clients.
    if (isFloatingUtilityWindow(window)) {
      return FULLSCREEN_Z_INDEX + 1
        + Math.max(0, Math.min(WINDOW_STACK_Z_INDEX_RANGE, stackZIndex()));
    }
    if (window.state[WINDOW_STATE_FULLSCREEN]() || window.state[WINDOW_STATE_FULLSCREEN_WITH_CHROME]()) return FULLSCREEN_Z_INDEX;
    if (!window.state[WINDOW_STATE_WORKSPACE_TILED]()) {
      return stackZIndex();
    }
    const stackOffset = Math.max(
      -WINDOW_STACK_Z_INDEX_RANGE,
      Math.min(WINDOW_STACK_Z_INDEX_RANGE, stackZIndex()),
    );
    if (!window.state[WINDOW_STATE_TILED]()) {
      return FLOATING_WINDOW_Z_INDEX_BASE + stackOffset;
    }
    if (window.state[WINDOW_STATE_TILE_REORDERING]()) {
      return REORDERING_TILED_WINDOW_Z_INDEX;
    }
    return window.isFocused()
      ? FOCUSED_TILED_WINDOW_Z_INDEX
      : stackOffset;
  });
  const minimizeVisualIdle = window.state[WINDOW_STATE_MINIMIZE_VISUAL_IDLE];
  const inactive = computed(
    () => (minimizeVisualIdle() && !windowWaveIsHiding(window))
      || (!workspaceVisible() && !tileDragging()),
  );
  const interactive = computed(
    () => !window.state[WINDOW_STATE_MINIMIZED]() && !inactive(),
  );

  const borderColor = window.isFocused((focused) =>
    focused ? "#cba6f7" : "#585b70",
  );
  const titlebarBackground = window.isFocused((focused) =>
    focused ? "#1e1e2e" : "#181825",
  );
  const titleColor = window.isFocused((focused) =>
    focused ? "#cdd6f4" : "#a6adc8",
  );

  const titlebarStyle: SSDStyle = {
    height: TITLEBAR_HEIGHT,
    paddingX: 8,
    gap: 8,
    alignItems: "center",
    background: titlebarBackground,
  };

  const backgroundShader = compileEffect({
    input: backdropSource(),
    capturePadding: 24,
    invalidate: { kind: "on-source-damage-box", damagePadding: 8 },
    pipeline: [
      dualKawaseBlur({ radius: 4, passes: 2 }),
      shaderStage(loadShader("./src/effect/liquid-glass.frag"), {
        uniforms: {
          glass_radius_px: 10.0,
          distortion_depth: 0.2,
          distortion_strength: 0.15,
          chromatic_shift_px: 3.0,
          glass_tint: 0.9,
        },
      }),
    ],
  });

  const appIcon = (
    <AppIcon icon={window.icon} style={{ width: 16, height: 16 }} />
  );
  const label = (
    <Label
      text={window.title}
      style={{
        color: titleColor,
        fontFamily: ["Noto Sans", "Noto Color Emoji"],
        fontSize: 13,
        fontWeight: 600,
        flexGrow: 1,
        flexShrink: 1,
        minWidth: 0,
      }}
    />
  );
  const minimizeButton = <MinimizeButton window={window} />;
  const maximizeButton = <MaximizeButton window={window} />;
  const closeButton = <CloseButton window={window} />;

  var innerComponents = (
    <Box direction="column">
      <Box direction="row" style={titlebarStyle}>
        {appIcon}
        {label}
        {minimizeButton}
        {maximizeButton}
        {closeButton}
      </Box>
      <ClientWindow />
    </Box>
  );

  const TERMINALS = ["kitty", "ghostty", "com.mitchellh.ghostty"];

  if (TERMINALS.includes(window.appId() ?? "")) {
    innerComponents = (
      <ShaderEffect shader={backgroundShader} direction="column">
        <Box direction="row" style={titlebarStyle}>
          {appIcon}
          {label}
          {minimizeButton}
          {maximizeButton}
          {closeButton}
        </Box>
        <ClientWindow />
      </ShaderEffect>
    );
  }

  // Fullscreen: drop all chrome (titlebar, border, rounded corners) and let
  // the client surface fill its managed rect edge to edge. The rect is set to
  // the whole output by onWindowFullscreenRequest. Rendering nothing but the
  // bare ClientWindow is also what lets the tty backend promote the client
  // buffer to the primary plane (direct scanout).
  if (window.state[WINDOW_STATE_FULLSCREEN]() && !window.state[WINDOW_STATE_FULLSCREEN_WITH_CHROME]()) {
    return (
      <ManagedWindow
        rect={managedRect}
        zIndex={zIndex}
        visibleOutputs={window.state[WINDOW_STATE_VISIBLE_OUTPUTS]}
        opacity={workspaceOpacity}
        forceRectSize={forceRectSize}
        tiled={tiled}
        idle={inactive}
        interactive={interactive}
        // Permit low-latency tearing for fullscreen windows. The compositor only actually tears
        // once the window is on the direct-scanout fast path and is committing faster than the
        // refresh rate (i.e. games), so this is a no-op for ordinary fullscreen apps. Narrow it
        // per app if desired, e.g. `allowTearing={isGame(window.appId())}`.
        allowTearing={true}
      >
        <ClientWindow />
      </ManagedWindow>
    );
  }

  // use less Server-Side Decoration
  if (useClientDecoration) {
    return (
      <ManagedWindow
        rect={managedRect}
        zIndex={zIndex}
        visibleOutputs={window.state[WINDOW_STATE_VISIBLE_OUTPUTS]}
        opacity={workspaceOpacity}
        forceRectSize={forceRectSize}
        tiled={tiled}
        idle={inactive}
        interactive={interactive}
      >
        <WindowBorder
          style={{
            border: { px: window.state[WINDOW_STATE_FULLSCREEN_WITH_CHROME]() ? 0 : WINDOW_BORDER_PX, color: borderColor },
            borderRadius: window.state[WINDOW_STATE_FULLSCREEN_WITH_CHROME]() ? 0 : 10,
            background: "#11111b00",
            padding: 0,
            paddingX: 0,
            paddingRight: 0,
          }}
          interaction={{
            resizeHitArea: {
              edgePx: 8,
              cornerPx: 14,
            },
          }}
        >
          <ClientWindow />
        </WindowBorder>
      </ManagedWindow>
    );
  }

  // use full Server-Side Decoration
  return (
    <ManagedWindow
      rect={managedRect}
      zIndex={zIndex}
      visibleOutputs={window.state[WINDOW_STATE_VISIBLE_OUTPUTS]}
      opacity={workspaceOpacity}
      forceRectSize={forceRectSize}
      tiled={tiled}
      idle={inactive}
      interactive={interactive}
    >
      <WindowBorder
        style={{
          border: { px: window.state[WINDOW_STATE_FULLSCREEN_WITH_CHROME]() ? 0 : WINDOW_BORDER_PX, color: borderColor },
          borderRadius: window.state[WINDOW_STATE_FULLSCREEN_WITH_CHROME]() ? 0 : 10,
          background: "#11111b00",
          padding: 0,
          paddingX: 0,
          paddingRight: 0,
        }}
        interaction={{
          resizeHitArea: {
            edgePx: 8,
            cornerPx: 14,
          },
        }}
      >
        <Box direction="row">{innerComponents}</Box>
      </WindowBorder>
    </ManagedWindow>
  );
};

const CloseButton = ({ window }: { window: WaylandWindow }) => {
  const [hover, setHover] = useState(false);

  const borderColor = hover((hover) => (hover ? "#00000000" : "#f38ba830"));

  var icon: CompositionRenderable | null = null;
  if (hover()) {
    icon = (
      <Image
        src="./assets/x.svg"
        style={{
          width: 16,
          height: 16,
          position: "absolute",
          zIndex: 1,
          pointerEvents: "none",
        }}
      />
    );
  }

  return (
    <Box style={{ position: "relative", flexShrink: 0 }}>
      <Button
        onHoverChange={setHover}
        style={{
          width: 16,
          height: 16,
          borderRadius: 8,
          background: "#cdd6f420",
          border: { px: 1, color: borderColor },
        }}
        onClick={window.close}
      />
      {icon}
    </Box>
  );
};

const MaximizeButton = ({ window }: { window: WaylandWindow }) => {
  const [hover, setHover] = useState(false);

  const borderColor = computed(() => {
    if (!window.isResizable()) {
      return "#00000000";
    }
    return hover() ? "#00000000" : "#cba6f730";
  });
  const shouldHover = computed(() => hover() && window.isResizable());

  var icon: CompositionRenderable | null = null;
  if (shouldHover()) {
    const src = window.isMaximized((maximized) => {
      return maximized ? "./assets/minimize-2.svg" : "./assets/maximize-2.svg";
    });

    icon = (
      <Image
        src={src}
        style={{
          width: 16,
          height: 16,
          position: "absolute",
          zIndex: 1,
          pointerEvents: "none",
        }}
      />
    );
  }

  return (
    <Box style={{ position: "relative", flexShrink: 0 }}>
      <Button
        onHoverChange={setHover}
        style={{
          width: 16,
          height: 16,
          borderRadius: 8,
          background: "#cdd6f420",
          border: { px: 1, color: borderColor },
        }}
        onClick={() => {
          if (!read(window.isResizable)) {
            return;
          }

          if (read(window.isMaximized)) {
            window.unmaximize();
          } else {
            window.maximize();
          }
        }}
      />
      {icon}
    </Box>
  );
};

const MinimizeButton = ({ window }: { window: WaylandWindow }) => {
  const [hover, setHover] = useState(false);

  const borderColor = hover((hover) => (hover ? "#00000000" : "#f9e2af30"));

  var icon: CompositionRenderable | null = null;
  if (hover()) {
    icon = (
      <Image
        src="./assets/minus.svg"
        style={{
          width: 16,
          height: 16,
          position: "absolute",
          zIndex: 1,
          pointerEvents: "none",
        }}
      />
    );
  }

  return (
    <Box style={{ position: "relative", flexShrink: 0 }}>
      <Button
        onHoverChange={setHover}
        style={{
          width: 16,
          height: 16,
          borderRadius: 8,
          background: "#cdd6f420",
          border: { px: 1, color: borderColor },
        }}
        onClick={() => window.minimize()}
      />
      {icon}
    </Box>
  );
};

export default COMPOSITOR;
