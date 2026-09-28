// A travelling elastic wave deforms both the silhouette and the captured pixels.
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
    float along = dot(point, axis) / max(abs(axis.x) + abs(axis.y), 0.001);
    float across = dot(point, tangent);

    // Arrive near the first geometric overshoot, then travel from the leading
    // edge through the body. Different points recoil at different times.
    float distanceFromImpact = clamp((1.0 - along) * 0.5, 0.0, 1.0);
    float age = time - (0.20 + distanceFromImpact * 0.18);
    float envelope = smoothstep(0.0, 0.045, age) * exp(-max(age, 0.0) * 9.0)
                   * (1.0 - smoothstep(0.65, 1.0, time));
    float wave = sin(age * 16.0);
    float crossWave = sin(age * 16.0 - 0.7) * sin(across * 2.4);
    vec2 deformation = axis * wave * (0.78 + 0.30 * cos(across * 3.1415927))
                     + tangent * crossWave * 0.48;
    vec2 scale = size / max(jelly_extent, vec2(1.0));
    vec2 displacement = deformation * jelly_strength * envelope * scale;
    vec2 uv = effect.texture_uv - displacement / effect.texture_size_px;
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return vec4(0.0);
    return texture2D(tex, uv);
}
