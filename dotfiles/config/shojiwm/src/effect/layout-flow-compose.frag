uniform sampler2D water_field;
uniform vec2 water_size;

vec4 shader_main(EffectContext effect) {
    vec2 uv = effect.texture_uv;
    vec2 local = (uv * effect.texture_size_px - effect.content_rect_px.xy)
               / max(effect.content_rect_px.zw, vec2(1.0));
    vec4 field = texture2D(water_field, local);
    float coverage = (1.0 - exp(-max(field.b, 0.0) * 1.6))
                   * (1.0 - smoothstep(0.0, 0.2, field.a));

    // Bound overlapping wakes; logical pixels stay consistent across output scales.
    vec2 pixelUv = effect.content_rect_px.zw
                 / (max(water_size, vec2(1.0)) * effect.texture_size_px);
    vec2 offset = field.rg * (7.0 / (1.0 + length(field.rg)));
    vec2 halfTexel = vec2(0.5) / effect.texture_size_px;
    // Clamp to the visible output: padding outside a monitor can be transparent.
    vec2 lower = effect.content_rect_px.xy / effect.texture_size_px + halfTexel;
    vec2 upper = (effect.content_rect_px.xy + effect.content_rect_px.zw)
               / effect.texture_size_px - halfTexel;
    vec2 sampleUv = uv + offset * pixelUv;
    vec2 blur = pixelUv * (6.0 * coverage);
    vec4 color = texture2D(tex, clamp(sampleUv, lower, upper)) * 0.4;
    color += texture2D(tex, clamp(sampleUv + vec2(blur.x, 0.0), lower, upper)) * 0.15;
    color += texture2D(tex, clamp(sampleUv - vec2(blur.x, 0.0), lower, upper)) * 0.15;
    color += texture2D(tex, clamp(sampleUv + vec2(0.0, blur.y), lower, upper)) * 0.15;
    color += texture2D(tex, clamp(sampleUv - vec2(0.0, blur.y), lower, upper)) * 0.15;
    return color * coverage;
}
