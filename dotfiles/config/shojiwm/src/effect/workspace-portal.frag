uniform sampler2D sharp_window;
uniform float visibility;
uniform float reveal_edge;
uniform vec4 viewport;
uniform vec4 window_rect;
uniform float pixel_size;

float cellNoise(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float softNoise(vec2 p) {
    vec2 cell = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(cellNoise(cell), cellNoise(cell + vec2(1.0, 0.0)), f.x),
               mix(cellNoise(cell + vec2(0.0, 1.0)), cellNoise(cell + 1.0), f.x), f.y);
}

vec4 portalMatter(EffectContext effect, vec2 p, float front, float cellSize, float layer) {
    // Both desktops use the same screen-space grid and motion, including reversal.
    vec2 drift = vec2(front * 0.07, front * 0.035) * (1.0 + layer * 0.3);
    vec2 grid = p + drift;
    vec2 cell = floor(grid / cellSize);
    vec2 center = (cell + 0.5) * cellSize - drift + viewport.xy;
    vec2 localUV = clamp((center - window_rect.xy) / max(window_rect.zw, vec2(1.0)),
                         vec2(0.0), vec2(1.0));
    vec2 paletteUV = (effect.content_rect_px.xy + localUV * effect.content_rect_px.zw)
                     / effect.texture_size_px;
    // Only blurred application colors become particles; never rectangular image tiles.
    vec4 palette = texture2D(tex, paletteUV);
    float density = softNoise(cell * 0.23 + vec2(front * 0.002, layer));
    float halfSize = mix(0.27, 0.48, density);
    vec2 within = fract(grid / cellSize) - 0.5;
    float square = max(abs(within.x), abs(within.y));
    float shape = 1.0 - smoothstep(halfSize - 0.08, halfSize + 0.10, square);
    float aura = (1.0 - smoothstep(0.25, 0.72, length(within))) * 0.12;
    float alpha = clamp(shape + aura, 0.0, 1.0);
    if (layer > 0.5) alpha *= smoothstep(0.35, 0.75, density) * 0.6;
    return palette * alpha;
}

vec4 shader_main(EffectContext effect) {
    vec4 sharp = texture2D(sharp_window, effect.texture_uv);
    if (visibility <= 0.0) return vec4(0.0);
    if (visibility >= 1.0) return sharp;

    vec2 localUV = (effect.texture_uv * effect.texture_size_px - effect.content_rect_px.xy)
                   / max(effect.content_rect_px.zw, vec2(1.0));
    vec2 p = window_rect.xy + localUV * window_rect.zw - viewport.xy;
    float band = clamp(viewport.w * 0.12, 80.0, 160.0);
    float front = reveal_edge > 0.0
        ? mix(viewport.w + band, -band, visibility)
        : mix(-band, viewport.w + band, visibility);
    float roughness = (softNoise(vec2(p.x * 0.009, front * 0.003)) - 0.5) * 32.0;
    float depth = reveal_edge * (p.y - front - roughness);
    float coverage = smoothstep(-band * 0.35, band * 0.55, depth);
    float material = 1.0 - smoothstep(band * 0.25, band, abs(p.y - front));

    vec4 largePixels = portalMatter(effect, p, front, pixel_size, 0.0);
    vec4 smallPixels = portalMatter(effect, p, front, pixel_size * 0.38, 1.0);
    vec4 matter = smallPixels + largePixels * (1.0 - smallPixels.a);
    return mix(sharp, matter, material) * coverage;
}
