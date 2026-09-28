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

vec4 shader_main(EffectContext effect) {
    vec2 uv = effect.texture_uv;
    vec4 original = texture2D(tex, uv);
    if (melt <= 0.0) return original;
    vec2 p = uv * screen_size;
    vec2 workEdge = min(p - work_rect.xy, work_rect.xy + work_rect.zw - p);
    float workMask = smoothstep(0.0, 3.0, min(workEdge.x, workEdge.y));
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
    vec4 paint = mix(sharp, soft, smoothstep(0.0, 0.75, melt));

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
    vec4 background = texture2D(wallpaper, uv);
    vec4 merged = vec4(color * alpha, alpha) + background * (1.0 - alpha);
    return mix(original, merged, workMask * smoothstep(0.0, 0.15, melt));
}
