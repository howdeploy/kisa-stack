// Finite travelling impulse; no global translation or simultaneous squash.
uniform float jelly_progress;
uniform vec2 jelly_contact;
uniform vec2 jelly_normal;
uniform float jelly_strength;
uniform vec2 jelly_extent;

vec2 impactPacket(vec2 point, vec2 contact, vec2 inward, float front, float width) {
    vec2 delta = point - contact;
    float distanceFromContact = length(delta);
    float age = (front - distanceFromContact) / width;
    // Untouched before arrival; exactly settled after this crest and recoil.
    if (age <= 0.0 || age >= 1.0) return vec2(0.0);
    float pulse = sin(age * 6.2831853) * sin(age * 3.1415927);
    float attenuation = inversesqrt(1.0 + distanceFromContact / (width * 1.5));
    vec2 radial = delta / max(distanceFromContact, 1.0);
    vec2 direction = mix(inward, radial, 0.60);
    return direction * pulse * attenuation;
}

vec4 shader_main(EffectContext effect) {
    float time = clamp(jelly_progress, 0.0, 1.0);
    // The 460 ms placement first reaches its target near 210 ms; the material
    // clock lasts 560 ms. Launch on contact, not when travel begins.
    if (time <= 0.38 || time >= 1.0) return texture2D(tex, effect.texture_uv);

    vec2 scale = max(effect.content_rect_px.zw, vec2(1.0)) / max(jelly_extent, vec2(1.0));
    vec2 extent = max(jelly_extent - vec2(32.0), vec2(1.0));
    vec2 point = (effect.texture_uv * effect.texture_size_px - effect.content_rect_px.xy)
               / scale - vec2(16.0);
    vec2 contact = jelly_contact * extent;
    float reach = length(max(contact, extent - contact));
    float width = max(32.0, reach * 0.42);
    float phase = (time - 0.38) / 0.62;
    float front = phase * (reach + width);

    vec2 displacement = impactPacket(point, contact, jelly_normal, front, width);
    // A weak reflection starts only once the front actually reaches the far
    // boundary. The mirrored source supplies that path length automatically.
    vec2 reflectedContact = contact + jelly_normal * extent * 2.0;
    displacement += impactPacket(point, reflectedContact, -jelly_normal, front, width) * 0.22;
    displacement *= jelly_strength * (1.0 - smoothstep(0.88, 1.0, time));

    vec2 uv = effect.texture_uv - displacement * scale / effect.texture_size_px;
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return vec4(0.0);
    return texture2D(tex, uv);
}
