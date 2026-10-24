import QtQuick
Item {
    id:root
    objectName:"controlsPanel"
    property var tokens
    property var fonts
    property Item backdrop
    property int material:1
    property real intensity:.55
    property bool wifi:true
    property bool quiet:true
    signal materialSelected(int value)
    signal intensitySelected(real value)
    Glass { anchors.fill:parent;tokens:root.tokens;backdrop:root.backdrop;material:root.material;intensity:root.intensity }
    Column { x:28;y:28;width:parent.width-56;spacing:22
        Row { width:parent.width
            Label { tokens:root.tokens;text:"Controles";font.pixelSize:28;font.weight:Font.DemiBold;width:parent.width-40 }
            Tool { tokens:root.tokens;fonts:root.fonts;icon:"gear-six";width:36;height:36 }
        }
        Row { spacing:12;width:parent.width
            Rectangle { width:(parent.width-12)/2;height:114;radius:8;color:root.wifi?tokens.selected:tokens.raised
                Icon { x:18;y:16;fonts:root.fonts;name:"wifi-high";color:tokens.accent }
                Label { x:18;y:53;tokens:root.tokens;text:"Wi-Fi";font.pixelSize:17 }
                Label { x:18;y:80;tokens:root.tokens;text:root.wifi?"Casa · Conectado":"Desactivado";font.pixelSize:13;color:tokens.muted }
                MouseArea { anchors.fill:parent;onClicked:root.wifi=!root.wifi }
            }
            Rectangle { width:(parent.width-12)/2;height:114;radius:8;color:tokens.raised
                Icon { x:18;y:16;fonts:root.fonts;name:"bluetooth";color:tokens.muted }
                Label { x:18;y:53;tokens:root.tokens;text:"Bluetooth";font.pixelSize:17 }
                Label { x:18;y:80;tokens:root.tokens;text:"Disponible";font.pixelSize:13;color:tokens.muted }
            }
        }
        ValueSlider { width:parent.width;tokens:root.tokens;fonts:root.fonts;label:"Audio · Altavoces";icon:"speaker-high";value:.64 }
        ValueSlider { width:parent.width;tokens:root.tokens;fonts:root.fonts;label:"Brillo de pantalla";icon:"sun";value:.78 }
        Rectangle { width:parent.width;height:1;color:tokens.line }
        Row { width:parent.width;spacing:12
            Icon { fonts:root.fonts;name:"battery-high";color:tokens.accent }
            Label { tokens:root.tokens;text:"86 %";font.pixelSize:18;width:65;height:28 }
            Label { tokens:root.tokens;text:"Equilibrado · 5 h restantes";font.pixelSize:14;color:tokens.muted;height:28 }
        }
        Rectangle { width:parent.width;height:65;radius:7;color:tokens.raised
            Icon { x:16;y:19;fonts:root.fonts;name:"bell-slash";color:tokens.muted }
            Label { x:58;y:20;tokens:root.tokens;text:"No molestar";font.pixelSize:16 }
            Rectangle { anchors.right:parent.right;anchors.rightMargin:16;y:22;width:38;height:22;radius:11;color:root.quiet?tokens.accent:tokens.line
                Rectangle { x:root.quiet?19:3;y:3;width:16;height:16;radius:8;color:tokens.surface }
            }
            MouseArea { anchors.fill:parent;onClicked:root.quiet=!root.quiet }
        }
        Rectangle { width:parent.width;height:1;color:tokens.line }
        Column { width:parent.width;spacing:12
            Label { tokens:root.tokens;text:"Material del escritorio";font.pixelSize:18;font.weight:Font.Medium }
            Label { tokens:root.tokens;text:"Apariencia de las superficies flotantes";font.pixelSize:14;color:tokens.muted }
            Row { width:parent.width;spacing:6
                Repeater { model:["Mate","Cristal","Liquid Glass"]
                    Rectangle { required property int index;required property string modelData;objectName:"material-"+index;Accessible.role:Accessible.Button;Accessible.name:modelData;width:(parent.width-12)/3;height:42;radius:6;color:root.material===index?tokens.selected:tokens.raised;border.color:root.material===index?tokens.accent:"transparent"
                        Label { anchors.centerIn:parent;tokens:root.tokens;text:modelData;font.pixelSize:13;color:root.material===index?tokens.accent:tokens.muted }
                        MouseArea { anchors.fill:parent;onClicked:root.materialSelected(index) }
                    }
                }
            }
        }
        ValueSlider { width:parent.width;tokens:root.tokens;fonts:root.fonts;label:"Intensidad de Liquid Glass";icon:"drop-half";value:root.intensity;opacity:root.material===2?1:.45;enabled:root.material===2;onValueChanged:root.intensitySelected(value) }
        Label { tokens:root.tokens;text:"Sin notificaciones nuevas";font.pixelSize:14;color:tokens.muted }
    }
}
