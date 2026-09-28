# Shader and animation guide

There are **two incompatible shader pipelines** in this desktop. Pick the target
before writing GLSL. A successful `qsb` build says nothing about a ShojiWM shader.

| Target | Source files | Compiler and entrypoint |
| --- | --- | --- |
| Compositor windows, layers, popups and composition | `config/shojiwm/src/effect/` | ShojiWM runtime; GLSL ES 1.00; `vec4 shader_main(EffectContext effect)` |
| Wallpaper, widget masks and Neko | `config/shoji-shell/shaders/` | Qt 6 `qsb`; GLSL 440 input; `void main()` with Qt uniform ABI |

## Find the active effect

Start at `shojiwm/src/index.tsx` and follow imports and effect assignments. The
directory also retains alternate experiments; a filename existing does not make
that shader active.

| Effect | Entry module / primary shader | Control |
| --- | --- | --- |
| Window appear/hide/dissolve | `window-wave.ts` / `window-wave-sparse.frag` | Window lifecycle variables; 460 ms reveal, 512 ms dissolve in this snapshot |
| Drag distortion | `window-drag-jelly.ts` and its fragments | Drag state; between wave and ordinary jelly in assignment priority |
| Window jelly | `window-jelly.ts` and its fragments | Window motion and deformation |
| Monitor portal | `monitor-portal.ts`, `monitor-portal.frag`, `monitor-window-portal.frag` | Transfer between outputs |
| Layout change | `layout-melt.ts`, flow/melt stages | Shared transition; 760 ms in this snapshot |
| Workspace change | `workspace-wave.ts` plus fork native TTY implementation | Workspace API and native capture lifecycle |
| Layer glass | `island-glass.ts`, `island-*.frag` | Silhouette, distance field, blur and refraction |
| Wallpaper | `WallpaperTransition.qml`, `wallpaper-wave.frag` | Before/after images, output size and shared progress |
| Widget reveal/relocation | `WidgetWaveLoader.qml`, `WidgetWaveSnapshot.qml`, `widget-wave-mask.frag` | Same screen-space wave as wallpaper |
| Neko | `NekoWidget.qml`, `NekoMotion.js`, `neko-pudding.frag` | Procedural shape, pointer motion and music energy |

## ShojiWM ABI

Use the fork's pinned [effects reference](https://github.com/howdeploy/ShojiWM/blob/f61a5f98117c355fe131e3d550970de0ed6a5120/docs/docs/configuration/effects.md)
and the actual `packages/shoji_wm/src/shader.ts` types. The compiler must match the
assignment: `compileEffect` for composition/background, `compileWindowEffect` for
windows, `compileLayerEffect` for layers, `compilePopupEffect` for popups.

`windowSource()` reads a window; `backdropSource()` reads behind the target. They
are not interchangeable. Named extra sources are bound through `textures` and
values through `uniforms`. The current stage's input is available as `tex`:

```glsl
// ShojiWM fragment body, not a complete Qt or Shadertoy program.
vec4 shader_main(EffectContext effect) {
    return texture2D(tex, effect.texture_uv);
}
```

`loadShader("./src/effect/name.frag")` resolves from the config package root.
Use `effect.texture_uv` for sampling and the appropriate content-space coordinates
for geometry. `*_px` values are framebuffer pixels; capture/damage padding is in
logical units. Mixing them breaks scale-dependent edges and multi-monitor motion.

Preserve premultiplied alpha and request `alpha: "preserve"` where transparency is
part of the effect. `save/get` store intermediate textures for **one frame**;
`stateTexture/renderTo` is for actual persistent state and requires reset/resize
semantics. Avoid temporal feedback if an analytic trail is sufficient. Avoid
unconditional invalidation for an idle window.

`background_effect` applies to client-requested background-effect regions, not an
automatic whole-screen shader. The full-window replacement path depends on fork
PR #108 to include subsurfaces. Do not assume CSD, SSD and fullscreen take identical
rendering paths: follow each assignment and composition branch.

## Qt / Quickshell ABI

Qt sources declare `#version 440`, explicit input/output locations, the std140
uniform block containing `qt_Matrix`/`qt_Opacity`, and sampler bindings. QML property
names must match uniforms. Compile with `scripts/build-shaders.sh` after changes;
the QML `fragmentShader` property references the resulting `.frag.qsb` file.
Retain the same block layout and names between the GLSL source and QML component.

The widget mask and wallpaper shader share screen-space wave geometry. Changing
only one creates a visible mismatch. A widget moved between presets needs both
an outgoing snapshot and a live destination; a loader being destroyed early cannot
be repaired by a fragment formula. Keep `WidgetWaveSnapshot` registered in `qmldir`.

## Work from a reference

1. Describe the visible geometry, material, motion and endpoints before editing.
   Separate things seen in moving footage from guesses based on a still image.
2. Locate the nearest existing pipeline. Read its callers and lifecycle before
   adding a shader. Name opening, closing, minimize, restore, placement change and
   interrupted transitions where relevant.
3. Use one consistent reveal boundary: content must not appear outside the intended
   wave. Define completely empty and completely assembled endpoints explicitly.
4. Keep the captured surface alive until the reverse animation ends, while hidden
   windows stop accepting input. Preserve focus, layout and unrelated styling.
5. Verify only within the user's authorized scope. Distinguish syntax, compilation,
   live GPU rendering, manual aesthetic approval and measured performance.

The [shoji-shaders skill](../../skills/shoji-shaders/SKILL.md) packages this workflow
for agents. A request for one effect is not permission to rewrite the entire
composition or to launch a GUI session without agreement.
