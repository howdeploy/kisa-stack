---
name: ai-music-and-audio-tools
description: "Use when writing songs, prompting AI music systems, generating music/audio, or creating audio feature visualizations and spectrograms."
version: 1.0.0
author: KISA
license: MIT
metadata:
  hermes:
    tags: [music, audio, songwriting, suno, heartmula, audiocraft, spectrogram]
    related_skills: [youtube-content]
---

# AI Music and Audio Tools

## Overview

This umbrella covers music/audio creation and analysis workflows: lyric writing, Suno-style prompt engineering, HeartMuLa generation, AudioCraft/MusicGen-style local generation, and audio feature visualization such as mel/chroma/MFCC spectrograms.

## When to Use

- The user asks for lyrics, song structure, rhyme/meter, parody, or musical prompt writing.
- The user asks to generate music or background audio with AI tools.
- The user asks about HeartMuLa, AudioCraft, MusicGen, or Suno-like prompts.
- The user asks to visualize or inspect audio features.

## Songwriting and Prompting

- Start with genre, mood, tempo, vocalist/instrumentation, structure, and emotional arc.
- Use bracketed metatags only when the target generator supports them.
- Keep lyrics singable: meter, stresses, repetition, and contrast matter more than clever prose.
- For background music, avoid lyrical hooks unless requested.

## Generation Tools

### HeartMuLa

- Treat as a local generation stack with installation, Python-version, and dependency compatibility constraints.
- Verify hardware and patched dependencies before promising generation.

### AudioCraft / MusicGen

- Check GPU/CPU feasibility and model size.
- Generate short previews first; longer outputs may need batching or stitching.
- Save outputs with clear filenames and report real paths.

### Suno-style prompting

- Separate style/genre description from lyrics when the UI/API expects separate fields.
- Include arrangement cues such as intro, verse, chorus, bridge, drop, outro, and instrumentation.

## Audio Feature Visualization

- Use spectrogram/feature tools for mel, chroma, MFCC, waveform, or analysis plots.
- Confirm sample rate and channels before interpreting output.
- Present generated images/audio paths, not just descriptions.

## Common Pitfalls

1. Writing text that looks poetic but cannot be sung.
2. Ignoring generator-specific field limits or metatag syntax.
3. Starting a heavy generation job without checking hardware/dependencies.
4. Treating a failed/partial render as a completed audio file.
5. Overstating what feature visualizations prove musically.

## Verification Checklist

- [ ] Target tool and output format are clear.
- [ ] Dependencies/hardware checked for local generation.
- [ ] Audio or visualization artifact exists at a path.
- [ ] Lyrics/prompts match the requested genre, mood, and structure.
