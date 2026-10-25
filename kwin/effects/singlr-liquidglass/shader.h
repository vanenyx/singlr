// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
// Generated vertex shader supplies texcoord0; all positions below are local logical pixels.
inline constexpr char glassFragment[] = R"GLSL(
#version 140
uniform sampler2D sampler;
uniform vec2 extent;
uniform float radius;
uniform float strength;
in vec2 texcoord0;
out vec4 fragColor;
float sdf(vec2 p) {
    vec2 q = abs(p - extent * 0.5) - (extent * 0.5 - vec2(radius));
    return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}
void main() {
    // GLTexture's generated coordinates have a bottom-left texture origin.
    vec2 p = vec2(texcoord0.x, 1.0 - texcoord0.y) * extent;
    float d = sdf(p);
    if (d > 0.0) discard;
    vec2 n = normalize(vec2(sdf(p + vec2(0.5,0.0)) - sdf(p - vec2(0.5,0.0)),
                            sdf(p + vec2(0.0,0.5)) - sdf(p - vec2(0.0,0.5))) + vec2(0.00001));
    float edge = 1.0 - smoothstep(0.0, 16.0, -d);
    vec2 bend = n * edge * edge * (4.0 * strength) / extent;
    bend.y = -bend.y;
    vec2 uv = texcoord0 - bend;
    // A small nine-tap pass on the native blurred background. No noise or time uniform.
    vec2 stepSize = vec2(1.0 + 3.0 * strength) / extent;
    vec3 color = vec3(0.0);
    for (int x = -1; x <= 1; ++x)
        for (int y = -1; y <= 1; ++y)
            color += texture(sampler, uv + vec2(x,y) * stepSize).rgb / 9.0;
    // Subpixel chromatic separation, confined to the optical edge.
    vec2 dispersion = bend * 0.045;
    color.r += (texture(sampler, uv + dispersion).r - texture(sampler, uv).r) * edge;
    color.b += (texture(sampler, uv - dispersion).b - texture(sampler, uv).b) * edge;
    float rim = exp(-abs(d + 1.0) * 1.4);
    float light = 0.035 + 0.11 * max(0.0, dot(n, normalize(vec2(-0.4,-1.0))));
    fragColor = vec4(color + vec3(rim * light * strength), 1.0);
}
)GLSL";
