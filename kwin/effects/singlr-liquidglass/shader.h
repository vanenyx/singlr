// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
// Positions and optical lengths are logical pixels, independent of output scale.
inline constexpr char glassFragment[] = R"GLSL(
#version 140
uniform sampler2D sampler;
uniform vec2 extent;
uniform vec2 sourceExtent;
uniform vec2 inset;
uniform float radius;
uniform float strength;
uniform float liquid;
uniform float dark;
uniform float diagnosticOverlay;
in vec2 texcoord0;
out vec4 fragColor;
float sdf(vec2 p) {
    vec2 q = abs(p - extent * 0.5) - (extent * 0.5 - vec2(radius));
    return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}
vec3 diffuse(vec2 uv, float spread) {
    // Symmetric, fixed work. Native KWin blur supplies the low frequencies;
    // intensity controls this additional diffusion (Liquid keeps a cleaner body).
    vec2 stepSize = vec2(spread) / sourceExtent;
    vec3 c = texture(sampler, uv).rgb * 0.20;
    const vec2 offsets[12] = vec2[12](
        vec2(0.20412415, 0.00000000),
        vec2(-0.26069927, 0.23882188),
        vec2(0.03990420, -0.45468779),
        vec2(0.32859454, 0.42859339),
        vec2(-0.60301140, -0.10666423),
        vec2(0.57122504, -0.36336661),
        vec2(-0.19106360, 0.71074705),
        vec2(-0.36437900, -0.70158959),
        vec2(0.79055667, 0.28871003),
        vec2(-0.82244249, 0.33949230),
        vec2(0.39647163, -0.84723683),
        vec2(0.29298244, 0.93407421));
    for (int i = 0; i < 12; ++i) {
        vec2 offset = offsets[i];
        c += texture(sampler, uv + offset * stepSize).rgb * (0.80/12.0);
    }
    return c;
}
vec3 toLinear(vec3 c) {
    return mix(c / 12.92, pow((c + vec3(0.055)) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}
vec3 toDisplay(vec3 c) {
    return mix(c * 12.92, 1.055 * pow(c, vec3(1.0/2.4)) - vec3(0.055), step(vec3(0.0031308), c));
}
float softLimit(float value, float ceiling) {
    float ratio = value / ceiling;
    // Sixth-order smooth shoulder, bounded by ceiling with unit slope at zero.
    return value / pow(1.0 + pow(ratio, 6.0), 1.0/6.0);
}
void main() {
    vec2 p = vec2(texcoord0.x, 1.0 - texcoord0.y) * sourceExtent - inset;
    float d = sdf(p);
    if (d > 0.0) discard;
    vec2 n = normalize(vec2(sdf(p + vec2(0.5,0.0)) - sdf(p - vec2(0.5,0.0)),
                            sdf(p + vec2(0.0,0.5)) - sdf(p - vec2(0.0,0.5))) + vec2(0.00001));
    float width = min(30.0, min(extent.x, extent.y) / 3.0);
    float edge = 1.0 - smoothstep(0.0, width, -d);
    // Convex cross-section: steep at the perimeter, flat through the body.
    // SDF normals rotate continuously around each corner; all four sides lens.
    vec2 bend = n * pow(edge, 1.65) * (24.0 * strength * liquid) / sourceExtent;
    bend.y = -bend.y;
    vec2 uv = texcoord0 - bend;
    vec3 color = diffuse(uv, strength * mix(14.0, 5.0, liquid));
    vec2 dispersion = bend * 0.055;
    color.r += (texture(sampler, uv + dispersion).r - texture(sampler, uv).r) * edge;
    color.b += (texture(sampler, uv - dispersion).b - texture(sampler, uv).b) * edge;
    // Broad directional lobe plus a narrow Fresnel crest, following the SDF
    // normal instead of a horizontal painted line. Opposing lower bounce light.
    float key = pow(max(0.0, dot(n, normalize(vec2(-0.55,-1.0)))), 3.0);
    float bounce = pow(max(0.0, dot(n, normalize(vec2(0.7,1.0)))), 5.0);
    float shoulder = exp(-pow((-d-4.0)/4.5, 2.0));
    float crest = exp(-pow((-d-1.0)/0.9, 2.0));
    float specular = ((0.10 + 0.70*key + 0.25*bounce)*shoulder + 0.32*crest);
    color += vec3(specular * liquid * strength);
    color = clamp(color, vec3(0.0), vec3(1.0));
    // Vibrancy is a local material response, not a field or glyph rectangle.
    // Native blur + diffusion supply low-frequency luminance. A smooth shoulder
    // only compresses the unsafe range; dark details keep their original slope.
    // Work in linear SDR RGB, preserving hue when darkening and mixing reference
    // white when lightening. No mean readback, history, timers or hard threshold.
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = mix(vec3(luma), color, 0.86);
    vec3 linearColor = toLinear(color);
    float y = dot(linearColor, vec3(0.2126, 0.7152, 0.0722));
    float transmission = max(0.001, 0.85 * strength);
    float alpha = 1.0 - transmission;
    if (dark > 0.5) {
        // Tint channels <= .14. Convexity of sRGB decoding bounds final Y by
        // alpha*Y(tint) + transmission*Y(backdrop), even for saturated colors.
        float ceiling = max(0.001, (0.110 - alpha * 0.0173891) / transmission);
        float target = softLimit(y, ceiling);
        linearColor *= target / max(y, 0.000001);
    } else {
        // Tint channels >= .90. Composite >= k*backdrop componentwise;
        // linear(k*c) >= k^2.4*linear(c), yielding final Y >= .425.
        float k = transmission + alpha * 0.90;
        float floorY = 0.425 / pow(k, 2.4);
        float target = 1.0 - softLimit(1.0-y, 1.0-floorY);
        linearColor = mix(linearColor, vec3(1.0), (target-y) / max(1.0-y, 0.000001));
    }
    color = toDisplay(linearColor);
    if (diagnosticOverlay > 0.5 && d > -8.0)
        color = vec3(1.0, 0.0, 1.0);
    fragColor = vec4(color, 1.0);
}
)GLSL";
