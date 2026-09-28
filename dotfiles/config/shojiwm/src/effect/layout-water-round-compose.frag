uniform sampler2D water_field;
uniform vec2 water_size;
uniform float water_fade;

vec4 shader_main(EffectContext effect) {
    vec2 uv = effect.texture_uv;
    vec2 local = (uv * effect.texture_size_px - effect.content_rect_px.xy)
               / max(effect.content_rect_px.zw, vec2(1.0));
    // A wider normal estimate suppresses fine grid ripples without blurring apps.
    vec2 sampleStep = vec2(8.0) / max(water_size, vec2(1.0));
    vec2 slope = vec2(
        texture2D(water_field, local + vec2(sampleStep.x, 0.0)).r
          - texture2D(water_field, local - vec2(sampleStep.x, 0.0)).r,
        texture2D(water_field, local + vec2(0.0, sampleStep.y)).r
          - texture2D(water_field, local - vec2(0.0, sampleStep.y)).r) / 16.0;
    float coverage = smoothstep(0.001, 0.020, length(slope)) * water_fade;
    if (coverage < 0.001) return vec4(0.0);
    vec2 offset = slope * 75.0;
    offset *= min(1.0, 9.0 / max(length(offset), 0.001));
    vec2 scale = effect.content_rect_px.zw / max(water_size, vec2(1.0));
    vec2 halfTexel = vec2(0.5) / effect.texture_size_px;
    vec4 color = texture2D(tex, clamp(uv - offset * scale / effect.texture_size_px,
                                    halfTexel, vec2(1.0) - halfTexel));
    vec3 normal = normalize(vec3(-slope * 3.0, 1.0));
    vec3 light = normalize(vec3(0.2, -0.5, 0.7));
    float diffuse = clamp(dot(normal, light) / light.z, 0.82, 1.18);
    float specular = pow(max(0.0, -reflect(light, normal).z), 32.0);
    float flatSpecular = pow(light.z, 32.0);
    color.rgb = color.rgb * diffuse + vec3(max(0.0, specular - flatSpecular) * 0.20) * color.a;
    return color * coverage;
}
