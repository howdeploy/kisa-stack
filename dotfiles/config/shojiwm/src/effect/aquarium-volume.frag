precision highp float;
uniform float aquarium_enabled;
uniform float aquarium_phase;
uniform float aquarium_plane;
uniform vec2 aquarium_origin;
uniform vec2 aquarium_extent;
uniform float aquarium_window_count;
uniform vec4 aquarium_windows[16];

const float TAU = 6.28318530718;
const float TANK_DEPTH = 0.72;
const float GLASS_THICKNESS = 0.016;
const float CAMERA_DISTANCE = 1.65;
const float GLASS_IOR = 1.52;
const float WATER_IOR = 1.333;

vec2 aquariumHash(vec2 p) {
    vec3 h = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    h += dot(h, h.yzx + 33.33);
    return fract((h.xx + h.yz) * h.zy);
}

vec4 aquariumSample(vec2 uv) {
    return texture2D(tex, clamp(uv, vec2(0.0), vec2(1.0)));
}

vec4 aquariumBlur(vec2 uv, float radius, vec2 extent) {
    vec2 offset = radius / extent;
    return aquariumSample(uv) * 0.5
        + (aquariumSample(uv + vec2(offset.x, 0.0))
        + aquariumSample(uv - vec2(offset.x, 0.0))
        + aquariumSample(uv + vec2(0.0, offset.y))
        + aquariumSample(uv - vec2(0.0, offset.y))) * 0.125;
}

vec3 aquariumCurrent(vec3 p, float t) {
    return vec3(
        sin(p.y * 5.0 + p.z * 3.0 + t * 3.0)
            + 0.35 * sin(p.x * 3.0 - p.z * 4.0 - t * 2.0),
        cos(p.x * 4.0 - p.z * 5.0 - t * 2.0)
            + 0.35 * sin(p.y * 3.0 + p.z * 2.0 + t),
        0.0);
}

vec3 aquariumEnvironment(vec3 direction) {
    vec2 q = direction.xy / max(0.25, abs(direction.z));
    vec2 windowDistance = abs(q - vec2(-0.28, 0.23)) - vec2(0.19, 0.085);
    float windowLight = 1.0 - smoothstep(-0.015, 0.045, max(windowDistance.x, windowDistance.y));
    float pane = 1.0 - 0.25 * exp(-abs(q.x + 0.28) * 180.0);
    vec2 stripDistance = abs(q - vec2(0.40, -0.15)) - vec2(0.012, 0.18);
    float strip = 1.0 - smoothstep(0.0, 0.055, max(stripDistance.x, stripDistance.y));
    return vec3(0.025, 0.035, 0.045)
        + vec3(2.2, 2.45, 2.65) * windowLight * pane
        + vec3(0.75, 0.67, 0.56) * strip;
}

float aquariumBeam(vec3 p, float t) {
    float surface = sin(p.x * 4.2 + p.z * 8.0 + t * 2.0)
        + 0.55 * sin(p.x * 7.0 - p.z * 5.0 - t * 3.0);
    float ribbon = exp(-surface * surface * 5.0);
    return ribbon * exp(-max(0.0, 0.5 - p.y) * 1.8);
}

vec4 aquariumRear(vec2 uv, vec2 extent, float t) {
    vec2 point = (aquarium_origin + uv * extent) / extent.y;
    float density = 0.5 + 0.25 * sin(point.x * 2.3 + t)
        + 0.25 * cos(point.y * 2.6 - t * 2.0);
    vec4 source = aquariumBlur(uv, 2.8 + density * 1.4, extent);
    vec3 transmission = exp(-vec3(0.20, 0.08, 0.055) * (0.8 + density * 0.25));
    float beam = aquariumBeam(vec3(point.x, 0.5 - uv.y, TANK_DEPTH), t);
    vec3 scatter = vec3(0.08, 0.22, 0.26) + beam * vec3(0.15, 0.23, 0.24);
    return vec4(source.rgb * transmission
        + scatter * (1.0 - transmission) * source.a, source.a);
}

// Analytic ray/sphere optics in three depth strata, with depth-dependent focus.
void aquariumBubbles(vec3 origin, vec3 ray, float path, float aspect, float t,
    out vec2 displacement, out vec3 reflection) {
    displacement = vec2(0.0);
    reflection = vec3(0.0);
    vec2 cellSize = vec2(0.30, 0.34);
    vec2 seedOrigin = floor(aquarium_origin / max(aquarium_extent.y, 1.0) / cellSize);
    for (int depth = 0; depth < 3; ++depth) {
        float baseZ = 0.10 + float(depth) * 0.24;
        float rayDistance = max(0.0, (baseZ - origin.z) / ray.z);
        vec2 atDepth = origin.xy + ray.xy * rayDistance;
        // Sixteen rows pass upward per 96-second loop; seeds wrap with the clock.
        vec2 grid = (atDepth - vec2(0.0, aquarium_phase * 16.0 * cellSize.y)) / cellSize;
        vec2 cell = floor(grid);
        for (int y = -1; y <= 1; ++y) {
            for (int x = -1; x <= 1; ++x) {
                vec2 id = cell + vec2(float(x), float(y));
                vec2 seed = aquariumHash(vec2(id.x + seedOrigin.x, mod(id.y + seedOrigin.y, 16.0))
                    + float(depth) * 37.1);
                if (seed.x > 0.28) continue;
                float z = baseZ + (seed.y - 0.5) * 0.10;
                vec2 centerXY = (id + 0.25 + seed * 0.50) * cellSize;
                centerXY.y += aquarium_phase * 16.0 * cellSize.y;
                centerXY.x += 0.012 * sin(t * (2.0 + float(depth)) + seed.y * TAU);
                vec3 center = vec3(centerXY, z);
                float radius = 0.0035 + 0.013 * seed.y * seed.y;
                float softness = 0.0010 + abs(z - 0.38) * 0.009;
                if (abs(center.x) > aspect * 0.5 - radius
                    || abs(center.y) > 0.5 - radius) continue;
                vec3 relative = center - origin;
                float along = dot(relative, ray);
                if (along < radius || along > path + radius) continue;
                vec3 closest = origin + ray * along - center;
                float perpendicular = length(closest);
                if (perpendicular > radius + softness * 3.0) continue;
                float coverage = 1.0 - smoothstep(radius - softness, radius + softness, perpendicular);
                float nearHit = along - sqrt(max(0.0, radius * radius - perpendicular * perpendicular));
                vec3 hit = origin + ray * nearHit;
                vec3 normal = normalize(hit - center);
                float facing = clamp(-dot(ray, normal), 0.0, 1.0);
                float fresnel = 0.0204 + 0.9796 * pow(1.0 - facing, 5.0);
                float focus = radius / (radius + softness * 2.0);
                vec3 reflected = reflect(ray, normal);
                vec3 environment = aquariumEnvironment(reflected);
                vec3 lamp = normalize(vec3(-0.5, 0.75, -0.65));
                float highlight = pow(max(0.0, dot(reflected, lamp)), 36.0);
                reflection += coverage * focus * exp(-z * 0.6)
                    * (environment * fresnel * 0.18 + vec3(0.72, 0.91, 1.0) * highlight * 0.35);
                vec3 insideRay = refract(ray, normal, WATER_IOR);
                if (dot(insideRay, insideRay) > 0.01 && perpendicular < radius) {
                    float insideLength = max(0.0, -2.0 * dot(insideRay, hit - center));
                    vec3 exit = hit + insideRay * insideLength;
                    vec3 exitNormal = normalize(exit - center);
                    vec3 exitRay = refract(insideRay, -exitNormal, 1.0 / WATER_IOR);
                    if (exitRay.z > 0.1) {
                        float remaining = max(0.0, origin.z + ray.z * path - exit.z);
                        vec2 shifted = exit.xy + exitRay.xy * remaining / exitRay.z;
                        vec2 straight = origin.xy + ray.xy * path;
                        // Cap only the lens displacement so small bubbles cannot erase text.
                        displacement += clamp(shifted - straight, vec2(-0.006), vec2(0.006))
                            * coverage * focus * (1.0 - fresnel);
                    }
                }
            }
        }
    }
}

vec4 shader_main(EffectContext effect) {
    if (aquarium_enabled < 0.5) return aquariumSample(effect.texture_uv);
    vec2 extent = max(aquarium_extent, vec2(1.0));
    vec2 uv = effect.texture_uv;
    float t = TAU * aquarium_phase;
    if (aquarium_plane < 0.5) return aquariumRear(uv, extent, t);

    float aspect = extent.x / extent.y;
    vec3 front = vec3((uv.x - 0.5) * aspect, 0.5 - uv.y, 0.0);
    vec3 camera = vec3(0.0, 0.0, -CAMERA_DISTANCE);
    vec3 airRay = normalize(front - camera);
    vec2 edgePixels = min(uv, 1.0 - uv) * extent;
    vec2 bevel = exp(-edgePixels / 4.0) * sign(uv - 0.5);
    vec3 glassNormal = normalize(vec3(bevel.x * 0.14, -bevel.y * 0.14, -1.0));
    vec3 flatNormal = vec3(0.0, 0.0, -1.0);
    vec3 glassRay = refract(airRay, glassNormal, 1.0 / GLASS_IOR);
    vec3 referenceGlassRay = refract(airRay, flatNormal, 1.0 / GLASS_IOR);
    vec3 origin = front + glassRay * GLASS_THICKNESS / glassRay.z;
    vec3 referenceOrigin = front + referenceGlassRay * GLASS_THICKNESS / referenceGlassRay.z;
    vec3 ray = refract(glassRay, flatNormal, GLASS_IOR / WATER_IOR);
    vec3 referenceRay = refract(referenceGlassRay, flatNormal, GLASS_IOR / WATER_IOR);
    vec3 worldOffset = vec3(aquarium_origin / extent.y, 0.0);
    ray = normalize(ray + aquariumCurrent(origin + worldOffset, t) * 0.0018);

    // Intersect the finite tank: side walls shorten the optical path near its edges.
    vec2 sideDirection = vec2(ray.x >= 0.0 ? 1.0 : -1.0, ray.y >= 0.0 ? 1.0 : -1.0);
    vec2 sideDistances = (sideDirection * vec2(aspect * 0.5, 0.5) - origin.xy)
        / (sideDirection * max(abs(ray.xy), vec2(0.0001)));
    float backDistance = (TANK_DEPTH - origin.z) / ray.z;
    float path = max(0.002, min(backDistance, min(sideDistances.x, sideDistances.y)));
    float sideWall = smoothstep(0.0, 0.035, backDistance - path);
    vec3 exit = origin + ray * path;
    vec3 referenceExit = referenceOrigin + referenceRay * (exit.z - referenceOrigin.z) / referenceRay.z;
    vec2 displacement = exit.xy - referenceExit.xy;
    vec2 bubbleDisplacement;
    vec3 bubbleReflection;
    aquariumBubbles(origin, ray, path, aspect, t, bubbleDisplacement, bubbleReflection);
    displacement += bubbleDisplacement;
    // Calibrate the flat tank against the original desktop; the image stays aligned.
    vec2 shiftedUv = clamp(uv + displacement / vec2(aspect, -1.0), 0.0, 1.0);
    vec4 source = aquariumBlur(shiftedUv, 0.22 + path * 0.48, extent);
    if (aquarium_plane > 1.5) {
        float background = 1.0;
        vec2 samplePoint = shiftedUv * extent;
        for (int i = 0; i < 16; ++i) {
            if (float(i) >= aquarium_window_count) break;
            vec4 rect = aquarium_windows[i];
            vec2 inside = step(rect.xy, samplePoint) * step(samplePoint, rect.xy + rect.zw);
            background *= 1.0 - inside.x * inside.y;
        }
        source = mix(source, aquariumRear(shiftedUv, extent, t), background);
    }

    // Four volume samples integrate absorption and top-lit scattering along the ray.
    vec3 transmission = vec3(1.0);
    vec3 scattering = vec3(0.0);
    for (int stepIndex = 0; stepIndex < 4; ++stepIndex) {
        vec3 p = origin + ray * path * (float(stepIndex) + 0.5) / 4.0;
        vec3 world = p + worldOffset;
        float density = 0.86 + 0.10 * sin(world.x * 3.0 + world.z * 5.0 + t)
            + 0.08 * cos(world.y * 4.0 - world.z * 3.0 - t * 2.0);
        vec3 stepTransmission = exp(-vec3(0.15, 0.055, 0.030) * density * path / 4.0);
        vec3 light = vec3(0.06, 0.17, 0.21)
            + aquariumBeam(world, t) * vec3(0.22, 0.35, 0.39);
        scattering += transmission * (1.0 - stepTransmission) * light;
        transmission *= stepTransmission;
    }
    vec3 color = source.rgb * transmission + scattering * source.a;
    color = mix(color, color * vec3(0.86, 0.94, 0.97), sideWall * 0.55);
    color += bubbleReflection * source.a;

    float glassFacing = clamp(-dot(airRay, glassNormal), 0.0, 1.0);
    float glassFresnel = 0.0426 + 0.9574 * pow(1.0 - glassFacing, 5.0);
    vec3 reflected = reflect(airRay, glassNormal);
    vec3 glassLight = aquariumEnvironment(reflected)
        + aquariumEnvironment(normalize(reflected + vec3(0.006, -0.003, 0.0))) * 0.12;
    float glassEdge = exp(-min(edgePixels.x, edgePixels.y) / 2.0);
    color = color * (1.0 - glassFresnel * 0.35)
        + glassLight * glassFresnel * source.a
        + vec3(0.30, 0.48, 0.52) * glassEdge * 0.05 * source.a;
    return vec4(clamp(color, vec3(0.0), vec3(source.a)), source.a);
}
