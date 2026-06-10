# Voiceover background music prompt patterns

Use these when the user wants background music for spoken content and the first generations miss the target.

## Diagnostic ladder

When a user rejects a track, identify **what kind of wrong** it is before regenerating:

1. **Too technological / too soft / too pretty**
   - Move toward warmer, plainer, more utility-like wording.
   - Reduce atmospheric adjectives.
   - Remove "beautiful", "cinematic", "emotional", "ambient" unless explicitly wanted.

2. **Too instrumentally expressive / not truly background**
   - Ask the model for a "stock background bed", "explainer underscore", or "library music" feel.
   - Explicitly suppress lead instruments, featured piano, melodic phrases, swells, hooks.
   - Add "designed to stay unnoticed under speech".

3. **Too bland / missing sonic identity**
   - Restore a restrained genre color instead of going fully generic.
   - Good move: synthwave timbre + muted arrangement + no lead melody.

## Reliable phrasing for spoken-video beds

Useful constraints:
- instrumental only
- background bed / underscore
- voiceover-safe / designed for narration
- no lead melody
- no vocals
- no hook
- no dramatic rise / drop
- unobtrusive mix
- designed to stay unnoticed under speech

Useful anti-constraints:
- no featured piano
- no solo instruments
- no cinematic trailer tension
- no bright accents / bells / chimes / glassy plucks
- no sentimental atmosphere
- no lush ambient beauty
- no sparkling highs

## Genre recipes that worked as iteration pivots

### 1. Neutral stock / explainer bed
Use when the user wants nearly invisible support.

Example wording:
> Truly neutral stock background music for a YouTube explainer voiceover. Not emotional, not soft, not cinematic. Simple modern documentary/corporate underscore. Very few elements: steady muted pulse, restrained bass, plain synth bed, minimal percussion, no lead melody, no build, no drop, designed to stay unnoticed under speech.

### 2. Muted synthwave bed
Use when the user says the neutral version feels too library-like and wants actual sonic character.

Example wording:
> Muted synthwave background bed for a YouTube voiceover. Retro-futuristic sound, but restrained and background-safe. Warm analog synth pads, soft synth bass, gentle pulse, light retro drum machine, no lead melody, no heroic hook, no sax, no bright arpeggio showcase, no big snare fills, no cinematic rise, smooth unobtrusive mix.

### 3. Soft outrun documentary
Use when the user wants synthwave color but still needs narration space.

Example wording:
> Soft outrun documentary underscore for spoken tech content. Synthwave tone and neon nostalgia, but subtle and controlled. Rounded analog chords, steady bass pulse, understated electronic drums, very light motion, no featured synth solo, no catchy topline, no aggressive highs, no dramatic build, designed to sit under narration.

### 4. Dark neutral synthwave
Use when the user wants muted retro-digital mood without sparkle.

Example wording:
> Dark neutral synthwave underscore for an explainer video. Calm, matte, slightly nocturnal, retro-digital atmosphere. Soft analog textures, muted kick and snare, restrained bassline, subtle synth motion, no emotional swells, no sparkling lead, no arcade brightness, no featured melody, polished background-only mix.

## Practical lesson from this session

For educational/essay YouTube beds, the user's complaint may not actually be "make it more neutral." Sometimes the real issue is:
- the track is too pretty or tender,
- then too stock and personality-less after correction,
- and what is missing is a controlled genre identity.

In this class of task, do not just slide along one axis from ambient -> neutral. Also test whether the user wants a **specific timbral world** (here: synthwave) with the arrangement restrained enough for speech.