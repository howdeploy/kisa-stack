#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 bodyMotion;
    vec2 earMotion;
    vec4 milkColor;
    vec2 viewportSize;
    vec2 viewAngles;
    vec2 upperMotion;
};

float smoothUnion(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float ellipsoid(vec3 p, vec3 radius) {
    // Conservative bound, including the centre of the ellipsoid.
    return (length(p / radius) - 1.0) * min(radius.x, min(radius.y, radius.z));
}

float roundedCone(vec3 p, vec3 a, vec3 b, float baseRadius, float tipRadius) {
    vec3 axis = b - a;
    float height = length(axis);
    vec3 direction = axis / height;
    float along = dot(p - a, direction);
    vec2 q = vec2(length(p - a - direction * along), along);
    // Tangent joins keep the continuous flank and rounded tip smooth.
    float taper = (baseRadius - tipRadius) / height;
    float slope = sqrt(1.0 - taper * taper);
    float region = dot(q, vec2(-taper, slope));
    if (region < 0.0) return length(q) - baseRadius;
    if (region > slope * height) return length(q - vec2(0.0, height)) - tipRadius;
    return dot(q, vec2(slope, taper)) - baseRadius;
}

float ear(vec3 p, float side) {
    return roundedCone(p, vec3(side * 0.27, 1.39, 0.30),
                       vec3(side * 0.28, 1.88, 0.29), 0.29, 0.15);
}

vec3 restPosition(vec3 p) {
    // Inverse squash: reciprocal horizontal expansion preserves volume.
    float vertical = 1.0 - bodyMotion.z;
    p.y /= vertical;
    p.xz *= sqrt(vertical);
    float h = clamp(p.y / 2.01, 0.0, 1.1);
    float bend = h * (0.4 + 0.6 * h);
    // The main mass moves first; the upper body follows with its own inertia.
    p.xz -= bodyMotion.xy * bend * 0.75 + upperMotion * h * h * 1.25;
    float angle = -bodyMotion.w * bend;
    p.xz = mat2(cos(angle), -sin(angle), sin(angle), cos(angle)) * p.xz;
    float earWeight = smoothstep(1.38, 2.01, p.y);
    // Positive scaling plus shear stays invertible even when the ears move
    // in opposite directions. Subtracting an x-dependent offset can fold
    // the distance field and create detached droplets.
    float earSway = (earMotion.x + earMotion.y) * 0.5;
    float earSpread = (earMotion.y - earMotion.x) * 0.9;
    p.x = (p.x - earSway * earWeight * 0.65) / exp(earSpread * earWeight);
    float earBend = mix(earMotion.x, earMotion.y, smoothstep(-0.28, 0.28, p.x));
    p.z -= earBend * earWeight * 0.35;
    return p;
}

float catDistance(vec3 p) {
    vec3 q = restPosition(p);
    // One gently tapered front: no separate head sphere, cheeks or neck.
    vec3 front = vec3(q.xy, (q.z - 0.28) * 1.40);
    float d = roundedCone(front, vec3(0.0, 0.12, 0.0),
                          vec3(0.0, 1.00, 0.0), 0.72, 0.64) / 1.40;
    // The rump is sheared down towards the rear and sunk below the support
    // plane, giving a spreading base rather than the underside of a ball.
    vec3 rump = q - vec3(0.0, -0.16, -0.30);
    rump.y -= 0.38 * (q.z + 0.30);
    d = smoothUnion(d, ellipsoid(rump, vec3(0.78, 1.02, 1.0)) * 0.80, 0.22);
    float paws = smoothUnion(
        ellipsoid(q - vec3(-0.32, 0.12, 0.53), vec3(0.28, 0.25, 0.32)),
        ellipsoid(q - vec3(0.32, 0.12, 0.53), vec3(0.28, 0.25, 0.32)), 0.09);
    d = smoothUnion(d, paws, 0.14);
    d = smoothUnion(d, ear(q, -1.0), 0.14);
    d = smoothUnion(d, ear(q, 1.0), 0.14);
    // The support plane never moves; there is no floating or bouncing base.
    return max(d, -p.y);
}

vec3 catNormal(vec3 p) {
    const vec2 e = vec2(0.002, -0.002);
    return normalize(e.xyy * catDistance(p + e.xyy)
                   + e.yyx * catDistance(p + e.yyx)
                   + e.yxy * catDistance(p + e.yxy)
                   + e.xxx * catDistance(p + e.xxx));
}

float faceMask(vec3 q) {
    vec2 eye = (vec2(abs(q.x), q.y) - vec2(0.17, 1.13)) / vec2(0.025, 0.037);
    vec2 nose = (q.xy - vec2(0.0, 1.02)) / vec2(0.025, 0.019);
    float ink = 1.0 - smoothstep(0.78, 1.16, min(length(eye), length(nose)));
    return ink * smoothstep(0.55, 0.67, q.z);
}

vec3 shadeCat(vec3 p, vec3 ray) {
    vec3 n = catNormal(p);
    vec3 q = restPosition(p);
    vec3 light = normalize(vec3(-0.65, 0.95, 1.4));
    vec3 view = -ray;
    vec3 halfLight = normalize(light + view);
    float facing = max(dot(n, view), 0.0);
    float diffuse = clamp((dot(n, light) + 0.42) / 1.42, 0.0, 1.0);
    float ao = 0.0;
    ao += max(0.0, 0.06 - catDistance(p + n * 0.06)) * 0.75;
    ao += max(0.0, 0.16 - catDistance(p + n * 0.16)) * 0.35;
    float occlusion = clamp(1.0 - ao * 2.2, 0.65, 1.0);
    float baseShade = mix(0.76, 1.0, smoothstep(0.02, 0.38, p.y));
    vec3 milk = pow(milkColor.rgb, vec3(2.2));
    vec3 color = milk * (0.38 + diffuse * 0.62) * occlusion * baseShade;
    // Warm diffuse transmission at thin ear tips; the centre stays milky.
    float thin = smoothstep(1.38, 2.01, q.y);
    float backlight = pow(max(dot(-light, view), 0.0), 3.0);
    color += milk * vec3(1.0, 0.60, 0.30) * thin * (0.055 + backlight * 0.2);
    float fresnel = 0.028 + 0.972 * pow(1.0 - facing, 5.0);
    float sheen = pow(max(dot(n, halfLight), 0.0), 38.0);
    float broad = pow(max(dot(n, halfLight), 0.0), 8.0);
    color += vec3(1.0, 0.96, 0.86) * (sheen * 0.36 + broad * 0.045 + fresnel * 0.10);
    color = mix(color, vec3(0.028, 0.018, 0.020) + sheen * 0.09, faceMask(q));
    return pow(clamp(color, 0.0, 1.0), vec3(1.0 / 2.2));
}

void main() {
    vec2 uv = (qt_TexCoord0 - 0.5) * vec2(viewportSize.x / max(viewportSize.y, 1.0), -1.0) * 3.2;
    float yaw = viewAngles.x;
    float pitch = viewAngles.y;
    vec3 view = vec3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch));
    // Analytic camera basis stays defined when looking straight down or up.
    vec3 right = vec3(cos(yaw), 0.0, -sin(yaw));
    vec3 up = cross(view, right);
    vec3 origin = vec3(0.0, 1.0, -0.18) + view * 4.3 + right * uv.x + up * uv.y;
    vec3 ray = -view;
    float travel = 2.0;
    // ponytail: bounded artistic deformation, not FEM. Keep conservative steps;
    // a full soft-body solver is only needed for folds or changing contacts.
    for (int i = 0; i < 224; i++) {
        vec3 p = origin + ray * travel;
        float distance = catDistance(p);
        if (distance < 0.0015) {
            fragColor = vec4(shadeCat(p, ray), 1.0) * qt_Opacity;
            return;
        }
        travel += max(distance * 0.38, 0.0006);
        if (travel > 6.6) break;
    }
    fragColor = vec4(0.0);
}
