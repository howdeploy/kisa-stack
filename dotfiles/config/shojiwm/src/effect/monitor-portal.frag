uniform float portal_progress;
uniform vec2 portal_normal;
uniform vec2 portal_center;
uniform vec2 portal_extent;

float portalHash(float n) { return fract(sin(n * 127.1 + 31.7) * 43758.5453); }

vec4 shader_main(EffectContext effect) {
    float t = clamp(portal_progress, 0.0, 1.0);
    if (t <= 0.0 || t >= 1.0) return vec4(0.0);
    vec2 point = (effect.texture_uv * effect.texture_size_px - effect.content_rect_px.xy)
                / max(effect.content_rect_px.zw, vec2(1.0)) * portal_extent - portal_center;
    vec2 tangent = vec2(-portal_normal.y, portal_normal.x);
    vec2 p = vec2(dot(point, portal_normal), dot(point, tangent));
    if (abs(p.x) > 76.0 || abs(p.y) > 116.0) return vec4(0.0);
    float life = smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.55, 1.0, t));
    float radius = length(p / vec2(5.0, 52.0 * max(life, 0.01)));
    float light = exp(-radius * radius * 2.0) * 0.72
                + exp(-abs(radius - 1.0) * 10.0) * 0.50;
    vec3 color = vec3(0.72, 0.39, 1.0);
    float alpha = min(0.85, light) * life;
    vec3 rgb = color * alpha;
    for (int i = 0; i < 18; ++i) {
        float seed = portalHash(float(i));
        float tone = portalHash(float(i) + 43.0);
        float age = fract(t * 1.7 + seed);
        float side = mod(float(i), 2.0) < 1.0 ? -1.0 : 1.0;
        vec2 center = vec2(side * (5.0 + age * (30.0 + seed * 35.0)),
            (tone - 0.5) * 88.0 + sin(age * 4.0 + seed * 6.28) * age * 20.0);
        vec2 d = abs(p - center);
        float size = 1.3 + seed * 1.8;
        float pixel = (1.0 - smoothstep(size, size + 0.7, max(d.x, d.y)))
                    * sin(age * 3.1415927) * life * 0.85;
        vec3 tint = mix(color, vec3(0.96, 0.76, 0.91), tone * 0.65);
        rgb = tint * pixel + rgb * (1.0 - pixel);
        alpha = pixel + alpha * (1.0 - pixel);
    }
    return vec4(rgb, alpha);
}
