#version 440
layout(location=0) in vec2 uv;
layout(location=1) in float light;
layout(location=2) in vec2 scene;
layout(location=3) in float behind;
layout(location=0) out vec4 fragColor;
void main() {
    float d=dot(uv,uv);
    if (d>1.) discard;
    // Far-side particles disappear behind the event-horizon silhouette.
    float mask=mix(1.,smoothstep(1.,1.025,length(scene)),behind);
    float point=exp(-d*4.5)*(1.-smoothstep(.6,1.,d));
    float value=point*light*mask;
    fragColor=vec4(vec3(value),0.);
}
