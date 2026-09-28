---
name: shoji-shaders
description: Create and refine GLSL effects for ShojiWM windows, layouts and Quickshell widgets from visual references. Use for shader motion, reveal/hide transitions and GPU effect bugs; not for ordinary CSS or static UI styling.
metadata:
  hermes:
    tags: [shaders, desktop, graphics]
---

# Shoji shader workflow

Find the user's current config first. Public source and detailed map:
https://github.com/howdeploy/kisa-stack/tree/main/dotfiles ; read
`docs/shaders.md` and `sources.json` there or in a local checkout. No private
project memory or author-specific path is required by this skill.

## Read the reference and define the effect

Separate observed motion, code evidence and assumptions. A still image proves
appearance, not trajectory or timing. For Shadertoy, inspect Image and the actual
buffer dependencies when available; do not copy an unbounded simulation into a
finite transition without lifecycle control. If a requested reference cannot be
read, explain that limit instead of inventing what it shows.

Before editing, describe the intended geometry, material, motion and endpoints.
Identify where the reveal starts, what remains fixed, whether particles carry
source pixels or only sampled colors, and how the effect reverses. Preserve the
user's accepted aesthetic; do not substitute a different effect based on keywords.

## Select the real pipeline

| Pipeline | Contract |
| --- | --- |
| ShojiWM `src/effect/*.frag` | GLSL ES 1.00 body; `vec4 shader_main(EffectContext effect)`; `texture2D(tex, effect.texture_uv)` |
| Quickshell `shaders/*.frag` | GLSL 440 with Qt uniform/sampler bindings; compile to `.frag.qsb`; QML `ShaderEffect` |

The compositor does not accept Qt's `#version 440` program or Shadertoy `mainImage`
unchanged. Choose `compileEffect`, `compileWindowEffect`, `compileLayerEffect` or
`compilePopupEffect` according to the target. Match the source type: a window
replacement reads `windowSource()`, a backdrop reads `backdropSource()`.

Read `src/index.tsx` assignments, the closest existing effect module and its callers.
Read the fork's `docs/docs/configuration/effects.md` and shader API types for exact
contracts. Paths passed to `loadShader` resolve from the config package root.
Use texture UV for sampling, content-space coordinates for geometry. Framebuffer
`*_px` and logical capture/damage padding are different units, especially on scaled
outputs. Explicitly bind uniforms/textures; there is no automatic Shadertoy clock.

Preserve premultiplied alpha and `alpha: "preserve"` when required. `save/get` is
intra-frame storage. Persistent state needs `stateTexture/renderTo`, reset on resize
and clear terminal conditions. Prefer an analytic trail when it fits the reference.
Do not keep an expensive effect running on an idle, fully assembled window.

## Trace lifecycle before fixing the formula

Follow event → animation variable → capture → effect assignment → visibility and
input → cleanup. Closing, minimizing, hiding/unmapping and moving to a tray are
different events. Fullscreen, CSD and SSD may enter different rendering paths.

An outgoing capture must remain available through reverse animation, while an
already-hidden window stops receiving input. Avoid competing scale/translation
drivers moving an intended fixed portal center. Define empty/complete endpoints;
prevent content outside the reveal frontier and leftover rings after completion.
Full-source effects need the fork's subsurface fix. Native workspace transitions
also require the pinned fork's TTY implementation.

For wallpaper and widget transitions, share screen-space wave geometry. A moved
widget uses an old-position snapshot plus live destination, not only the destination
mask. Preserve `WidgetWaveSnapshot` registration in `qmldir`. Do not replace the
window manager, delete presets or disable animations to conceal a lifecycle bug.

## Verification and delivery

Make the smallest change that produces the requested visible behavior. Keep palette,
layout and unrelated effects intact. Compile Qt shaders only through the Qt script;
ShojiWM compiles its own shaders at runtime. Run checks and reload/manipulate the
desktop only within the user's authorization. Check interruption, reverse motion,
final cleanup and scaled/multiple outputs when live testing is authorized.

Report what changed and what is known: syntax, shader compilation, actual rendering,
manual aesthetic acceptance and performance are separate evidence. Never infer that
an animation looks correct solely because a compiler returned success.
