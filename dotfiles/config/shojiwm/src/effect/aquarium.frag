precision highp float;
uniform float aquarium_enabled;
uniform float aquarium_phase;
uniform float aquarium_plane;
uniform vec2 aquarium_origin;
uniform vec2 aquarium_extent;
// Only the thumbnail renderer uses window bounds; the live mist has real z-order.
uniform float aquarium_window_count;
uniform vec4 aquarium_windows[16];

const float WATER_TAU = 6.28318530718;

vec2 waterHash(vec2 p) {
    vec3 h = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    h += dot(h, h.yzx + 33.33);
    return fract((h.xx + h.yz) * h.zy);
}

float waterCaustics(vec2 p, float t) {
    vec2 q = p / 150.0;
    q += vec2(sin(q.y * 1.8 + t * 3.0), cos(q.x * 1.6 - t * 2.0)) * 0.23;
    float ridge = abs(sin(q.x * 2.4 + q.y + t * 4.0)
        + sin(q.y * 2.9 - q.x * 0.7 - t * 3.0) * 0.72
        + sin(q.x * 1.7 - q.y * 1.9 + t * 5.0) * 0.38);
    return 1.0 - smoothstep(0.025, 0.19, ridge);
}

vec4 waterFog(vec2 p, float t) {
    float density = 0.5 + 0.25 * sin(p.x / 650.0 + t * 2.0)
        + 0.25 * sin(p.y / 510.0 - p.x / 900.0 - t * 3.0);
    float shaft = pow(0.5 + 0.5 * sin(p.x / 340.0 + p.y / 810.0 + t), 8.0);
    float alpha = 0.045 + density * 0.035 + shaft * 0.012;
    vec3 tint = mix(vec3(0.10, 0.36, 0.43), vec3(0.28, 0.58, 0.62), shaft);
    tint += waterCaustics(p, t) * vec3(0.05, 0.07, 0.07);
    return vec4(tint * alpha, alpha);
}

vec4 shader_main(EffectContext effect) {
    if (aquarium_enabled < 0.5) return texture2D(tex, effect.texture_uv);
    vec2 extent = max(aquarium_extent, vec2(1.0));
    vec2 local = effect.texture_uv * extent;
    vec2 point = aquarium_origin + local;
    float t = WATER_TAU * aquarium_phase;
    if (aquarium_plane < 0.5) return waterFog(point, t);

    // Sub-pixel to roughly one logical pixel of current: text stays readable.
    vec2 wave = vec2(
        sin(point.y / 190.0 + t * 5.0) + 0.4 * sin((point.x + point.y) / 310.0 - t * 3.0),
        cos(point.x / 230.0 - t * 4.0) + 0.4 * cos((point.x - point.y) / 370.0 + t * 2.0));
    vec2 displacement = wave * 0.70;
    float light = waterCaustics(point, t) * 0.028;
    float shimmer = pow(0.5 + 0.5 * sin(point.x / 510.0 + point.y / 640.0 + t * 3.0), 18.0);
    light += shimmer * 0.016;

    // One sparse grid, nine nearby cells: ascending transparent bubbles with a lens.
    vec2 cellSize = vec2(240.0, 260.0);
    vec2 grid = (point + vec2(0.0, aquarium_phase * 4160.0)) / cellSize;
    vec2 cell = floor(grid);
    for (int y = -1; y <= 1; ++y) {
        for (int x = -1; x <= 1; ++x) {
            vec2 id = cell + vec2(float(x), float(y));
            vec2 seed = waterHash(vec2(id.x, mod(id.y, 16.0)));
            if (seed.x > 0.38) continue;
            vec2 center = id + 0.25 + seed * 0.5;
            center.x += 0.05 * sin(t * (3.0 + floor(seed.y * 3.0)) + seed.x * WATER_TAU);
            vec2 delta = (grid - center) * cellSize;
            float radius = mix(3.0, 10.0, seed.y * seed.y);
            if (max(abs(delta.x), abs(delta.y)) > radius + 2.0) continue;
            float distance = length(delta);
            float interior = 1.0 - smoothstep(radius - 1.0, radius + 1.0, distance);
            float rim = 1.0 - smoothstep(0.5, 1.5, abs(distance - radius));
            vec2 highlight = (delta / radius + vec2(0.32, 0.42)) * 4.0;
            float glint = exp(-dot(highlight, highlight)) * interior;
            displacement += delta * 0.24 * interior * max(0.0, 1.0 - distance / radius);
            light += rim * (0.07 + 0.045 * clamp(-delta.y / radius, 0.0, 1.0)) + glint * 0.28;
        }
    }
    vec2 edge = smoothstep(vec2(0.0), vec2(0.018), effect.texture_uv)
        * smoothstep(vec2(0.0), vec2(0.018), 1.0 - effect.texture_uv);
    vec2 warpedUv = clamp(effect.texture_uv + displacement * edge.x * edge.y / extent, 0.0, 1.0);
    vec4 source = texture2D(tex, warpedUv);

    // Reconstruct the rear plane for thumbnails without fogging their window interiors.
    if (aquarium_plane > 1.5) {
        vec2 samplePoint = warpedUv * extent;
        float background = 1.0;
        for (int i = 0; i < 16; ++i) {
            if (float(i) >= aquarium_window_count) break;
            vec4 rect = aquarium_windows[i];
            vec2 inside = step(rect.xy, samplePoint) * step(samplePoint, rect.xy + rect.zw);
            background *= 1.0 - inside.x * inside.y;
        }
        vec4 fog = waterFog(aquarium_origin + samplePoint, t);
        source.rgb = source.rgb * (1.0 - fog.a * background) + fog.rgb * source.a * background;
    }
    vec3 tint = vec3(0.62, 0.90, 0.96);
    vec3 color = source.rgb + (vec3(source.a) - source.rgb) * tint * clamp(light, 0.0, 0.4);
    return vec4(clamp(color, vec3(0.0), vec3(source.a)), source.a);
}
