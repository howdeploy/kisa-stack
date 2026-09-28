uniform sampler2D water_field;
uniform vec2 water_size;
uniform float water_fade;

vec4 shader_main(EffectContext effect) {
    vec2 uv = effect.texture_uv;
    vec2 local = (uv * effect.texture_size_px - effect.content_rect_px.xy)
               / max(effect.content_rect_px.zw, vec2(1.0));
    vec2 cell = vec2(4.0) / max(water_size, vec2(1.0));
    float height = texture2D(water_field, local).r;
    vec2 slope = vec2(
        texture2D(water_field, local + vec2(cell.x, 0.0)).r
          - texture2D(water_field, local - vec2(cell.x, 0.0)).r,
        texture2D(water_field, local + vec2(0.0, cell.y)).r
          - texture2D(water_field, local - vec2(0.0, cell.y)).r) / 8.0;
    float coverage = clamp(length(slope) * 35.0 + abs(height) * 0.06, 0.0, 1.0) * water_fade;
    if (coverage < 0.001) return vec4(0.0);
    vec2 offset = slope * 75.0;
    offset *= min(1.0, 9.0 / max(length(offset), 0.001));
    vec2 scale = effect.content_rect_px.zw / max(water_size, vec2(1.0));
    vec2 halfTexel = vec2(0.5) / effect.texture_size_px;
    vec4 color = texture2D(tex, clamp(uv - offset * scale / effect.texture_size_px,
                                    halfTexel, vec2(1.0) - halfTexel));
    float light = clamp(dot(slope, vec2(-0.6, -0.8)) * 2.0, -0.16, 0.16);
    color.rgb *= 1.0 + light;
    color.rgb += vec3(max(0.0, light) * 0.30) * color.a;
    return color * coverage;
}
