vec4 shader_main(EffectContext effect) {
    return texture2D(tex, effect.texture_uv);
}
