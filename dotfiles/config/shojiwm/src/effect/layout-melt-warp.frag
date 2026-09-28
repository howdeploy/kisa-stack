uniform vec2 screen_size;
uniform float flow_time;

float rand(vec2 n) {
    return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 ip = floor(p);
    vec2 u = fract(p);
    u = u * u * (3.0 - 2.0 * u);
    float value = mix(mix(rand(ip), rand(ip + vec2(1.0, 0.0)), u.x),
                      mix(rand(ip + vec2(0.0, 1.0)), rand(ip + vec2(1.0)), u.x), u.y);
    return value * value;
}

const mat2 mtx = mat2(0.80, 0.60, -0.60, 0.80);

float fbm(vec2 p) {
    float time = flow_time * 0.55;
    float f = 0.500000 * noise(p + time); p = mtx * p * 2.02;
    f += 0.031250 * noise(p); p = mtx * p * 2.01;
    f += 0.250000 * noise(p); p = mtx * p * 2.03;
    f += 0.125000 * noise(p); p = mtx * p * 2.01;
    f += 0.062500 * noise(p); p = mtx * p * 2.04;
    f += 0.015625 * noise(p + sin(time));
    return f / 0.96875;
}

float pattern(vec2 p) {
    return fbm(p + fbm(p + fbm(p)));
}

vec4 shader_main(EffectContext effect) {
    vec2 p = effect.texture_uv * screen_size / max(screen_size.x, 1.0) * 3.0;
    float a = pattern(p);
    float b = pattern(p + vec2(5.2, 1.3));
    return vec4(a, b, clamp((a + b) * 0.9, 0.0, 1.0), 1.0);
}
