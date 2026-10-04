uniform float snow_phase_v2;
// Change the uniform layout once to retire the installed compositor's v1 program.
#define snow_phase snow_phase_v2
uniform float snow_near;
uniform vec2 snow_extent;
uniform vec2 snow_origin;
uniform vec4 snow_desktop;

const float SNOW_TAU = 6.28318530718;

vec2 snowHash(vec2 p) {
    vec3 h = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    h += dot(h, h.yzx + 33.33);
    return fract((h.xx + h.yz) * h.zy);
}

vec2 snowDrift(float phase) {
    float stepTime = phase * 12.0;
    float stepId = floor(stepTime);
    float t = fract(stepTime);
    // Interpolate displacement, not velocity * time: gusts cannot teleport flakes.
    t = t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
    vec2 a = snowHash(vec2(mod(stepId, 12.0), 41.7));
    vec2 b = snowHash(vec2(mod(stepId + 1.0, 12.0), 41.7));
    return (mix(a, b, t) * 2.0 - 1.0) * vec2(580.0, 85.0);
}

float snowMist(vec2 p) {
    vec2 cell = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    // Broad, overlapping density variations; wrap vertical motion with the clock.
    float a = snowHash(vec2(cell.x, mod(cell.y, 16.0))).x;
    float b = snowHash(vec2(cell.x + 1.0, mod(cell.y, 16.0))).x;
    float c = snowHash(vec2(cell.x, mod(cell.y + 1.0, 16.0))).x;
    float d = snowHash(vec2(cell.x + 1.0, mod(cell.y + 1.0, 16.0))).x;
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float snowSegment(vec2 p, vec2 a, vec2 b, float width) {
    vec2 v = b - a;
    return length(p - a - v * clamp(dot(p - a, v) / dot(v, v), 0.0, 1.0)) - width;
}

float snowClump(vec2 p, vec2 seed) {
    float edge = length(p) - mix(0.27, 0.38, seed.y);
    // Uneven, thick crystal arms fuse into a small aggregate, not a perfect star.
    for (int arm = 0; arm < 6; ++arm) {
        float a = float(arm);
        float variation = fract(seed.x * 17.73 + a * 0.618034);
        float angle = a * SNOW_TAU / 6.0;
        vec2 direction = vec2(cos(angle), sin(angle));
        vec2 side = vec2(-direction.y, direction.x);
        float reach = mix(0.44, 0.91, variation);
        float width = mix(0.10, 0.18, fract(seed.y * 11.7 + a * 0.381966));
        edge = min(edge, snowSegment(p, vec2(0.0), direction * reach, width));
        if (variation > 0.38) {
            vec2 fork = direction * reach * 0.52;
            float branch = mix(0.17, 0.29, variation);
            edge = min(edge, snowSegment(p, fork,
                fork + (direction * 0.5 + side * 0.866025) * branch, width * 0.72));
            edge = min(edge, snowSegment(p, fork,
                fork + (direction * 0.5 - side * 0.866025) * branch, width * 0.72));
        }
    }
    // Two compact grains fill some gaps differently on each flake.
    vec2 q = abs(p - vec2(0.24 + seed.y * 0.18, -0.18));
    edge = min(edge, max(q.x * 0.866025 + q.y * 0.5, q.y) - 0.28);
    q = abs(p + vec2(0.20, 0.16 + seed.x * 0.17));
    return min(edge, max(q.x * 0.5 + q.y * 0.866025, q.x) - 0.24);
}

vec2 snowPlane(vec2 point, float plane, vec2 drift, float faceGust, vec2 gustCenter) {
    // At most three bands of nine candidate cells. Keep depth, visible alpha,
    // and snow-only occlusion separate: defocus must not reveal sharp flakes behind.
    vec3 particles[27];
    int count = 0;
    // SnowIsFalling's depth bands + Snow Bokeh's local scattering, with no
    // scene bloom/tonemapping. Three sparse far bands and two foreground bands.
    for (int band = 0; band < 6; ++band) {
        if (plane > 0.5 && band >= 2) continue;
        if (plane < 0.5 && band < 3) continue;
        float depth = float(band);
        float cellSize = mix(90.0 + depth * 14.0, 200.0 + depth * 70.0, plane);
        float rows = mix(43.0 - depth * 2.0, 24.0 - depth * 2.0, plane);
        float response = mix(0.45 + depth * 0.085, 1.25 + depth * 0.25, plane);
        float expansion = 1.0 + faceGust * mix(0.025 + depth * 0.007,
            0.18 + depth * 0.06, plane);
        vec2 wind = drift * response;
        wind.x += response * 14.0 * sin(SNOW_TAU * snow_phase * 9.0 + depth * 0.7);
        vec2 blownPoint = gustCenter + (point - gustCenter) / expansion;
        vec2 grid = (blownPoint - wind - vec2(0.0, snow_phase * rows * cellSize)) / cellSize;
        vec2 cell = floor(grid);

        // Integer row periods and sway frequencies preserve the seamless clock loop.
        for (int y = -1; y <= 1; ++y) {
            for (int x = -1; x <= 1; ++x) {
                vec2 id = cell + vec2(float(x), float(y));
                vec2 seed = snowHash(vec2(id.x, mod(id.y, rows))
                    + plane * 137.0 + depth * 53.0);
                vec2 detail = snowHash(seed * 83.0 + 7.0);
                if (detail.y > mix(0.94, 0.82, plane)) continue;

                vec2 center = id + 0.15 + seed * 0.70;
                center.x += 0.16 * sin(SNOW_TAU * (snow_phase * (6.0 + depth) + detail.x));
                center.y += 0.04 * sin(SNOW_TAU * (snow_phase * 4.0 + seed.y));
                vec2 d = (grid - center) * cellSize;
                float radius = mix(mix(3.1, 4.4, detail.x) + depth * 0.23,
                    mix(6.5, 10.0, detail.x) + depth * 1.8, plane);
                // Each flake travels in depth on its own seamless 22–40 second cycle.
                // Perspective size and focus share that distance, never separate pulses.
                float focusCycles = 6.0 + floor(seed.x * 6.0);
                float approach = 0.5 + 0.5 * sin(SNOW_TAU
                    * (snow_phase * focusCycles + seed.y));
                float distanceToEye = mix(1.55, 0.55, approach);
                radius *= mix(1.0, 1.0 / distanceToEye, plane);
                float defocus = smoothstep(0.10, 1.0, approach);
                float softness = mix(1.65 - depth * 0.24,
                    0.55 + defocus * (6.0 + depth * 1.5) + faceGust * 2.2, plane);
                float bound = radius * 1.5 + softness * 3.0;
                if (max(abs(d.x), abs(d.y)) > bound) continue;

                float radialDistance = length(d);
                float angle = SNOW_TAU * (seed.x + snow_phase * (2.0 + depth));
                float c = cos(angle), s = sin(angle);
                vec2 p = mat2(c, -s, s, c) * d / radius;
                p.y *= mix(0.82, 1.18, seed.y);
                float edge = snowClump(p, seed) * radius;
                float coverage = 1.0 - smoothstep(-softness, softness, edge);
                float opacity = mix(0.23 + depth * 0.085, 0.96, plane)
                    * mix(0.86, 1.0, detail.x);
                // A focused core stays white; defocus spreads it and lowers its peak.
                opacity *= radius * radius / (radius * radius + softness * softness);
                float spread = radius * 0.65 + softness;
                float halo = exp(-radialDistance * radialDistance / (2.0 * spread * spread))
                    * mix(0.09 - depth * 0.012, 0.075 * defocus + faceGust * 0.025, plane);
                halo *= 1.0 - smoothstep(bound * 0.78, bound, radialDistance);
                float flake = clamp(coverage * opacity + halo * (1.0 - coverage), 0.0, 1.0);
                float occlusion = max(coverage, plane * defocus * (1.0
                    - smoothstep(radius * 0.4, radius * 1.4 + softness, radialDistance)));
                particles[count] = vec3(mix(4.0 + (5.0 - depth) * 0.7,
                    distanceToEye, plane), flake, occlusion);
                count++;
            }
        }
    }
    float alpha = 0.0;
    float occlusion = 0.0;
    for (int i = 0; i < 27; ++i) {
        if (i >= count) break;
        float visible = particles[i].y;
        for (int j = 0; j < 27; ++j) {
            if (j >= count) break;
            // Equal-depth crossings blend smoothly instead of popping their order.
            float inFront = smoothstep(0.0, 0.08, particles[i].x - particles[j].x);
            visible *= 1.0 - particles[j].z * inFront;
        }
        alpha += visible * (1.0 - alpha);
        occlusion += particles[i].z * (1.0 - occlusion);
    }
    return vec2(alpha, occlusion);
}

vec4 shader_main(EffectContext effect) {
    vec2 local = (effect.texture_uv * effect.texture_size_px - effect.content_rect_px.xy)
        / max(effect.content_rect_px.zw, vec2(1.0)) * snow_extent;
    vec2 point = snow_origin + local;
    vec2 drift = snowDrift(snow_phase);
    float gustTime = snow_phase * 3.0;
    vec2 gustSeed = snowHash(vec2(mod(floor(gustTime), 3.0), 97.3));
    float gustPhase = fract(gustTime);
    float gustStart = mix(0.10, 0.30, gustSeed.x);
    float faceGust = smoothstep(gustStart, gustStart + 0.05, gustPhase)
        * (1.0 - smoothstep(gustStart + 0.07, gustStart + 0.27, gustPhase));
    vec2 gustCenter = snow_desktop.xy + snow_desktop.zw * (0.20 + gustSeed * 0.60);
    // Evaluate the same foreground at the same desktop point on both surfaces.
    vec2 nearSnow = snowPlane(point, 1.0, drift, faceGust, gustCenter);
    float alpha = nearSnow.x;
    if (snow_near < 0.5) {
        vec2 mistPoint = (point - drift * 0.35) / vec2(520.0, 340.0)
            - vec2(0.0, snow_phase * 16.0);
        float mist = 0.035 + 0.055 * snowMist(mistPoint)
            + 0.025 * snowMist(mistPoint * 2.0 + vec2(17.2, 5.4));
        float farSnow = snowPlane(point, 0.0, drift, faceGust, gustCenter).x;
        alpha = mist + farSnow * (1.0 - nearSnow.y) * (1.0 - mist);
    }
    // Occlusion removes only snow; windows/widgets keep their own composition.
    return vec4(vec3(0.985, 0.995, 1.0) * alpha, alpha);
}
