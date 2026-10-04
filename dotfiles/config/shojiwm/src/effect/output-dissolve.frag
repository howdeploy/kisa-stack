uniform float progress;

vec4 shader_main(EffectContext effect) {
    vec4 frozen = texture2D(tex, effect.texture_uv);
    return frozen * (1.0 - clamp(progress, 0.0, 1.0));
}
