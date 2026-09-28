uniform float closed;
uniform float dissolving;
uniform float reveal_at_close;
uniform vec2 surface_size;
uniform vec3 theme_accent;

float crest(float angle, float phase) {
    return sin(angle * 3.0 + phase * 7.0) * 0.55
         + sin(angle * 7.0 - phase * 11.0) * 0.30
         + cos(angle * 11.0 + phase * 9.0) * 0.15;
}

vec4 waveEdge(vec4 image, float depth, float width, float feather, float life) {
    if (depth <= -feather) return vec4(0.0);
    if (depth >= width * 2.0) return image;
    float coverage = smoothstep(-feather, feather, depth);
    float band = (1.0 - smoothstep(0.0, width, depth)) * life * 0.60;
    float highlight = 1.0 - smoothstep(0.0, width * 0.32, abs(depth - width * 0.22));
    vec3 color = mix(image.rgb, theme_accent * image.a, band);
    color = mix(color, mix(theme_accent, vec3(1.0), 0.25) * image.a,
        highlight * highlight * life * 0.22);
    return vec4(color, image.a) * coverage;
}

vec4 revealWave(vec4 image, vec2 point, vec2 extent, float progress) {
    if (progress <= 0.0) return vec4(0.0);
    if (progress >= 1.0) return image;
    vec2 delta = point - extent * 0.5;
    float distance = length(delta);
    float width = clamp(min(extent.x, extent.y) * 0.035, 12.0, 32.0);
    float feather = width * 0.65;
    float reach = length(extent * 0.5) + width * 2.0;
    // Zero speed at both ends; the same clock still reverses exactly.
    float eased = progress * progress * (3.0 - 2.0 * progress);
    float radius = reach * eased;
    float life = 4.0 * progress * (1.0 - progress);
    float swell = life * min(30.0, reach * 0.045);
    float depth = radius - distance;
    // Most of the window needs neither angular harmonics nor edge shading.
    if (depth < -swell - feather) return vec4(0.0);
    if (depth > swell + width * 2.0) return image;
    float angle = distance > 0.001 ? atan(delta.y, delta.x) : 0.0;
    depth += swell * crest(angle, progress);
    return waveEdge(image, depth, width, feather, life)
        * smoothstep(0.0, feather, radius);
}

vec4 shader_main(EffectContext effect) {
    float time = clamp(closed, 0.0, 1.0);
    if (time >= 1.0) return vec4(0.0);
    vec4 image = texture2D(tex, effect.texture_uv);
    if (image.a <= 0.0) return image;
    vec2 extent = max(surface_size, vec2(1.0));
    vec2 point = effect_content_uv(effect) * extent;
    if (dissolving < 0.5) return revealWave(image, point, extent, 1.0 - time);

    if (time <= 0.0) return revealWave(image, point, extent, reveal_at_close);
    vec2 p = point / extent;
    float cloud = 0.5
        + 0.28 * sin(p.x * 4.0 + time * 1.2) * cos(p.y * 3.5 - time * 0.8)
        + 0.16 * sin((p.x + p.y) * 3.0 - time);
    float delay = cloud * 0.22;
    float fade = smoothstep(0.0, 1.0, clamp((time - delay) / (1.0 - delay), 0.0, 1.0));
    // Broad translucent wisps, not thresholded holes: every region fades to
    // the same empty endpoint. Premultiplied samples keep dark edges clean.
    vec2 blur = vec2(12.0 * time * time) / extent
        * effect.content_rect_px.zw / effect.texture_size_px;
    vec2 uv = effect.texture_uv;
    vec4 soft = image * 0.5;
    soft += texture2D(tex, clamp(uv + vec2(blur.x, 0.0), 0.0, 1.0)) * 0.125;
    soft += texture2D(tex, clamp(uv - vec2(blur.x, 0.0), 0.0, 1.0)) * 0.125;
    soft += texture2D(tex, clamp(uv + vec2(0.0, blur.y), 0.0, 1.0)) * 0.125;
    soft += texture2D(tex, clamp(uv - vec2(0.0, blur.y), 0.0, 1.0)) * 0.125;
    soft = mix(image, soft, smoothstep(0.0, 0.65, time));
    // Apply the frozen reveal after diffusion, including interrupted minimizes.
    return revealWave(soft, point, extent, reveal_at_close) * (1.0 - fade);
}
