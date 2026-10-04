#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 desktopSize;
    vec2 outputOrigin;
    vec2 outputSize;
    float progress;
    float uncovering;
    vec4 backgroundColor;
    vec4 accent;
    vec4 warm;
};

float hashCell(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
    // One field in desktop logical coordinates, including the seam between outputs.
    vec2 p = outputOrigin + qt_TexCoord0 * outputSize - desktopSize * 0.5;
    float reach = length(desktopSize * 0.5);
    float maxBand = clamp(min(desktopSize.x, desktopSize.y) * 0.08, 60.0, 110.0);
    float radius = (reach + maxBand * 1.85) * (1.0 - pow(1.0 - progress, 1.4));
    float band = max(1.0, min(maxBand, radius * 0.28));
    float swell = sin(3.1415927 * progress) * min(42.0, reach * 0.045);
    float angle = atan(p.y, p.x + 0.0001);
    float crest = sin(angle * 3.0 + progress * 7.0) * 0.55
                + sin(angle * 7.0 - progress * 11.0) * 0.30
                + cos(angle * 11.0 + progress * 9.0) * 0.15;
    float depth = radius + swell * crest - length(p);
    float stagger = hashCell(floor(p / 10.0)) * band * 0.18;
    float assembled = smoothstep(band * 0.28, band * 1.35, depth - stagger);
    if (progress <= 0.0) assembled = 0.0;
    if (progress >= 1.0) assembled = 1.0;
    float alpha = mix(assembled, 1.0 - assembled, uncovering);

    // Soft pixel matter and a liquid crest match the existing widget reveal.
    vec2 direction = p / max(length(p), 1.0);
    vec2 flow = direction * progress * 84.0 + vec2(-direction.y, direction.x) * progress * 66.0;
    vec2 cell = floor((p - flow) / 26.0);
    vec2 local = fract((p - flow) / 26.0) - 0.5;
    float seed = hashCell(cell);
    float square = 1.0 - smoothstep(0.20, 0.38, max(abs(local.x), abs(local.y)));
    float fringe = smoothstep(0.0, band * 0.20, depth)
                 * (1.0 - smoothstep(band * 0.70, band * 1.45, depth))
                 * sin(3.1415927 * progress);
    vec3 color = mix(backgroundColor.rgb, mix(accent.rgb, warm.rgb, seed),
                     fringe * (0.22 + square * 0.60));
    fragColor = vec4(color * alpha, alpha) * qt_Opacity;
}
