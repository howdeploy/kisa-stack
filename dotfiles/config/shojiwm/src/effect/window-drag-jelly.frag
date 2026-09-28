uniform float drag_progress;
uniform vec2 drag_bend;
uniform vec2 drag_grab;
uniform vec2 drag_extent;

vec4 shader_main(EffectContext effect) {
    float t = clamp(drag_progress, 0.0, 1.0);
    vec2 scale = max(effect.content_rect_px.zw, vec2(1.0)) / max(drag_extent, vec2(1.0));
    vec2 extent = max(drag_extent - vec2(24.0), vec2(1.0));
    vec2 point = (effect.texture_uv * effect.texture_size_px - effect.content_rect_px.xy)
                / scale - vec2(12.0);
    vec2 uvWindow = point / extent;
    // Keep the grabbed point fixed; the rest of the material yields gently.
    float weight = smoothstep(0.0, 0.85, length(uvWindow - drag_grab));
    float settle = exp(-6.0 * t) * cos(10.0 * t) * (1.0 - smoothstep(0.7, 1.0, t));
    vec2 bend = drag_bend * weight * settle;
    vec2 uv = effect.texture_uv - bend * scale / effect.texture_size_px;
    if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return vec4(0.0);
    return texture2D(tex, uv);
}
