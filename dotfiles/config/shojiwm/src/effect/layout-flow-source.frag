uniform vec2 water_size;
uniform vec4 flow_rects[8];
uniform vec4 flow_deltas[8];
uniform float flow_ages[8];

vec4 shader_main(EffectContext effect) {
    vec4 field = texture2D(tex, effect.texture_uv);
    vec2 p = effect.texture_uv * water_size;
    for (int i = 0; i < 8; i++) {
        float age = flow_ages[i];
        if (age >= 0.0 && age < 0.5) {
            vec4 rect = flow_rects[i];
            vec4 delta = flow_deltas[i];
            // Emit from the middle of each travelled segment, including resize.
            vec2 center = rect.xy + rect.zw * 0.5 - delta.xy * 0.5;
            vec2 halfSize = max((rect.zw - delta.zw * 0.5) * 0.5, vec2(1.0));
            float corner = min(24.0, min(halfSize.x, halfSize.y));
            vec2 rel = p - center;
            vec2 q = abs(rel) - halfSize + corner;
            vec2 outside = max(q, vec2(0.0));
            float distanceToEdge = length(outside) + min(max(q.x, q.y), 0.0) - corner;
            vec2 normal = length(outside) > 0.001
                ? normalize(outside) * sign(rel)
                : (q.x > q.y ? vec2(sign(rel.x), 0.0) : vec2(0.0, sign(rel.y)));
            vec2 edgeTravel = delta.xy + sign(rel) * delta.zw * 0.5;
            float strength = 1.0 - exp(-abs(dot(edgeTravel, normal)) / 90.0);

            // A broad travelling crest, with a soft trough on either side.
            float radius = age * length(water_size) * 1.5;
            float width = 48.0 + radius * 0.045;
            float phase = (distanceToEdge - radius) / width;
            float crest = exp(-phase * phase * 0.5);
            float fade = 1.0 - smoothstep(0.05, 0.5, age);
            float amplitude = strength * fade;
            field.rg += normal * phase * crest * amplitude;
            field.b += crest * amplitude;
        }
    }
    return field;
}
