// R: height, G: vertical velocity, B: clock, A: frame delta.
uniform float water_time;
uniform float water_substep;
uniform vec2 water_size;

vec4 shader_main(EffectContext effect) {
    vec2 uv = effect.texture_uv;
    vec2 texel = 1.0 / effect.texture_size_px;
    vec2 cell = water_size * texel;
    vec4 state = texture2D(tex, uv);
    if (water_substep < 0.5) {
        if (water_time < state.b - 0.001) return vec4(0.0, 0.0, water_time, 0.0);
        state.a = clamp(water_time - state.b, 0.0, 0.032);
        state.b = water_time;
    }
    float dt = min(state.a * 0.25, min(cell.x, cell.y) * 0.45 / 240.0);
    float left = texture2D(tex, uv - vec2(texel.x, 0.0)).r;
    float right = texture2D(tex, uv + vec2(texel.x, 0.0)).r;
    float top = texture2D(tex, uv - vec2(0.0, texel.y)).r;
    float bottom = texture2D(tex, uv + vec2(0.0, texel.y)).r;
    float diagonal = texture2D(tex, uv + texel).r
                   + texture2D(tex, uv - texel).r
                   + texture2D(tex, uv + vec2(texel.x, -texel.y)).r
                   + texture2D(tex, uv + vec2(-texel.x, texel.y)).r;
    // Nine-point stencil reduces the grid-axis bias of circular wave fronts.
    float laplacian = (left + right - 2.0 * state.r) / (cell.x * cell.x)
                    + (top + bottom - 2.0 * state.r) / (cell.y * cell.y)
                    + (diagonal - 2.0 * (left + right + top + bottom) + 4.0 * state.r)
                      / (3.0 * dot(cell, cell));
    vec2 p = uv * water_size;
    float edge = min(min(p.x, p.y), min(water_size.x - p.x, water_size.y - p.y));
    float damping = 3.6 + 10.0 * (1.0 - smoothstep(0.0, 40.0, edge));
    state.g = (state.g + 57600.0 * laplacian * dt) * exp(-damping * dt);
    state.r += state.g * dt;
    return state;
}
