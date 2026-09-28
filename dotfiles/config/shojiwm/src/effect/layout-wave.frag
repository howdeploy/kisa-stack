uniform float wave_progress;
uniform float wave_direction;
uniform vec2 wave_size;

vec4 shader_main(EffectContext effect) {
    float time = clamp(wave_progress, 0.0, 1.0);
    vec2 uv = effect.texture_uv;
    if (time <= 0.0 || time >= 1.0) return vec4(0.0);
    vec2 local = (uv * effect.texture_size_px - effect.content_rect_px.xy)
               / max(effect.content_rect_px.zw, vec2(1.0));
    float x = wave_direction > 0.0 ? local.x : 1.0 - local.x;
    float front = mix(-0.18, 1.18, min(time / 0.80, 1.0));
    float bend = sin(local.y * 5.0 + time * 2.0) * 0.025;
    float distanceToFront = x - front - bend;
    float band = exp(-pow(distanceToFront / 0.065, 2.0));
    float crest = exp(-pow(distanceToFront / 0.014, 2.0));
    float envelope = smoothstep(0.0, 0.10, time) * (1.0 - smoothstep(0.72, 1.0, time));
    vec2 scale = effect.content_rect_px.zw / max(wave_size, vec2(1.0));
    vec2 offset = vec2(wave_direction, 0.12 * cos(local.y * 5.0))
                * sin(distanceToFront * 32.0) * band * envelope * 2.0;
    vec2 halfTexel = vec2(0.5) / effect.texture_size_px;
    vec4 color = texture2D(tex, clamp(uv - offset * scale / effect.texture_size_px,
                                    halfTexel, vec2(1.0) - halfTexel));
    vec3 tint = mix(vec3(0.796, 0.651, 0.969), vec3(0.961, 0.761, 0.906), local.y);
    color.rgb = mix(color.rgb, tint * color.a, (0.06 * band + 0.10 * crest) * envelope);
    // Only the moving ribbon covers the scene; the rest stays live underneath.
    return color * (band * envelope);
}
