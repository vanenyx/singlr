.pragma library
var serial = 0;
var session = Date.now().toString(36)+Math.random().toString(36).slice(2,8);
function nextId() { return ++serial; }
// Three separable box passes approximate a Gaussian. Applied to actual scene
// pixels, at quarter resolution, for Qt's headless software scenegraph.
function gaussian(data, w, h, radius) {
    var a = new Float32Array(w*h*4), b = new Float32Array(a.length);
    for(var n=0;n<a.length;n++) a[n]=data[n];
    for(var pass=0;pass<3;pass++) {
        for(var y=0;y<h;y++) for(var ch=0;ch<3;ch++) {
            var sum=0;
            for(var k=-radius;k<=radius;k++) sum+=a[(y*w+Math.max(0,Math.min(w-1,k)))*4+ch];
            for(var x=0;x<w;x++) {
                b[(y*w+x)*4+ch]=sum/(radius*2+1);
                sum+=a[(y*w+Math.min(w-1,x+radius+1))*4+ch]-a[(y*w+Math.max(0,x-radius))*4+ch];
            }
        }
        for(var x2=0;x2<w;x2++) for(var ch2=0;ch2<3;ch2++) {
            var sum2=0;
            for(var k2=-radius;k2<=radius;k2++) sum2+=b[(Math.max(0,Math.min(h-1,k2))*w+x2)*4+ch2];
            for(var y2=0;y2<h;y2++) {
                a[(y2*w+x2)*4+ch2]=sum2/(radius*2+1);
                sum2+=b[(Math.min(h-1,y2+radius+1)*w+x2)*4+ch2]-b[(Math.max(0,y2-radius)*w+x2)*4+ch2];
            }
        }
    }
    for(var i=0;i<data.length;i++) data[i]=i%4===3?255:a[i];
}
