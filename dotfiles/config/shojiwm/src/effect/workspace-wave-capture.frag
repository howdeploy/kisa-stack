uniform sampler2D presented;
uniform sampler2D stamp;
uniform float generation;

vec4 shader_main(EffectContext effect) {
    vec4 marker = texture2D(stamp, vec2(0.5));
    if (marker.a < 0.5 || abs(marker.r - generation) > 0.5) {
        return texture2D(presented, effect.texture_uv);
    }
    return texture2D(tex, effect.texture_uv);
}
