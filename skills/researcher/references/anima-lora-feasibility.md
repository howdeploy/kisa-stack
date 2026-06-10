# Anima v1 / L4 24 GB — condensed feasibility notes

Use this when the user asks whether a rented NVIDIA L4 24 GB can train Anima, what Anima actually is, or whether classic SD1.5/Kohya assumptions apply.

## What Anima is
- `Anima` is a `2B parameter text-to-image model` focused on anime concepts, characters, styles, and other non-photorealistic art.
- Officially presented as a collaboration between `CircleStone Labs` and `Comfy Org`.
- Official README says `Built on NVIDIA Cosmos` and treats the model as a derivative of `Cosmos-Predict2-2B-Text2Image`.
- Key components called out in docs/model card:
  - base model: `anima-base-v1.0.safetensors`
  - text encoder: `qwen_3_06b_base.safetensors`
  - VAE: `qwen_image_vae.safetensors`
- This is **not** a normal SD1.5 / SDXL checkpoint. Do not assume old Kohya recipes transfer 1:1.

## Training path
- For LoRA/network training, prefer the dedicated `sd-scripts` Anima path: `anima_train_network.py`.
- Why: Anima uses a different stack (DiT / Qwen text encoder / Qwen-image VAE, plus adapter pieces in the training docs), so "standard SD1.5 LoRA command" is the wrong default.
- If the user asks about full finetune, answer separately from LoRA. Do not blur them together.

## Practical answer for L4 24 GB
Short version:
- `LoRA on L4 24 GB` -> **yes, realistic**.
- `Full finetune on single L4` -> **generally not the practical recommendation**.

Why:
- L4 has 24 GB VRAM, which is enough for small/medium LoRA runs.
- But L4 bandwidth is far below RTX 3090-class consumer cards, so raw throughput is worse even if VRAM size matches.
- Community reports around Anima training suggest rough feasibility like:
  - around `~10 GB` VRAM at `512px, batch 1` with checkpointing
  - around `~14 GB` VRAM at `1024px, batch 1`
  - full finetune territory closer to `~31–33 GB` VRAM
- Treat those as practical community numbers, not vendor guarantees.

## Memory-saving flags worth checking
When discussing feasibility, explicitly look for and mention the actual memory-saving knobs from upstream/community docs, e.g.:
- `--gradient_checkpointing`
- `--cache_latents`
- `--cache_text_encoder_outputs`
- `--vae_chunk_size`
- `--vae_disable_cache`

## Best-use cases to say out loud
Good fit for Anima LoRA:
- character LoRA
- style / aesthetic LoRA
- outfit / costume / accessory concept LoRA
- anime / illustration-specific visual identity

Bad or weaker fit:
- photoreal identity work
- broad "universal everything" expectations
- pretending a niche anime base is the best generic realism model

## Dataset prep pattern that worked well
For anime/illustration training research, default to:
- `WD14 -> cleanup -> train`

Useful upgrade path:
- `WD14 + Florence/JoyCaption -> merge -> cleanup -> train`

Reason:
- Anima understands Danbooru-style tags well, so WD14-style taggers are a strong first default.
- Caption models can add nuance, but should usually augment, not replace, tag-centric captions.

## Small character-dataset heuristic
For something like `15–20 images of one mascot/character`:
- success is plausible if the design is consistent and the views are varied enough;
- hair, silhouette, outfit type, and general vibe usually learn more easily than tiny accessories or rare back/side details;
- rough training window on L4 is often in the `~30–90 min` range for the train itself, but practical end-to-end session time is longer because dataset cleanup dominates.

## Release / provenance facts worth separating by confidence
Higher-confidence / official:
- collaboration: `CircleStone Labs + Comfy Org`
- built on `NVIDIA Cosmos`
- derivative-of-Cosmos licensing relationship
- component stack and required files
- comparison workflow exists in README (`anima_comparison.json`)

Useful but secondary / external:
- public listing date for `base v1.0`: often cited as `2026-05-14`
- claims like `first sponsored model` for Comfy/ComfyUI appear in secondary/community sources and should be labeled that way unless the current session has a direct first-party quote

## Benchmark caveat
When asked for "benchmarks", do not pretend there is a neat official leaderboard if you did not find one.
Separate:
- official/public model-comparison workflow
- community side-by-side evaluations
- popularity/traction signals (downloads, likes)
- formal quantitative benchmarks (if absent, say absent)

## Good final framing
A strong answer usually has this shape:
1. one-line verdict (`yes for LoRA, no for practical single-GPU full finetune`)
2. why the model is unusual (not SD1.5/SDXL, different stack)
3. what hardware constraints actually matter (VRAM + bandwidth)
4. what the user should train on it
5. what workflow to use for captions/tags and training
6. rough time/cost numbers if available
