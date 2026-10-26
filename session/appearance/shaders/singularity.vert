#version 440
layout(location=0) in vec2 corner;
layout(location=1) in vec4 particle;
layout(location=0) out vec2 uv;
layout(location=1) out float light;
layout(location=2) out vec2 scene;
layout(location=3) out float behind;
layout(std140,binding=0) uniform buf {
    mat4 matrix;
    float opacity; float time; vec2 size;
    vec2 pointer; float density;
} u;
const float PI = 3.14159265359;
void main() {
    float seed=particle.z, kind=particle.w;
    float r=1.12 + 3.9*pow(particle.x,1.65);
    float a=particle.y + u.time*.16/pow(r,1.5);
    // Thin orbital filaments with coherent differential rotation and vertical turbulence.
    r = floor(r*110.)/110. + .006*sin(a*9. + r*18. + u.time*.13);
    float z=sin(a)*r;
    vec2 p=vec2(cos(a)*r, z*.20);
    vec2 tangent=normalize(vec2(-sin(a),cos(a)*.20));
    p.y += .018*sin(a*5.+r*12.+u.time*.2) + (seed-.5)*.035;
    float depth=5.8/(5.8+z*.19);
    p*=depth;
    behind=step(z,0.);
    float brightness=(.15+.85*pow(1.-particle.x,1.4))*(.3+.7*seed);
    float radius=mix(.65,1.35,pow(seed,5.));
    if (kind < .26) {
        // Secondary images of the disk bent around the black silhouette.
        // Artistic lensing, deliberately not a relativistic ray tracer.
        float band=pow(particle.x,2.8);
        float angle=particle.y + u.time*.095/(1.+band);
        r=1.035+band*.72;
        p=vec2(cos(angle)*r, sin(angle)*r);
        tangent=vec2(-sin(angle),cos(angle));
        p.y*=1.02;
        brightness=(.16+.55*pow(1.-band,2.))*(.3+.7*seed);
        brightness*=p.y<0. ? 1.0 : .48;
        behind=1.; radius=mix(.5,1.15,seed);
    } else if (kind < .30) {
        // Photon rim: a fine granular edge, not a solid glowing circle.
        r=1.015+.045*pow(particle.x,2.);
        p=vec2(cos(a),sin(a))*r; tangent=vec2(-sin(a),cos(a));
        brightness=.28+.45*seed; behind=1.; radius=.65;
    } else if (kind > .975) {
        p=vec2((particle.x-.5)*16.,(particle.y/6.2831853-.5)*10.);
        brightness=.035+.11*pow(seed,7.); radius=.6+seed*.7; behind=1.;
    }
    // Restrained camera parallax, with inertia supplied by the frame clock.
    float tilt=-.13+(u.pointer.x-.5)*.065;
    mat2 rotation=mat2(cos(tilt),sin(tilt),-sin(tilt),cos(tilt));
    p=rotation*p;
    p += (u.pointer-vec2(.5))*vec2(.08,.05)*(1.+abs(z)*.1);
    float scale=min(u.size.x/11.6,u.size.y/5.8);
    vec2 center=vec2(u.size.x*.51,u.size.y*.50);
    float pixels=radius*max(.15,scale/110.);
    // Sparse broad sprites add local soft light without a fullscreen blur pass.
    if (seed < .10 && kind < .975) { pixels *= 8.; brightness *= .018; }
    brightness *= 2.2;
    // Slightly elongated specks convey orbital flow while staying individually visible.
    tangent=rotation*tangent;
    float trail=kind > .975 ? 1. : mix(1.4,5.5,pow(seed,3.));
    vec2 extent=tangent*corner.x*pixels*trail + vec2(-tangent.y,tangent.x)*corner.y*pixels*.7;
    scene=p+extent/scale;
    uv=corner;
    light=brightness*sqrt(u.density)*u.opacity;
    gl_Position=u.matrix*vec4(center+p*scale+extent,0.,1.);
}
