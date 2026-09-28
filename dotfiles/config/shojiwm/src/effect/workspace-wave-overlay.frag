uniform float progress;

vec4 shader_main(EffectContext effect) {
    if (progress >= 1.0) return vec4(0.0);
    return texture2D(tex, effect.texture_uv);
}
