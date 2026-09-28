// A soft crest travels along the moving edge and fades before the window centre.
uniform float jelly_progress;
uniform vec2 jelly_contact;
uniform vec2 jelly_normal;
uniform float jelly_strength;
uniform vec2 jelly_extent;

vec4 shader_main(EffectContext effect) {
    float time = clamp(jelly_progress, 0.0, 1.0);
    // Let the edge yield during deceleration, without another whole-window kick.
    if (time <= 0.30 || time >= 1.0) return texture2D(tex, effect.texture_uv);

    vec2 scale = max(effect.content_rect_px.zw, vec2(1.0)) / max(jelly_extent, vec2(1.0));
    vec2 extent = max(jelly_extent - vec2(32.0), vec2(1.0));
    vec2 point = (effect.texture_uv * effect.texture_size_px - effect.content_rect_px.xy)
               / scale - vec2(16.0);
    vec2 delta = point - jelly_contact * extent;
    vec2 tangent = vec2(-jelly_normal.y, jelly_normal.x);
    float along = abs(dot(delta, tangent));
    float depth = min(90.0, dot(extent, abs(jelly_normal)) * 0.18);
    float edgeWeight = 1.0 - smoothstep(0.0, depth, max(0.0, dot(delta, jelly_normal)));
    if (edgeWeight <= 0.0) return texture2D(tex, effect.texture_uv);

    float reach = dot(extent, abs(tangent)) * 0.5;
    float width = max(24.0, reach * 0.75);
    float front = ((time - 0.30) / 0.70) * (reach + width);
    float age = (front - along) / width;
    if (age <= 0.0 || age >= 1.0) return texture2D(tex, effect.texture_uv);

    // One rounded bend and a smooth release, with no reflected oscillations.
    float pulse = sin(age * 3.1415927);
    pulse *= pulse;
    float attenuation = 1.0 / (1.0 + along / max(reach, 1.0));
    vec2 displacement = jelly_normal * jelly_strength * pulse * edgeWeight * attenuation;
    vec2 uv = effect.texture_uv - displacement * scale / effect.texture_size_px;
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return vec4(0.0);
    return texture2D(tex, uv);
}
