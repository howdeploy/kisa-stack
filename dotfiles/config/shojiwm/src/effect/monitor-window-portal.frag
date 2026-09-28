uniform float portal_time;
uniform float portal_opacity;
uniform vec2 portal_normal;
uniform vec2 portal_center;
uniform vec2 portal_extent;
uniform float portal_half_length;

float portalHash(float n) { return fract(sin(n * 127.1 + 31.7) * 43758.5453); }

vec4 shader_main(EffectContext effect) {
    if (portal_opacity <= 0.0) return vec4(0.0);
    vec2 point = (effect.texture_uv * effect.texture_size_px - effect.content_rect_px.xy)
                / max(effect.content_rect_px.zw, vec2(1.0)) * portal_extent - portal_center;
    vec2 tangent = vec2(-portal_normal.y, portal_normal.x);
    vec2 p = vec2(dot(point, portal_normal), dot(point, tangent));
    if (abs(p.x) > 80.0 || abs(p.y) > portal_half_length + 36.0) return vec4(0.0);
    float end = 1.0 - smoothstep(max(0.0, portal_half_length - 8.0), portal_half_length + 8.0, abs(p.y));
    float core = (1.0 - smoothstep(3.0, 10.0, abs(p.x))) * end;
    float glow = exp(-abs(p.x) / 16.0) * end * 0.28;
    float alpha = min(0.92, core * 0.82 + glow);
    vec3 color = mix(vec3(0.57, 0.22, 0.94), vec3(0.86, 0.65, 1.0), core);
    vec3 rgb = color * alpha;

    // Constant particle density along the window edge, with six local candidates.
    float segment = floor((p.y + portal_half_length) / 22.0);
    for (int i = -1; i <= 1; ++i) {
        float row = segment + float(i);
        float originY = (row + 0.5) * 22.0 - portal_half_length;
        if (abs(originY) > portal_half_length) continue;
        for (int sideIndex = 0; sideIndex < 2; ++sideIndex) {
            float side = sideIndex == 0 ? -1.0 : 1.0;
            float seed = portalHash(row * 2.0 + float(sideIndex));
            float tone = portalHash(row * 2.0 + float(sideIndex) + 43.0);
            float age = fract(portal_time + seed);
            vec2 particle = vec2(side * (7.0 + age * (32.0 + seed * 30.0)),
                originY + sin(age * 4.0 + seed * 6.28) * age * 12.0);
            vec2 d = abs(p - particle);
            float size = 1.5 + seed * 2.0;
            float pixel = (1.0 - smoothstep(size, size + 0.7, max(d.x, d.y)))
                          * sin(age * 3.1415927) * 0.9;
            vec3 tint = mix(vec3(0.72, 0.39, 1.0), vec3(0.96, 0.76, 0.91), tone * 0.65);
            rgb = tint * pixel + rgb * (1.0 - pixel);
            alpha = pixel + alpha * (1.0 - pixel);
        }
    }
    return vec4(rgb, alpha) * portal_opacity;
}
