#version 440
layout(location=0) in vec4 shape;
layout(location=1) in float light;
layout(location=0) out vec4 fragColor;
void main() {
    // Rotate the sprite coordinates into the streak's frame.
    vec2 q=gl_PointCoord*2.-1.;
    vec2 uv=vec2(dot(q,shape.xy),dot(q,vec2(-shape.y,shape.x)))*shape.zw;
    float d=dot(uv,uv);
    if (d>1.) discard;
    float point=exp(-d*4.5)*(1.-smoothstep(.6,1.,d));
    fragColor=vec4(vec3(point*light),0.);
}
