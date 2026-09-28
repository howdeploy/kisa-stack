uniform sampler2D previous;
uniform float progress;
uniform float direction;
uniform vec2 screen_size;
uniform vec3 theme_accent;

vec4 shader_main(EffectContext effect) {
    vec2 uv = effect.texture_uv;
    vec4 live = texture2D(tex, uv);
    vec4 old = texture2D(previous, uv);
    if (progress >= 1.0 || old.a < 0.5) return live;
    if (progress <= 0.0) return old;

    vec2 local = (uv * effect.texture_size_px - effect.content_rect_px.xy)
        / max(effect.content_rect_px.zw, vec2(1.0));
    // kisa_music/wowWaterTransition.ts: expand from the centre of an edge.
    vec2 origin = vec2(screen_size.x * 0.5, direction > 0.0 ? screen_size.y : 0.0);
    vec2 delta = local * screen_size - origin;
    float distance = length(delta);
    float angle = distance > 0.001 ? atan(delta.y, delta.x) : 0.0;
    float reach = length(vec2(screen_size.x * 0.5, screen_size.y)) + 100.0;
    float radius = reach * (1.0 - pow(1.0 - progress, 1.4));
    float life = sin(progress * 3.14159265);
    float crest = sin(angle * 3.0 + progress * 7.0) * 0.55
        + sin(angle * 7.0 - progress * 11.0) * 0.30
        + cos(angle * 11.0 + progress * 9.0) * 0.15;
    float swell = life * min(42.0, reach * 0.045);
    float depth = max(0.0, radius + swell * crest) - distance;
    float reveal = smoothstep(-0.8, 0.8, depth);

    // Refraction and colour follow the same boundary that replaces the desktop.
    float width = clamp(min(screen_size.x, screen_size.y) * 0.022, 14.0, 28.0);
    float rim = exp(-pow(depth / width, 2.0)) * life;
    vec2 shift = delta / max(distance, 1.0)
        * (rim * 7.0) / max(screen_size, vec2(1.0));
    shift *= effect.content_rect_px.zw / effect.texture_size_px;
    vec2 halfPixel = 0.5 / effect.texture_size_px;
    vec2 sampleUV = clamp(uv + shift, halfPixel, vec2(1.0) - halfPixel);
    vec3 color = mix(old.rgb, texture2D(tex, sampleUV).rgb, reveal);
    float band = (1.0 - smoothstep(0.0, width, depth)) * reveal * life;
    color = mix(color, theme_accent, band * 0.88);
    float highlight = exp(-pow((depth - 3.0) / 1.8, 2.0)) * reveal * life;
    color = mix(color, mix(theme_accent, vec3(1.0), 0.35), highlight * 0.45);
    float wake = exp(-pow((depth - 14.0 - progress * 12.0) / 4.0, 2.0)) * reveal * life;
    color = mix(color, theme_accent, wake * 0.16);
    return vec4(color, 1.0);
}
