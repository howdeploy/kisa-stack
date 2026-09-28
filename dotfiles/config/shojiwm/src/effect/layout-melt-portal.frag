uniform sampler2D windows;
uniform sampler2D colors;
uniform sampler2D flow;
uniform sampler2D wallpaper;
uniform vec2 screen_size;
uniform vec4 work_rect;
uniform vec4 group_rect;
uniform vec3 theme_accent;
uniform vec3 theme_warm;
uniform float melt;
uniform float pixel_size;
uniform float flow_time;

float hashCell(vec2 point) {
    return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 saturated(vec3 color) {
    float gray = dot(color, vec3(0.2126, 0.7152, 0.0722));
    return clamp(mix(vec3(gray), color, 1.75), 0.0, 1.0);
}

vec4 meltMaterial(vec2 p, float materialBlur) {
    vec2 uv = clamp(p / screen_size, vec2(0.0), vec2(1.0));
    vec3 field = texture2D(flow, uv).rgb;
    vec2 center = group_rect.xy + group_rect.zw * 0.5;
    // The entire composition contracts into one shared body, then opens back out.
    vec2 squeeze = vec2(1.0 - 0.22 * melt, 1.0 - 0.12 * melt);
    vec2 warped = center + (p - center) / squeeze;
    warped += (field.rg - vec2(0.35)) * min(screen_size.x, screen_size.y) * 0.28 * melt;
    vec2 sampleUv = warped / screen_size;
    vec2 edge = min(warped, screen_size - warped);
    float inside = smoothstep(0.0, 2.0, min(edge.x, edge.y));
    vec4 sharp = texture2D(windows, clamp(sampleUv, vec2(0.0), vec2(1.0))) * inside;
    vec4 soft = texture2D(colors, clamp(sampleUv, vec2(0.0), vec2(1.0))) * inside;
    vec4 paint = mix(sharp, soft, materialBlur);

    // Fill the gaps between windows at peak melt, so this is one flowing mass.
    vec2 halfSize = group_rect.zw * 0.5;
    float corner = min(halfSize.x, halfSize.y) * 0.55;
    vec2 q = abs(warped - center) - halfSize + corner;
    float distanceToBody = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner;
    float body = 1.0 - smoothstep(-24.0, 36.0, distanceToBody);
    float alpha = mix(paint.a, body, smoothstep(0.20, 0.90, melt));
    vec3 palette = mix(theme_accent, theme_warm, smoothstep(0.15, 0.65, field.b));
    vec3 windowColor = paint.rgb / max(paint.a, 0.001);
    windowColor = mix(palette * 0.65, windowColor, smoothstep(0.005, 0.08, paint.a));
    vec3 color = mix(windowColor, palette, 0.28 * melt);
    return vec4(color * alpha, alpha);
}

// The portal's two soft square grids, carried across the shared fBM material.
vec4 portalPixels(vec2 p, float cellSize, float layer) {
    vec2 drift = vec2(20.0, -12.0) * flow_time * (1.0 + layer * 0.4);
    vec2 position = p + drift;
    vec2 cell = floor(position / cellSize);
    vec2 pixel = (cell + 0.5) * cellSize - drift;
    // Sample only the blurred palette: these are colored matter, not image tiles.
    vec4 material = meltMaterial(pixel, 1.0);
    vec3 field = texture2D(flow, clamp(pixel / screen_size, vec2(0.0), vec2(1.0))).rgb;
    float cloud = smoothstep(0.10, 0.65, field.b);
    float glints = hashCell(cell + layer * 17.0);
    float density = material.a * (0.65 + 0.50 * cloud);
    if (layer > 0.5) density *= smoothstep(0.42, 0.85, glints) * 0.8;

    vec3 appColor = saturated(material.rgb / max(material.a, 0.001));
    vec3 systemColor = saturated(mix(theme_accent, theme_warm, cloud));
    vec3 color = mix(appColor, systemColor, 0.30 + 0.18 * glints);
    color *= mix(0.68, 1.0, cloud) / max(max(color.r, max(color.g, color.b)), 0.12);

    vec2 withinCell = fract(position / cellSize) - 0.5;
    float square = max(abs(withinCell.x), abs(withinCell.y));
    float halfPixel = mix(0.22, 0.49, clamp(density, 0.0, 1.0));
    float softPixel = 1.0 - smoothstep(halfPixel - 0.09, halfPixel + 0.10, square);
    float aura = (1.0 - smoothstep(0.22, 0.72, length(withinCell))) * 0.18;
    float opacity = clamp(density * (softPixel + aura), 0.0, 0.98);
    return vec4(clamp(color, 0.0, 1.0) * opacity, opacity);
}

vec4 shader_main(EffectContext effect) {
    vec2 uv = effect.texture_uv;
    vec4 original = texture2D(tex, uv);
    if (melt <= 0.0) return original;
    vec2 p = uv * screen_size;
    vec2 workEdge = min(p - work_rect.xy, work_rect.xy + work_rect.zw - p);
    float workMask = smoothstep(0.0, 3.0, min(workEdge.x, workEdge.y));
    vec4 largePixels = portalPixels(p, pixel_size, 0.0);
    vec4 smallPixels = portalPixels(p, pixel_size * 0.38, 1.0);
    vec4 matter = smallPixels + largePixels * (1.0 - smallPixels.a);
    vec4 material = meltMaterial(p, smoothstep(0.0, 0.75, melt));
    material = mix(material, matter, smoothstep(0.04, 0.65, melt));
    vec4 background = texture2D(wallpaper, uv);
    vec4 merged = material + background * (1.0 - material.a);
    return mix(original, merged, workMask * smoothstep(0.0, 0.15, melt));
}
