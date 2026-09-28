uniform sampler2D scene;
uniform vec2 screen_size;
uniform vec4 window_rect;

vec4 shader_main(EffectContext effect) {
    vec2 uv = effect.texture_uv;
    vec2 p = uv * screen_size - window_rect.xy - window_rect.zw * 0.5;
    float radius = min(10.0, min(window_rect.z, window_rect.w) * 0.5);
    vec2 q = abs(p) - window_rect.zw * 0.5 + radius;
    float distanceToEdge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
    float coverage = max(texture2D(tex, uv).a, 1.0 - smoothstep(-1.0, 1.0, distanceToEdge));
    return vec4(texture2D(scene, uv).rgb * coverage, coverage);
}
