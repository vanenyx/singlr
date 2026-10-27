#version 440
layout(location=0) in vec4 particle;
// Point sprite: travel direction and the ellipse's inverse half-axes.
layout(location=0) out vec4 shape;
layout(location=1) out float light;
layout(std140,binding=0) uniform buf {
    mat4 matrix;
    float opacity; float time; vec2 size;
    float dpr; float wakeCount; float density; float padding;
    vec4 wakes[32];
    vec4 pushes[32];
} u;
void main() {
    float scale=min(u.size.x/11.6,u.size.y/5.8);
    vec2 center=vec2(u.size.x*.51,u.size.y*.50);
    float seed=particle.z, kind=particle.w;
    bool infalling=kind>.64;
    float r=1.12 + 3.9*pow(particle.x,1.65);
    float a=particle.y + u.time*.16/pow(r,1.5);
    r=floor(r*110.)/110. + .006*sin(a*9. + r*18. + u.time*.13);
    float z=sin(a)*r;
    vec2 p=vec2(cos(a)*r,z*.20);
    vec2 tangent=normalize(vec2(-sin(a),cos(a)*.20));
    p.y+=.018*sin(a*5.+r*12.+u.time*.2)+(seed-.5)*.035;
    p*=5.8/(5.8+z*.19);
    float behind=step(z,0.);
    float brightness=1.35*(.15+.85*pow(1.-particle.x,1.4))*(.3+.7*seed);
    float radius=mix(.65,1.35,pow(seed,5.));
    float trail=mix(1.4,5.5,pow(seed,3.));
    if (kind<.26) {
        // Artistic secondary images of the accretion disk around a fixed silhouette.
        float band=pow(particle.x,2.8);
        float angle=particle.y+u.time*.095/(1.+band);
        r=1.035+band*.72;
        p=vec2(cos(angle)*r,sin(angle)*r*1.02);
        tangent=vec2(-sin(angle),cos(angle));
        brightness=(.16+.55*pow(1.-band,2.))*(.3+.7*seed);
        brightness*=p.y<0. ? 1.0 : .48;
        behind=1.; radius=mix(.5,1.15,seed);
    } else if (kind<.30) {
        r=1.015+.045*pow(particle.x,2.);
        p=vec2(cos(a),sin(a))*r;
        tangent=vec2(-sin(a),cos(a));
        brightness=.28+.45*seed; behind=1.; radius=.65;
    }
    // A fixed composition: the pointer never rotates/translates the camera.
    const float tilt=-.13;
    mat2 rotation=mat2(cos(tilt),sin(tilt),-sin(tilt),cos(tilt));
    p=rotation*p; tangent=rotation*tangent;
    if (infalling) {
        // Staggered lifetimes distribute particles over the whole rectangular
        // output, including its corners; each path spirals inward and is recycled.
        float life=fract(particle.x+seed*.731+u.time*(.012+.012*seed));
        float angle=particle.y+.4*life+1.1*pow(life,5.);
        vec2 direction=vec2(cos(angle),sin(angle));
        vec2 halfSize=u.size/(2.*scale)+vec2(.22);
        float edge=min(halfSize.x/max(.001,abs(direction.x)),halfSize.y/max(.001,abs(direction.y)));
        r=.76+(edge-.76)*pow(1.-life,.55);
        p=direction*r;
        tangent=normalize(-direction+vec2(-direction.y,direction.x)*(.2+life*.9));
        brightness=(.12+.30*pow(seed,5.)+.20*life)*smoothstep(0.,.06,life);
        brightness*=smoothstep(.82,1.25,r);
        radius=.48+.66*seed;
        trail=1.15+1.7*pow(life,4.);
        behind=1.;
    }
    vec2 base=center+p*scale;
    vec2 displacement=vec2(0.);
    float totalWeight=0.;
    float influence=min(u.size.x,u.size.y)*.12;
    // Compact-support cursor wakes: pixels outside the local field are exactly
    // unchanged. Past impulses decay and overshoot slightly like disturbed water.
    int wakeCount=int(u.wakeCount+.5);
    for (int i=0;i<32;++i) {
        if (i>=wakeCount) break;
        vec2 delta=base-u.wakes[i].xy*u.size;
        float support=influence*(1.+min(u.wakes[i].w,1.5)*.3);
        float f=max(0.,1.-dot(delta,delta)/(support*support));
        f=f*f*f;
        float weight=u.wakes[i].z*f;
        vec2 swirl=vec2(-delta.y,delta.x)*.25;
        displacement+=(delta*1.4+swirl+u.pushes[i].xy*u.size*.035)*weight;
        totalWeight+=abs(weight);
    }
    displacement/=max(1.,totalWeight);
    p+=displacement/scale;
    float pixels=radius*max(.15,scale/110.);
    if (seed<.10 && !infalling) { pixels*=8.; brightness*=.018; }
    brightness*=2.2;
    float along=pixels*trail*u.dpr, across=pixels*.7*u.dpr;
    // The square sprite encloses the streak at any orientation.
    float side=max(along,across)+.5;
    gl_PointSize=2.*side;
    shape=vec4(tangent,side/along,side/across);
    // Far-side particles disappear behind the event-horizon silhouette.
    light=brightness*sqrt(u.density)*u.opacity*mix(1.,smoothstep(1.,1.025,length(p)),behind);
    gl_Position=u.matrix*vec4(center+p*scale,0.,1.);
}
