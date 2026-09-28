// One inverse warp for the full captured window: SSD border and client together.
uniform float jelly_progress;
uniform vec2 jelly_direction;
uniform float jelly_strength;
uniform vec2 jelly_extent;

vec4 shader_main(EffectContext effect) {
    float time = clamp(jelly_progress, 0.0, 1.0);
    if (time <= 0.0 || time >= 1.0) return texture2D(tex, effect.texture_uv);

    vec2 size = max(effect.content_rect_px.zw, vec2(1.0));
    vec2 position = effect.texture_uv * effect.texture_size_px - effect.content_rect_px.xy;
    vec2 point = (position / size - 0.5) * 2.0;
    vec2 axis = jelly_direction / max(length(jelly_direction), 0.001);
    vec2 tangent = vec2(-axis.y, axis.x);
    float along = dot(point, axis);
    float across = dot(point, tangent);
    float projection = along / max(abs(axis.x) + abs(axis.y), 0.001);

    // Short compression during travel lives in the texture, not client geometry.
    float compression = sin(3.1415927 * clamp(time / 0.42, 0.0, 1.0));
    vec2 strain = (-axis * along * 0.70 + tangent * across * 0.35) * compression;

    // The impact crosses the sheet near the positional overshoot. Spatial modes
    // bend rows and edges differently; this is not a whole-window translation.
    float arrival = 0.36 + clamp((1.0 - projection) * 0.5, 0.0, 1.0) * 0.16;
    float age = time - arrival;
    float envelope = smoothstep(0.0, 0.025, age) * exp(-max(age, 0.0) * 6.0)
                   * (1.0 - smoothstep(0.82, 1.0, time));
    float oscillation = sin(age * 30.0);
    float bend = oscillation * (0.45 + 0.55 * cos(across * 3.1415927));
    float shear = sin(age * 30.0 - 0.8) * sin(along * 3.6 + across * 1.2);
    vec2 ripple = (axis * bend + tangent * shear * 0.65) * envelope;

    vec2 scale = size / max(jelly_extent, vec2(1.0));
    vec2 displacement = (strain + ripple) * jelly_strength * scale;
    vec2 uv = effect.texture_uv - displacement / effect.texture_size_px;
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return vec4(0.0);
    return texture2D(tex, uv);
}
