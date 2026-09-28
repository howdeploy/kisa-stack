#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 viewportSize;
    vec2 widgetOrigin;
    vec2 widgetSize;
    float progress;
    float beforeVisible;
    float afterVisible;
};
layout(binding = 1) uniform sampler2D source;

// Match wallpaper-wave.frag in screen coordinates, including its assembly band.
float revealed(vec2 p) {
    if (progress <= 0.0) return 0.0;
    if (progress >= 1.0) return 1.0;
    float reach = length(viewportSize * 0.5);
    float maxBand = clamp(min(viewportSize.x, viewportSize.y) * 0.08, 60.0, 110.0);
    float radius = (reach + maxBand * 1.85) * (1.0 - pow(1.0 - progress, 1.4));
    float band = max(1.0, min(maxBand, radius * 0.28));
    float swell = sin(3.1415927 * progress) * min(42.0, reach * 0.045);
    float angle = atan(p.y, p.x + 0.0001);
    float crest = sin(angle * 3.0 + progress * 7.0) * 0.55
                + sin(angle * 7.0 - progress * 11.0) * 0.30
                + cos(angle * 11.0 + progress * 9.0) * 0.15;
    float depth = radius + swell * crest - length(p);
    float stagger = fract(sin(dot(floor(p / 10.0), vec2(127.1, 311.7))) * 43758.5453) * band * 0.18;
    return smoothstep(band * 0.28, band * 1.35, depth - stagger);
}

void main() {
    vec2 p = widgetOrigin + qt_TexCoord0 * widgetSize - viewportSize * 0.5;
    float visibility = mix(beforeVisible, afterVisible, revealed(p));
    fragColor = texture(source, qt_TexCoord0) * visibility * qt_Opacity;
}
