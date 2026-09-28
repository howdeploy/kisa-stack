uniform vec2 water_size;
uniform vec4 source_before;
uniform vec4 source_after;
uniform float source_delta;

float drop(vec2 p, vec2 centre, float radius) {
    vec2 d = (p - centre) / radius;
    return exp(-dot(d, d) * 0.5);
}

float edgeDrops(vec2 p, vec2 a, vec2 b, float movement) {
    float radius = clamp(length(b - a) * 0.045, 20.0, 30.0);
    // A few broad, circular sources, not a uniformly displaced rectangle.
    return movement * (0.75 * drop(p, mix(a, b, 0.12), radius)
                     +        drop(p, mix(a, b, 0.50), radius)
                     + 0.75 * drop(p, mix(a, b, 0.88), radius));
}

vec4 shader_main(EffectContext effect) {
    vec4 state = texture2D(tex, effect.texture_uv);
    if (state.a <= 0.0 || source_delta <= 0.0) return state;
    vec2 p = effect.texture_uv * water_size;
    vec4 rect = mix(source_before, source_after, 0.5);
    vec2 a = rect.xy;
    vec2 b = rect.xy + rect.zw;
    vec2 nearDelta = source_after.xy - source_before.xy;
    vec2 farDelta = nearDelta + source_after.zw - source_before.zw;
    float impulse = edgeDrops(p, a, vec2(a.x, b.y), -nearDelta.x)
                  + edgeDrops(p, vec2(b.x, a.y), b, farDelta.x)
                  + edgeDrops(p, a, vec2(b.x, a.y), -nearDelta.y)
                  + edgeDrops(p, vec2(a.x, b.y), b, farDelta.y);
    // Drive velocity only: height evolves continuously through the wave equation.
    // Edge displacement includes speed and resizing; stationary edges add zero.
    state.g = clamp(state.g + impulse * 0.9 * min(1.0, state.a / source_delta), -80.0, 80.0);
    return state;
}
