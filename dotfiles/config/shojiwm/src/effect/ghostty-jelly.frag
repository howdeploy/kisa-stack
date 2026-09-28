float roundedDistance(vec2 p, vec2 halfSize, float radius) {
    vec2 d = abs(p) - halfSize + radius;
    return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - radius;
}

vec4 shader_main(EffectContext effect) {
    vec2 size = max(effect.content_rect_px.zw, vec2(1.0));
    vec2 p = effect_content_px(effect) - size * 0.5;
    vec2 q = p / size;
    // Normalize SDF inputs to avoid large squared intermediates on mediump GPUs.
    float unit = max(size.x, size.y);
    float radius = min(10.0, min(size.x, size.y) * 0.25);
    float distance = roundedDistance(p / unit, size * 0.5 / unit, radius / unit) * unit;
    float mask = 1.0 - smoothstep(-1.0, 0.0, distance);
    if (mask <= 0.0) return vec4(0.0);
    float inside = max(-distance, 0.0);
    float bevelWidth = clamp(min(size.x, size.y) * 0.08, 24.0, 48.0);
    float rim = 1.0 - smoothstep(0.0, bevelWidth, inside);
    vec2 gradient = vec2(
        roundedDistance((p + vec2(1.0, 0.0)) / unit, size * 0.5 / unit, radius / unit)
          - roundedDistance((p - vec2(1.0, 0.0)) / unit, size * 0.5 / unit, radius / unit),
        roundedDistance((p + vec2(0.0, 1.0)) / unit, size * 0.5 / unit, radius / unit)
          - roundedDistance((p - vec2(0.0, 1.0)) / unit, size * 0.5 / unit, radius / unit)) * unit * 0.5;
    // Broad, stationary variations in thickness, without animated noise under text.
    float thickness = sin(q.x * 6.0 + q.y * 2.0) * sin(q.y * 5.0 - q.x * 1.5);
    vec2 offset = gradient * (rim * 9.0 + rim * rim * 7.0)
                + q * (2.0 + thickness * 0.8);
    vec2 sampleUV = effect_texture_uv_from_content_px(effect, p + size * 0.5 - offset);
    vec2 halfTexel = vec2(0.5) / effect.texture_size_px;
    vec3 scene = texture2D(tex, clamp(sampleUV, halfTexel, vec2(1.0) - halfTexel)).rgb;
    float density = mix(0.70, 0.43, rim) + thickness * 0.025;
    vec3 gel = mix(scene * vec3(0.78, 0.68, 0.90), vec3(0.12, 0.085, 0.17), density);

    // Keep the centre dark even over white windows; the brighter rim is peripheral.
    float luminance = dot(gel, vec3(0.2126, 0.7152, 0.0722));
    float limit = mix(0.23, 0.34, rim);
    gel *= min(1.0, limit / max(luminance, 0.001));
    vec3 normal = normalize(vec3(gradient * rim * 0.95, 1.0));
    vec3 light = normalize(vec3(-0.55, -0.65, 1.0));
    float gloss = pow(max(dot(normal, light), 0.0), 36.0) * rim;
    float lip = exp(-inside / 2.4) * max(dot(gradient, normalize(vec2(-0.55, -0.65))), 0.0);
    gel += vec3(0.80, 0.73, 0.98) * (gloss * 0.22 + lip * 0.16);
    gel *= 1.0 - rim * 0.07;
    return vec4(gel * mask, mask);
}
