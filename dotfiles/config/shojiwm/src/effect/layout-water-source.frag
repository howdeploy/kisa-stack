uniform vec2 water_size;
uniform vec4 source_before;
uniform vec4 source_after;
uniform float source_delta;

float submerged(vec2 p, vec4 rect) {
    vec2 d = abs(p - rect.xy - rect.zw * 0.5) - rect.zw * 0.5;
    float distanceToEdge = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
    return 1.0 - smoothstep(-10.0, 10.0, distanceToEdge);
}

vec4 shader_main(EffectContext effect) {
    vec4 state = texture2D(tex, effect.texture_uv);
    if (state.a <= 0.0 || source_delta <= 0.0) return state;
    vec2 p = effect.texture_uv * water_size;
    // Newly displaced water rises at the leading edge and falls in the wake.
    // Resize contributes too; identical rects inject exactly zero energy.
    float displaced = (submerged(p, source_after) - submerged(p, source_before))
                    * min(1.0, state.a / source_delta);
    state.r = clamp(state.r + displaced * 1.1, -4.0, 4.0);
    state.g = clamp(state.g + displaced * 14.0, -80.0, 80.0);
    return state;
}
