import QtQuick
import "Data.js" as Data
Item {
    id: root
    property var tokens
    property var fonts
    property Item backdrop
    property int material: 1
    property real intensity: .55
    property bool alternate: false
    signal dismissed()
    Glass { anchors.fill:parent;backdrop:root.backdrop;tokens:root.tokens;material:root.material;intensity:root.intensity }
    Icon { x:28;y:30;name:"magnifying-glass";fonts:root.fonts;color:tokens.accent;font.pixelSize:28 }
    TextInput {
        id:query;x:78;y:28;width:parent.width-180;height:42;text:"singlr";color:tokens.text
        font.family:tokens.family;font.pixelSize:root.alternate?30:25;selectByMouse:true;clip:true
        onAccepted:root.dismissed()
        Accessible.name:"Buscar aplicaciones, archivos y acciones"
    }
    Rectangle { anchors.right:parent.right;anchors.rightMargin:26;y:33;width:48;height:28;radius:5;color:tokens.raised;border.color:tokens.line
        Label { anchors.centerIn:parent;tokens:root.tokens;text:"esc";font.pixelSize:13;color:tokens.muted }
        MouseArea { anchors.fill:parent;onClicked:root.dismissed() }
    }
    Rectangle { x:24;y:92;width:parent.width-48;height:1;color:tokens.line }
    Column { x:20;y:116;width:parent.width-40;spacing:6
        Label { x:14;tokens:root.tokens;text:"MEJOR RESULTADO";font.pixelSize:12;font.letterSpacing:1.6;color:tokens.muted;height:30 }
        Rectangle { width:parent.width;height:root.alternate?100:80;radius:8;color:tokens.selected
            Image { x:18;anchors.verticalCenter:parent.verticalCenter;source:Data.apps[0].path;width:42;height:42 }
            Column { x:80;y:17;spacing:5
                Label { tokens:root.tokens;text:"Singlr";font.pixelSize:21;font.weight:Font.Medium }
                Label { tokens:root.tokens;text:"Carpeta  ·  Personal / Proyectos";font.pixelSize:15;color:tokens.muted }
            }
            Icon { anchors.right:parent.right;anchors.rightMargin:20;anchors.verticalCenter:parent.verticalCenter;name:"arrow-elbow-down-left";fonts:root.fonts;color:tokens.accent }
            MouseArea { anchors.fill:parent;onClicked:root.dismissed() }
        }
        Item { width:1;height:16 }
        Label { x:14;tokens:root.tokens;text:"ARCHIVOS";font.pixelSize:12;font.letterSpacing:1.6;color:tokens.muted;height:30 }
        Repeater { model:["Visión del escritorio.md|Singlr / Documentos  ·  Hoy","Notas de exploración.md|Singlr / Interfaz  ·  Ayer"]
            Rectangle { required property string modelData; width:parent.width;height:root.alternate?82:66;radius:6;color:mouse.containsMouse?tokens.raised:"transparent"
                Icon { x:20;y:20;name:"file-text";fonts:root.fonts;color:tokens.muted;font.pixelSize:27 }
                Column { x:80;y:12;spacing:5
                    Label { tokens:root.tokens;text:modelData.split("|")[0];font.pixelSize:root.alternate?20:17 }
                    Label { tokens:root.tokens;text:modelData.split("|")[1];font.pixelSize:14;color:tokens.muted }
                }
                MouseArea { id:mouse;anchors.fill:parent;hoverEnabled:true;onClicked:root.dismissed() }
            }
        }
        Item { width:1;height:12 }
        Label { x:14;tokens:root.tokens;text:"APLICACIONES Y ACCIONES";font.pixelSize:12;font.letterSpacing:1.6;color:tokens.muted;height:30 }
        Row { spacing:16;x:14;height:58
            Image { source:Data.apps[3].path;width:30;height:30;anchors.verticalCenter:parent.verticalCenter }
            Label { tokens:root.tokens;text:"Abrir Singlr en Kate";height:58;font.pixelSize:root.alternate?20:17 }
        }
        Row { spacing:16;x:14;height:48
            Icon { name:"terminal-window";fonts:root.fonts;color:tokens.muted;anchors.verticalCenter:parent.verticalCenter }
            Label { tokens:root.tokens;text:"Abrir terminal aquí";height:48;font.pixelSize:root.alternate?20:17 }
        }
    }
    Rectangle { x:24;anchors.bottom:parent.bottom;anchors.bottomMargin:57;width:parent.width-48;height:1;color:tokens.line }
    Label { x:34;anchors.bottom:parent.bottom;anchors.bottomMargin:20;tokens:root.tokens;text:"↑ ↓  Navegar       ↵  Abrir";font.pixelSize:13;color:tokens.muted }
    Label { anchors.right:parent.right;anchors.rightMargin:30;anchors.bottom:parent.bottom;anchors.bottomMargin:20;tokens:root.tokens;text:"Buscar en todo";font.pixelSize:13;color:tokens.muted }
}
