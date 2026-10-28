# Native lock-scene integration

The publication source now uses the generic
`COMPOSITOR.session.configureLockBackground({ windowIds, layerIds })` API.
Application/namespace selection belongs to the TS config, not the compositor.
The config retains a compatibility path for the locally installed pre-generic
binary. The generic implementation has not been built, installed or exercised;
the build/install history below refers to the earlier local implementation.
The user subsequently confirmed both animated-wallpaper and MateEngine
screensaver modes worked after the deadlock correction. The final UI entrance
and empty-password reveal changes have not yet been confirmed.

On 2026-10-28 the native compositor, managed MateEngine integration and QML/TS
configuration were built and installed locally with explicit permission and
backups. The session/player were not restarted. Real authentication, animation,
input routing and DPMS remain unverified until the user's deliberate acceptance
check of the generic public build. The earlier local wallpaper/screensaver
behavior was subsequently accepted by the user. See [build and installation record](validation.md).

The first local Super+L attempt subsequently froze the compositor. Source review
found a self-deadlock in the added wallpaper background renderer: it held the
output LayerMap mutex while calling a helper that reacquires the same mutex.
The patch now obtains owned layer handles through `layer_surfaces_for_output`
before rendering, releasing the map guard first. This fixes the shared TTY/winit
path. The corrected release build passed and was installed locally without
restarting the session. The user later accepted the local wallpaper/screensaver
behavior; validation of the generic public build remains pending.

## Intended behavior

- The Quickshell password UI remains the session-lock surface. Keyboard/pointer
  routing stays in the existing compositor session-lock path; PAM owns unlock.
- Animated Wallpaper Engine roots render underneath that UI. If MateEngine's
  Big Screen screensaver is enabled and the bridge is fresh, its root joins the
  background. Outputs not covered by that window continue showing wallpaper.
- MateEngine receives the compositor's actual `sessionLocked` state. The enabled
  screensaver stays active while a password is typed; menu/idle heuristics resume
  when the session unlocks. No password or locked pointer data is sent to MateEngine.
- After PAM success, Quickshell requests a frozen lock-scene overlay while still
  securely locked. It releases the protocol lock only after available-output
  capture is ready, then starts the accepted wallpaper wave over the live desktop.
- The same radial wave geometry spans the connected output layout. Powered-off
  and disabled outputs cannot capture an overlay and are excluded. Successful
  captures on the remaining outputs can proceed.
- Missing native support or a failed/timed-out capture falls back to the existing
  unlock fade. Reduced motion skips the wave. A new lock cancels previous overlays.

## Source locations

| Component | Source |
| --- | --- |
| Locked renderer, native capability and unlock overlay lifetime | Fork revision `d78b72a` in `sources.json`, built by `scripts/build-shojiwm.sh`; the earlier patch export is archival |
| Background selection, bridge state and detached snapshot preparation | `config/shojiwm/src/mateengine.ts`, `src/lock-scene.ts` and registration in `src/index.tsx` |
| QML handoff, fallback and surface opacity | `config/shoji-shell/LockScene.qml`, `Lock.qml`, `LockFace.qml`, `qmldir` |
| Shared transition shader | Existing `config/shojiwm/src/effect/live-wallpaper-wave.frag` |
| MateEngine | Pinned Mate Engine Plus source `34136f2` contains the bridge; the earlier patch export is archival. [Build setup](mateengine.md) |

## Isolation and resource bounds

The locked renderer discards unselected windows, panels and popups. The trusted
TS config resolves MateEngine and `linux-wallpaperengine` to exact current
window/layer runtime IDs. Only those roots are passed to the generic native API,
without separately managed popups or compositor decorations. The native module
contains no application names. Selections are bounded and runtime-owned, applied
at frame boundaries, and hidden when no live buffered locker surface exists.
Fallback lock surfaces remain opaque until native capability and an eligible
background have been reported. With the old binary, the integration stays inactive.

The new overlay placement requires an active protocol lock, a snapshot,
nonpersistent mode and a native deadline of at most 3000ms. The TS controller uses
2500ms and cancels sooner; the wave itself lasts 680ms. Snapshots remain in GPU
memory and are disposed on completion, replacement, timeout, output change,
runtime cleanup or a new lock. No lock-screen bitmap is written to disk.

## Required rollout and acceptance

1. Review the compositor patch and the existing dirty work in all source checkouts.
2. With permission, build the pinned fork plus this patch, including its SDK.
   Build the matching MateEngine managed player/bridge using its X3.4 build guide.
3. Run authorized source/build checks before replacing live binaries/configuration.
   Preserve the working compositor, bridge, player and current user configuration.
4. Install and restart deliberately, with an independent recovery session available.
5. Check each background mode, wrong/correct password, focus on both outputs,
   input isolation, DPMS wake, output removal, reduced motion and the wave's final
   cleanup. The user enters their own password; never automate or record it.

The browser design preview is not a test of native rendering, PAM, input routing
or MateEngine. Its existing visual layout remains separate from this source work.
