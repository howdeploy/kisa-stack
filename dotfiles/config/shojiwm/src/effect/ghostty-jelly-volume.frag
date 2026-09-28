uniform float gel_pass;
uniform float gel_padding;
uniform vec2 gel_extent;
uniform float gel_phase;
uniform vec2 gel_bend;

float boundary(vec2 p, vec2 size) {
    float unit = max(max(size.x, size.y), 1.0);
    float radius = min(22.0, min(size.x, size.y) * 0.20);
    vec2 d = abs(p / unit) - size * 0.5 / unit + radius / unit;
    return (length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - radius / unit) * unit;
}

vec2 edgeWarp(vec2 p, vec2 size) {
    vec2 q = p / max(size * 0.5, vec2(1.0));
    vec2 strip = vec2(1.0) - smoothstep(vec2(0.0), vec2(18.0), size * 0.5 - abs(p));
    vec2 wobble = vec2(
        2.6 * sin(q.y * 5.0 + gel_phase) + 0.9 * sin(q.y * 9.0 - gel_phase * 2.0),
        2.2 * sin(q.x * 5.0 - gel_phase) + 0.8 * sin(q.x * 8.0 + gel_phase * 2.0));
    return strip * (wobble + gel_bend * 0.8);
}

// Orthographic front of a rounded, thick slab. The back face is at -height.
// This closed-form surface replaces marching through an unrelated blob scene.
float surfaceHeight(vec2 p, vec2 size) {
    vec2 q = p / max(size * 0.5, vec2(1.0));
    float inside = max(0.0, -boundary(p, size));
    float bevel = clamp(min(size.x, size.y) * 0.085, 26.0, 48.0);
    float crossSection = sqrt(max(0.0, 1.0 - pow(1.0 - min(inside / bevel, 1.0), 2.0)));
    float dome = max(0.0, 1.0 - q.x * q.x) * max(0.0, 1.0 - q.y * q.y);
    float softShape = sin(q.x * 4.0 + gel_phase) * sin(q.y * 3.0 - gel_phase * 2.0);
    return crossSection * (15.0 + 9.0 * dome + 3.5 * softShape
                           + dot(gel_bend, q) * 0.4);
}

vec4 shader_main(EffectContext effect) {
    vec2 size = max(gel_extent, vec2(1.0));
    vec2 scale = effect.content_rect_px.zw / (size + gel_padding * 2.0);
    vec2 local = effect_content_px(effect) / max(scale, vec2(0.001)) - gel_padding;
    vec2 p = local - size * 0.5;

    if (gel_pass > 0.5) {
        vec2 warp = edgeWarp(p, size);
        float mask = 1.0 - smoothstep(-1.0, 0.0, boundary(p + warp, size));
        if (mask <= 0.0) return vec4(0.0);
        // Only the padded outer strip bends. The terminal's text plane stays sharp.
        vec2 uv = effect.texture_uv + warp * scale / effect.texture_size_px;
        return texture2D(tex, clamp(uv, vec2(0.0), vec2(1.0))) * mask;
    }

    float distance = boundary(p, size);
    float mask = 1.0 - smoothstep(-1.0, 0.0, distance);
    if (mask <= 0.0) return vec4(0.0);
    float height = surfaceHeight(p, size);
    vec2 slope = vec2(
        surfaceHeight(p + vec2(1.0, 0.0), size) - surfaceHeight(p - vec2(1.0, 0.0), size),
        surfaceHeight(p + vec2(0.0, 1.0), size) - surfaceHeight(p - vec2(0.0, 1.0), size)) * 0.5;
    vec3 normal = normalize(vec3(-slope, 1.0));
    vec3 ray = refract(vec3(0.0, 0.0, -1.0), normal, 1.0 / 1.38);
    float path = 2.0 * height / max(-ray.z, 0.25);
    vec2 offset = ray.xy * path;
    offset *= min(1.0, 30.0 / max(length(offset), 0.001));
    vec2 sampleUV = effect_texture_uv_from_content_px(effect, (local + offset) * scale);
    vec2 halfTexel = vec2(0.5) / effect.texture_size_px;
    vec3 scene = texture2D(tex, clamp(sampleUV, halfTexel, vec2(1.0) - halfTexel)).rgb;
    // Thickness-dependent absorption: dense violet centre, translucent thin edges.
    vec3 transmission = exp(-vec3(0.025, 0.034, 0.018) * path);
    vec3 gel = scene * transmission + vec3(0.10, 0.055, 0.17) * (1.0 - transmission);
    float rim = 1.0 - smoothstep(4.0, 52.0, -distance);
    float luminance = dot(gel, vec3(0.2126, 0.7152, 0.0722));
    gel *= min(1.0, mix(0.23, 0.40, rim) / max(luminance, 0.001));
    vec3 light = normalize(vec3(-0.65, -0.75, 1.0));
    vec3 halfLight = normalize(light + vec3(0.0, 0.0, 1.0));
    float specular = pow(max(dot(normal, halfLight), 0.0), 52.0);
    float secondLight = pow(max(dot(normal, normalize(vec3(0.7, 0.3, 0.6))), 0.0), 22.0);
    float fresnel = 0.025 + 0.975 * pow(1.0 - max(normal.z, 0.0), 5.0);
    gel += vec3(0.83, 0.78, 1.0) * (specular * mix(0.055, 0.44, rim) + fresnel * 0.20);
    gel += vec3(0.65, 0.40, 0.80) * secondLight * rim * 0.18;
    return vec4(gel * mask, mask);
}
