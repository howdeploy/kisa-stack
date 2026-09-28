uniform float drag_progress;
uniform vec2 drag_bend;
uniform vec2 drag_velocity;
uniform vec2 drag_grab;
uniform vec2 drag_extent;

vec4 shader_main(EffectContext effect) {
    float progress = clamp(drag_progress, 0.0, 1.0);
    float t = progress * 0.6;
    vec2 scale = max(effect.content_rect_px.zw, vec2(1.0)) / max(drag_extent, vec2(1.0));
    vec2 extent = max(drag_extent - vec2(48.0), vec2(1.0));
    vec2 point = (effect.texture_uv * effect.texture_size_px - effect.content_rect_px.xy)
                / scale - vec2(24.0);
    float weight = smoothstep(0.0, 0.65, length(point / extent - drag_grab));
    vec2 spring = exp(-8.0 * t) * (drag_bend * cos(20.0 * t)
                  + (drag_velocity + 8.0 * drag_bend) / 20.0 * sin(20.0 * t));
    vec2 bend = clamp(spring, vec2(-14.0), vec2(14.0)) * weight
                * (1.0 - smoothstep(0.8, 1.0, progress));
    vec2 uv = effect.texture_uv - bend * scale / effect.texture_size_px;
    if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return vec4(0.0);
    return texture2D(tex, uv);
}
