.pragma library
// sRGB ↔ CIELAB. Generate neutral levels by perceptual lightness, independently
// from the accent. A changed accent can never tint a work surface.
function linear(v) { return v <= .04045 ? v/12.92 : Math.pow((v+.055)/1.055,2.4); }
function gamma(v) { return v <= .0031308 ? 12.92*v : 1.055*Math.pow(v,1/2.4)-.055; }
function lab(c) {
    var r=linear(c.r),g=linear(c.g),b=linear(c.b);
    function f(v) { return v>.008856 ? Math.cbrt(v) : 7.787*v+16/116; }
    var x=f((.4124564*r+.3575761*g+.1804375*b)/.95047);
    var y=f(.2126729*r+.7151522*g+.072175*b);
    var z=f((.0193339*r+.119192*g+.9503041*b)/1.08883);
    return [116*y-16,500*(x-y),200*(y-z)];
}
function lch(c) { var a=lab(c); return [a[0],Math.hypot(a[1],a[2]),Math.atan2(a[2],a[1])]; }
function color(l,c,h) {
    var fy=(Math.max(0,Math.min(100,l))+16)/116;
    var fx=fy+c*Math.cos(h)/500,fz=fy-c*Math.sin(h)/200;
    function f(v) { return v*v*v>.008856 ? v*v*v : (v-16/116)/7.787; }
    var x=.95047*f(fx), y=f(fy), z=1.08883*f(fz);
    function clamp(v) { return Math.max(0,Math.min(1,gamma(v))); }
    return Qt.rgba(clamp(3.2404542*x-1.5371385*y-.4985314*z),clamp(-.969266*x+1.8760108*y+.041556*z),clamp(.0556434*x-.2040259*y+1.0572252*z),1);
}
function level(base,offset,contrast) {
    var b=lch(base); return color(b[0]+offset*contrast,Math.min(.7,b[1]),b[2]);
}
function alpha(c,a) { return Qt.rgba(c.r,c.g,c.b,a); }
function ink(base,target,contrast) {
    var b=lch(base);
    return color(b[0]+(target-b[0])*contrast,Math.min(.8,b[1]),b[2]);
}
function accentInk(accent,dark,contrast) {
    var a=lch(accent);
    return color((dark?74:43)+(dark?1:-1)*(contrast-1)*12,Math.min(62,a[1]),a[2]);
}
