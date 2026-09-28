uniform vec2 water_size;
uniform vec4 window_rect;

vec4 shader_main(EffectContext effect) {
    vec4 field = texture2D(tex, effect.texture_uv);
    vec2 q = effect.texture_uv * water_size - window_rect.xy;
    // Guard against interpolation of the quarter-resolution obstacle mask.
    if (q.x >= -4.0 && q.y >= -4.0 && q.x <= window_rect.z + 4.0 && q.y <= window_rect.w + 4.0) {
        field.a = 1.0;
    }
    return field;
}
