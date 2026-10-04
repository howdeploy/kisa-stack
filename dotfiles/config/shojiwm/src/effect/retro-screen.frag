uniform float rows;
uniform float enabled;
const float CURVATURE = 0.025;

vec4 retroSample(vec2 pixel, vec2 size) {
    return texture2D(tex, clamp(pixel, vec2(0.5), size - 0.5) / size);
}

vec4 shader_main(EffectContext effect) {
    if (enabled < 0.5) return texture2D(tex, effect.texture_uv);
    vec2 size = max(effect.texture_size_px, vec2(1.0));
    vec2 edge = (effect.texture_uv - 0.5) * 2.0;
    // Gentle CRT barrel distortion: the center and edge midpoints stay fixed.
    vec2 curved = edge * (1.0 + CURVATURE * edge.yx * edge.yx);
    vec2 curvedUv = curved * 0.5 + 0.5;
    vec2 inside = 1.0 - smoothstep(vec2(1.0) - 2.0 / size, vec2(1.0), abs(curved));
    float screenMask = inside.x * inside.y;
    vec2 pixel = curvedUv * size;
    // Equal physical width and height keep the cells square on every output.
    float block = max(size.y / max(rows, 1.0), 1.0);
    vec2 cell = (floor(pixel / block) + 0.5) * block;
    vec4 source = retroSample(cell, size);
    vec3 neighbors = (
        retroSample(cell + vec2(block, 0.0), size).rgb +
        retroSample(cell - vec2(block, 0.0), size).rgb +
        retroSample(cell + vec2(0.0, block), size).rgb +
        retroSample(cell - vec2(0.0, block), size).rgb
    ) * 0.25;
    vec3 color = source.rgb * 0.98 + neighbors * 0.04;

    // Static CRT texture needs no animation timer or idle redraws.
    float scanline = 1.0 - 0.08 * (0.5 - 0.5 * cos(6.2831853 * pixel.y / 3.0));
    vec3 phosphor = 0.96 + 0.04 * (0.5 + 0.5 * cos(
        6.2831853 * (vec3(pixel.x / 3.0) - vec3(0.0, 0.3333333, 0.6666667))
    ));
    float vignette = 1.0 - 0.08 * clamp(dot(edge, edge) * 0.5, 0.0, 1.0);
    color *= scanline * phosphor * vignette;
    // Opaque black outside the curved glass prevents the original scene leaking through.
    return vec4(clamp(color, vec3(0.0), vec3(source.a)) * screenMask,
        mix(1.0, source.a, screenMask));
}
