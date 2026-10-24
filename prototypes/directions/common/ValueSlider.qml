import QtQuick
import QtQuick.Controls as Controls
Item {
    id:root
    property var tokens
    property var fonts
    property string icon: "speaker-high"
    property string label: "Volumen"
    property alias value: slider.value
    property alias from: slider.from
    property alias to: slider.to
    height:86
    Icon { x:0;y:0;fonts:root.fonts;name:root.icon;color:tokens.muted;font.pixelSize:22 }
    Label { x:38;y:0;tokens:root.tokens;text:root.label;font.pixelSize:16;height:27 }
    Label { anchors.right:parent.right;y:0;tokens:root.tokens;text:Math.round(slider.value*100)+" %";font.pixelSize:14;height:27;color:tokens.muted }
    Controls.Slider {
        id:slider;objectName:root.label;x:0;y:36;width:parent.width;height:30;from:0;to:1;value:.65
        Accessible.name:root.label
        background: Rectangle { x:0;y:12;width:slider.availableWidth;height:6;radius:3;color:tokens.line
            Rectangle { width:slider.visualPosition*parent.width;height:6;radius:3;color:tokens.accent }
        }
        handle:Rectangle { x:slider.leftPadding+slider.visualPosition*(slider.availableWidth-width);y:5;width:20;height:20;radius:10;color:tokens.text;border.color:tokens.surface;border.width:3 }
    }
}
