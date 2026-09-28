uniform sampler2D windows;
uniform sampler2D colors;
uniform sampler2D mixed_colors;
uniform sampler2D flow;
uniform sampler2D wallpaper;
uniform vec2 screen_size;
uniform vec4 work_rect;
uniform vec4 group_rect;
uniform float melt;

vec4 fogMaterial(vec2 point) {
    vec3 field = texture2D(flow, clamp(point / screen_size, 0.0, 1.0)).rgb;
    vec2 center = group_rect.xy + group_rect.zw * 0.5;
    vec2 squeeze = vec2(1.0 - 0.12 * melt, 1.0 - 0.06 * melt);
    vec2 warped = center + (point - center) / squeeze;
    warped += (field.rg - vec2(0.35)) * min(screen_size.x, screen_size.y) * 0.20 * melt;
    vec2 uv = clamp(warped / screen_size, 0.0, 1.0);
    vec2 edge = min(warped, screen_size - warped);
    float inside = smoothstep(0.0, 3.0, min(edge.x, edge.y));
    vec4 sharp = texture2D(windows, uv) * inside;
    vec4 soft = texture2D(colors, uv) * inside;
    vec4 mixed = texture2D(mixed_colors, uv) * inside;
    float diffusion = smoothstep(0.0, 0.85, melt);
    vec4 paint = mix(sharp, soft, diffusion);

    vec2 halfSize = group_rect.zw * 0.5;
    float corner = min(halfSize.x, halfSize.y) * 0.55;
    vec2 q = abs(warped - center) - halfSize + corner;
    float distanceToBody = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner;
    float body = 1.0 - smoothstep(-32.0, 64.0, distanceToBody);
    float cloud = smoothstep(0.08, 0.65, field.b);
    float density = (1.0 - exp(-max(soft.a, mixed.a) * 2.0))
        * body * mix(0.68, 0.90, cloud);
    float alpha = mix(paint.a, density, diffusion);
    // Mix the windows' own colors by coverage, without brightness amplification.
    vec3 nearbyColor = mixed.rgb / max(mixed.a, 0.0001);
    vec3 windowColor = paint.rgb / max(paint.a, 0.0001);
    vec3 color = mix(nearbyColor, windowColor,
        smoothstep(0.01, 0.12, paint.a) * (1.0 - diffusion * 0.70));
    alpha *= smoothstep(0.0, 0.005, max(paint.a, mixed.a));
    return vec4(color * alpha, alpha);
}

vec4 shader_main(EffectContext effect) {
    vec2 uv = effect.texture_uv;
    vec4 original = texture2D(tex, uv);
    if (melt <= 0.0) return original;
    vec2 point = uv * screen_size;
    vec2 workEdge = min(point - work_rect.xy, work_rect.xy + work_rect.zw - point);
    float workMask = smoothstep(0.0, 3.0, min(workEdge.x, workEdge.y));
    if (workMask <= 0.0) return original;
    vec4 fog = fogMaterial(point);
    vec4 background = texture2D(wallpaper, uv);
    vec4 merged = fog + background * (1.0 - fog.a);
    return mix(original, merged, workMask * smoothstep(0.0, 0.15, melt));
}
