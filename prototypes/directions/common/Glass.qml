import QtQuick
import QtQuick.Effects
import "Blur.js" as Blur
Item {
    id: glass
    clip:true
    property Item backdrop
    property var tokens
    property int material: 1
    property real intensity: 0.55
    property real radius: tokens.radius
    property point origin: backdrop ? mapToItem(backdrop,0,0) : Qt.point(0,0)
    readonly property bool software: glass.GraphicsInfo.api === GraphicsInfo.Software
    property string grabUrl: ""
    property int cacheId: Blur.nextId()
    property int cacheCycle: 0
    onVisibleChanged: refresh.restart()
    onMaterialChanged: { refresh.restart(); cpuBlur.requestPaint(); }
    onIntensityChanged: cpuBlur.requestPaint()
    Connections { target:glass.tokens; function onDarkChanged() { refresh.restart(); } }
    // Software fallback still blurs the real scene pixels; it is not a tint.
    // The source is always a lower scene layer; it never contains this effect.
    ShaderEffectSource {
        id: sample; visible: false
        sourceItem: glass.backdrop
        sourceRect: Qt.rect(glass.origin.x,glass.origin.y,glass.width,glass.height)
        textureSize: Qt.size(Math.max(1,glass.width/2),Math.max(1,glass.height/2))
        live: glass.visible && glass.material > 0
    }
    Rectangle {
        id: mask; anchors.fill: parent; radius: glass.radius; color: "white"; visible: false; layer.enabled: true
    }
    MultiEffect {
        anchors.fill: parent; visible: glass.material > 0 && !glass.software
        source: sample; autoPaddingEnabled: false; blurEnabled: true; blurMax: 64
        blur: glass.material === 2 ? .12 + glass.intensity*.28 : glass.tokens.blur
        saturation: -1.0
        maskEnabled: true; maskSource: mask
    }
    Canvas {
        id: cpuBlur; width:Math.ceil(parent.width/4);height:Math.ceil(parent.height/4)
        scale:4;transformOrigin:Item.TopLeft
        visible: glass.software && glass.material > 0
        onImageLoaded: requestPaint()
        onPaint: {
            if (!glass.grabUrl || !isImageLoaded(glass.grabUrl)) return;
            var c=getContext("2d"), w=canvasSize.width,h=canvasSize.height;
            c.reset();
            c.drawImage(glass.grabUrl, glass.origin.x,glass.origin.y,glass.width,glass.height,0,0,w,h);
            var pixels=c.getImageData(0,0,w,h);
            var data=pixels.data;
            Blur.gaussian(data,w,h,glass.material===2?Math.round(2+glass.intensity*2):7);
            // Neutral transmission: preserve luminance, suppress wallpaper tint.
            for(var i=0;i<data.length;i+=4) {
                var gray=.2126*data[i]+.7152*data[i+1]+.0722*data[i+2];
                data[i]=gray;data[i+1]=gray;data[i+2]=gray;
            }
            c.putImageData(pixels,0,0,0,0,w,h);
            c.globalCompositeOperation="destination-out";c.fillRule=Qt.OddEvenFill;
            c.beginPath();c.rect(0,0,w,h);c.roundedRect(0,0,w,h,glass.radius/4,glass.radius/4);c.fill();
        }
    }
    Timer {
        id:refresh; interval:450;running:glass.visible && glass.material>0;repeat:false
        onTriggered: {
            if(!glass.visible || glass.material===0 || !glass.backdrop || glass.backdrop.width<1 || glass.backdrop.height<1 || glass.width<1 || glass.height<1) return;
            glass.origin=glass.mapToItem(glass.backdrop,0,0);
            if(!glass.software) return;
            glass.backdrop.grabToImage(function(result) {
                if(glass.grabUrl) cpuBlur.unloadImage(glass.grabUrl);
                // Canvas does not resolve Qt's itemgrabber: URLs. A local cache
                // bridges the grab to Canvas; capture.sh removes it on exit.
                var path=Qt.resolvedUrl("../.blur-"+Blur.session+"-"+glass.cacheId+"-"+(glass.cacheCycle++%2)+".png").toString().replace("file://","");
                if(!result.saveToFile(path)) return;
                glass.grabUrl="file://"+path;
                cpuBlur.loadImage(glass.grabUrl);
            });
        }
    }
    Rectangle {
        anchors.fill: parent; radius: glass.radius
        color: glass.material === 0 ? glass.tokens.surface : (glass.material===2?glass.tokens.liquidTint:glass.tokens.glass)
        border.width: 1
        border.color: glass.tokens.dark ? "#25ffffff" : "#70ffffff"
    }
    // Liquid approximation: a specular rim, tighter transmitted blur and inner
    // light. This is deliberately separate from the classic frosted material.
    Item {
        anchors.fill: parent; visible: glass.material === 2
        Rectangle {
            anchors.fill:parent;radius:glass.radius;color:"transparent"
            gradient:Gradient {
                GradientStop { position:0;color:Qt.rgba(1,1,1,.04+glass.intensity*.08) }
                GradientStop { position:.28;color:"transparent" }
                GradientStop { position:.85;color:"transparent" }
                GradientStop { position:1;color:Qt.rgba(1,1,1,.02+glass.intensity*.025) }
            }
        }
        Rectangle {
            anchors.fill: parent; anchors.margins: 2; radius: Math.max(0,glass.radius-2); color: "transparent"
            border.width: 1; border.color: Qt.rgba(1,1,1,.06+glass.intensity*.12)
        }
        Rectangle {
            x: glass.radius; y: 1; width: parent.width-glass.radius*2; height: 1
            gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: "transparent" } GradientStop { position: .35; color: Qt.rgba(1,1,1,.3+glass.intensity*.4) } GradientStop { position: 1; color: "transparent" } }
        }
    }
}
