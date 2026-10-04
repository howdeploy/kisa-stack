// The accepted wallpaper-wave geometry/material, sampling the live backdrop.
uniform vec2 viewportSize;
uniform vec2 outputOrigin;
uniform vec2 outputSize;
uniform float progress;
uniform sampler2D previous;
uniform vec4 accent;
uniform vec4 warm;
uniform vec4 backgroundColor;

float hashCell(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 liveColor(vec2 uv) {
    vec2 local = clamp((uv * viewportSize - outputOrigin) / outputSize, 0.0, 1.0);
    vec4 c = texture2D(tex, local);
    return c.rgb + backgroundColor.rgb * (1.0 - c.a);
}

vec3 oldColor(vec2 uv) {
    vec2 local = clamp((uv * viewportSize - outputOrigin) / outputSize, 0.0, 1.0);
    vec4 c = texture2D(previous, local);
    return c.rgb + backgroundColor.rgb * (1.0 - c.a);
}

vec3 newColor(vec2 uv) {
    return liveColor(uv);
}

// Same three moving harmonics and radial easing as music_kisa's water reveal.
float waveRadius(vec2 p, float radius, float swell) {
    float angle = atan(p.y, p.x + 0.0001);
    float crest = sin(angle * 3.0 + progress * 7.0) * 0.55
                + sin(angle * 7.0 - progress * 11.0) * 0.30
                + cos(angle * 11.0 + progress * 9.0) * 0.15;
    return radius + swell * crest;
}

vec4 pixels(vec2 p, float size, float radius, float swell, float band, float layer) {
    vec2 direction = p / max(length(p), 1.0);
    vec2 tangent = vec2(-direction.y, direction.x);
    vec2 flow = direction * progress * (84.0 + layer * 38.0)
              + tangent * (progress * 66.0 + sin(progress * 6.0 + layer) * 12.0);
    vec2 cell = floor((p - flow) / size);
    float seed = hashCell(cell + layer * 31.7);
    float tone = hashCell(cell + vec2(43.2, 17.9));
    vec2 jitter = vec2(seed - 0.5, tone - 0.5) * 0.20;
    vec2 center = (cell + 0.5 + jitter) * size + flow;
    float depth = waveRadius(center, radius, swell) - length(center);
    float envelope = smoothstep(0.0, band * 0.20, depth)
                   * (1.0 - smoothstep(band * 0.70, band * 1.45, depth));
    if (envelope <= 0.0) return vec4(0.0);

    float pulse = 0.5 + 0.5 * sin(progress * 17.0 + seed * 6.2831853);
    float halfSize = mix(0.17, 0.39, seed) * mix(0.65, 1.0, envelope) + pulse * 0.025;
    vec2 local = (p - center) / size;
    float square = max(abs(local.x), abs(local.y));
    float body = 1.0 - smoothstep(halfSize - 0.06, halfSize + 0.07, square);
    float glow = (1.0 - smoothstep(halfSize, 0.58, length(local))) * 0.16;

    // Soft colour matter samples both wallpapers, not a grid of image cut-outs.
    vec2 uv = center / viewportSize + 0.5;
    vec2 spread = vec2(18.0 + 22.0 * seed) / viewportSize;
    vec3 before = (oldColor(uv - spread) + oldColor(uv + spread)) * 0.5;
    vec3 after = (newColor(uv + vec2(spread.x, -spread.y))
                + newColor(uv + vec2(-spread.x, spread.y))) * 0.5;
    vec3 color = mix(before, after, smoothstep(0.0, band, depth));
    color = mix(color, mix(accent.rgb, warm.rgb, tone), 0.32 + seed * 0.28);
    float gray = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = clamp(mix(vec3(gray), color, 1.35) * (0.85 + tone * 0.30), 0.0, 1.0);
    float alpha = clamp((body + glow) * envelope * (0.65 + seed * 0.35), 0.0, 0.96);
    if (layer > 0.5) alpha *= smoothstep(0.25, 0.60, seed);
    return vec4(color * alpha, alpha);
}

vec4 shader_main(EffectContext effect) {
    vec2 uv = (outputOrigin + effect.texture_uv * outputSize) / viewportSize;
    if (progress <= 0.0) return vec4(oldColor(uv), 1.0);
    if (progress >= 1.0) return vec4(newColor(uv), 1.0);

    vec2 p = (uv - 0.5) * viewportSize;
    float reach = length(viewportSize * 0.5);
    float maxBand = clamp(min(viewportSize.x, viewportSize.y) * 0.08, 60.0, 110.0);
    float radius = (reach + maxBand * 1.85) * (1.0 - pow(1.0 - progress, 1.4));
    float band = max(1.0, min(maxBand, radius * 0.28));
    float swell = sin(3.1415927 * progress) * min(42.0, reach * 0.045);
    float depth = waveRadius(p, radius, swell) - length(p);
    if (depth <= 0.0) return vec4(oldColor(uv), 1.0);
    if (depth >= band * 1.60) return vec4(newColor(uv), 1.0);

    float stagger = hashCell(floor(p / 10.0)) * band * 0.18;
    float assembled = smoothstep(band * 0.28, band * 1.35, depth - stagger);
    vec2 direction = p / max(length(p), 1.0);
    float water = sin(depth / band * 8.0) * sin(progress * 3.1415927)
                * smoothstep(0.0, band * 0.20, depth)
                * (1.0 - smoothstep(band * 0.50, band * 1.5, depth));
    vec2 refracted = uv + direction * water * 7.0 / viewportSize;
    vec3 arriving = (newColor(refracted + vec2(8.0, 8.0) / viewportSize)
                   + newColor(refracted - vec2(8.0, 8.0) / viewportSize)) * 0.5;
    arriving = mix(arriving, newColor(uv), smoothstep(0.30, 1.0, assembled));
    vec3 base = mix(oldColor(refracted), arriving, assembled);

    vec4 large = pixels(p, 26.0, radius, swell, band, 0.0);
    vec4 small = pixels(p, 9.88, radius, swell, band, 1.0);
    vec4 matter = small + large * (1.0 - small.a);
    matter *= (1.0 - assembled) * smoothstep(0.0, 18.0, radius)
            * smoothstep(0.0, band * 0.12, depth);
    return vec4(base * (1.0 - matter.a) + matter.rgb, 1.0);
}
