import QtQuick
Item {
    id:root
    property bool dark:true
    property bool alternate:false
    Rectangle { anchors.fill:parent;color:root.dark?"#191919":"#dedede" }
    Canvas {
        id:painting;anchors.fill:parent
        onWidthChanged:requestPaint()
        onHeightChanged:requestPaint()
        Connections { target:root;function onDarkChanged(){painting.requestPaint()} }
        onPaint: {
            var c=getContext("2d"),w=width,h=height;
            c.reset();
            var base=c.createLinearGradient(0,0,w,h);
            base.addColorStop(0,root.dark?"#161718":"#dadcdd");
            base.addColorStop(1,root.dark?"#343638":"#f2f2ef");
            c.fillStyle=base;c.fillRect(0,0,w,h);
            if(!root.alternate) {
                // Estrato: folded mineral planes, sharp geometry and a restrained olive light.
                var plane=c.createLinearGradient(w*.2,0,w*.8,h);
                plane.addColorStop(0,root.dark?"#656b50":"#c4c9b2");
                plane.addColorStop(.42,root.dark?"#343936":"#c8cdca");
                plane.addColorStop(1,root.dark?"#1b1d20":"#adb3b8");
                c.beginPath();c.moveTo(w*.12,0);c.lineTo(w*.72,0);c.lineTo(w*.47,h);c.lineTo(-w*.2,h);c.closePath();
                c.fillStyle=plane;c.fill();
                c.beginPath();c.moveTo(w*.72,0);c.lineTo(w*1.12,h*.35);c.lineTo(w*.47,h);c.closePath();
                var edge=c.createLinearGradient(w*.5,0,w*.8,h);edge.addColorStop(0,root.dark?"#404548":"#e5e7e6");edge.addColorStop(1,root.dark?"#1b1c1f":"#c0c3c6");c.fillStyle=edge;c.fill();
                c.beginPath();c.moveTo(w*.72,0);c.lineTo(w*.47,h);c.strokeStyle=root.dark?"rgba(232,239,209,.13)":"rgba(255,255,255,.55)";c.lineWidth=1;c.stroke();
            } else {
                // Margen: broad continuous silver contours, with amber light at the horizon.
                for(var i=0;i<5;i++) {
                    c.beginPath();c.moveTo(-w*.12,h*(.28+i*.16));
                    c.bezierCurveTo(w*.25,h*(1.03+i*.05),w*.67,h*(-.36+i*.22),w*1.15,h*(.1+i*.17));
                    c.lineTo(w*1.2,h*1.4);c.lineTo(-w*.2,h*1.4);c.closePath();
                    var band=c.createLinearGradient(w*.2,h,w*.8,0);
                    band.addColorStop(0,root.dark?"#17191c":"#a9afb5");
                    band.addColorStop(.55,root.dark?"#44494d":"#d8dcdf");
                    band.addColorStop(.85,root.dark?"#746654":"#efdfc9");
                    band.addColorStop(1,root.dark?"#b49b77":"#fff7e8");
                    c.fillStyle=band;c.fill();
                    c.strokeStyle=root.dark?"rgba(221,225,228,.12)":"rgba(255,255,255,.65)";c.lineWidth=2;c.stroke();
                }
            }
        }
    }
}
