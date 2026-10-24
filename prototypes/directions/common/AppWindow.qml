import QtQuick
import QtQuick.Effects
import "Data.js" as Data
Item {
    id: app
    property var tokens
    property var fonts
    property string kind: "files"
    property bool alternate: false
    property bool active: true
    property bool thumbnail:false
    readonly property int bar:tokens.titlebar
    property string title: kind === "files" ? "Singlr" : kind === "editor" ? "Visión del escritorio" : "Terminal"
    Repeater { model: app.thumbnail?0:6
        Rectangle { required property int index
            x:-8-index*4;y:3-index*3;width:app.width+16+index*8;height:app.height+20+index*7
            radius:app.tokens.radius+index*3;color:Qt.rgba(0,0,0,.018);visible:app.GraphicsInfo.api===GraphicsInfo.Software
        }
    }
    RectangularShadow { visible:!app.thumbnail && app.GraphicsInfo.api!==GraphicsInfo.Software; anchors.fill: frame; radius: tokens.radius; blur: 55; offset: Qt.vector2d(0,20); color: tokens.shadow }
    Rectangle {
        id: frame; anchors.fill: parent; radius: tokens.radius; color: tokens.surface; border.color: active ? tokens.line : tokens.inset; clip: true;layer.enabled:app.thumbnail;layer.smooth:true
        Rectangle { x:1;y:1; width: parent.width-2; height: app.bar-1; radius: tokens.radius; color: tokens.inset }
        Row { x:22; y:(app.bar-28)/2; spacing:12
            Image { width:27;height:27; source: Data.apps[kind==="files"?0:kind==="editor"?3:2].path }
            Label { tokens: app.tokens; text: app.title; font.pixelSize:16; font.weight:Font.Medium; height:28 }
        }
        Row { anchors.right:parent.right; anchors.rightMargin:18; y:(app.bar-32)/2; spacing:10
            Tool { tokens:app.tokens; fonts:app.fonts; icon:"minus"; width:32;height:32 }
            Tool { tokens:app.tokens; fonts:app.fonts; icon:"corners-out"; width:32;height:32 }
            Tool { tokens:app.tokens; fonts:app.fonts; icon:"x"; width:32;height:32 }
        }
        Rectangle { y:app.bar-1;width:parent.width;height:1;color:tokens.line }
        Item {
            visible: app.kind==="files"; y:app.bar; width:parent.width;height:parent.height-app.bar
            Rectangle { width:tokens.sidebar;height:parent.height;color:tokens.inset;bottomLeftRadius:tokens.radius }
            Column { x:16;y:24; spacing:5
                Repeater { model:["house|Inicio","clock|Recientes","star|Favoritos","folder-simple|Proyectos","download-simple|Descargas"]
                    Tool { required property string modelData; required property int index; tokens:app.tokens; fonts:app.fonts; icon:modelData.split("|")[0];label:modelData.split("|")[1];width:tokens.sidebar-32;leftAligned:true;selected:index===3 }
                }
                Item { width:1;height:26 }
                Label { tokens:app.tokens;text:"ESPACIOS";font.pixelSize:12;font.letterSpacing:1.5;x:12;color:tokens.muted }
                Tool { tokens:app.tokens;fonts:app.fonts;icon:"circle";label:"Personal";width:tokens.sidebar-32;leftAligned:true }
                Tool { tokens:app.tokens;fonts:app.fonts;icon:"hard-drives";label:"Este equipo";width:tokens.sidebar-32;leftAligned:true }
            }
            Item { x:tokens.sidebar+28;y:22;width:parent.width-tokens.sidebar-56;height:parent.height-44
                Row { spacing:8
                    Tool { tokens:app.tokens;fonts:app.fonts;icon:"arrow-left";width:36 }
                    Tool { tokens:app.tokens;fonts:app.fonts;icon:"caret-right";width:28 }
                    Label { tokens:app.tokens;text:"Proyectos";height:44;color:tokens.muted;font.pixelSize:16 }
                    Icon { fonts:app.fonts;name:"caret-right";color:tokens.muted;anchors.verticalCenter:parent.verticalCenter;font.pixelSize:14 }
                    Label { tokens:app.tokens;text:"Singlr";height:44;font.pixelSize:16 }
                }
                Row { anchors.right:parent.right;spacing:4
                    Tool { tokens:app.tokens;fonts:app.fonts;icon:"magnifying-glass" }
                    Tool { tokens:app.tokens;fonts:app.fonts;icon:"list";selected:true }
                    Tool { tokens:app.tokens;fonts:app.fonts;icon:"dots-three" }
                }
                Label { y:86;tokens:app.tokens;text:"Singlr";font.pixelSize:tokens.heading;font.weight:Font.DemiBold }
                Label { y:tokens.heading+102;tokens:app.tokens;text:"Proyectos  /  6 elementos";color:tokens.muted;font.pixelSize:16 }
                Row { y:tokens.tableTop;spacing:0
                    Label { tokens:app.tokens;text:"Nombre";width:Math.max(408,parent.parent.width-382);font.pixelSize:14;color:tokens.muted }
                    Label { tokens:app.tokens;text:"Modificado";width:190;font.pixelSize:14;color:tokens.muted }
                    Label { tokens:app.tokens;text:"Tamaño";font.pixelSize:14;color:tokens.muted }
                }
                Column { y:tokens.tableTop+36;width:parent.width;spacing:4
                    Repeater { model:Data.files
                        Rectangle { required property var modelData; required property int index; width:parent.width;height:tokens.rowHeight;radius:6;color:index===3?tokens.selected:"transparent"
                            Row { x:14;anchors.verticalCenter:parent.verticalCenter;spacing:16
                                Icon { name:modelData.icon;fonts:app.fonts;color:modelData.tint;font.pixelSize:26 }
                                Label { tokens:app.tokens;text:modelData.name;width:Math.max(332,parent.parent.width-458);height:30;font.pixelSize:tokens.body }
                                Label { tokens:app.tokens;text:modelData.date;width:174;height:30;font.pixelSize:15;color:tokens.muted }
                                Label { tokens:app.tokens;text:modelData.size;height:30;font.pixelSize:15;color:tokens.muted }
                            }
                        }
                    }
                }
                Label { anchors.bottom:parent.bottom;tokens:app.tokens;text:"6 elementos   ·   1 seleccionado";font.pixelSize:14;color:tokens.muted }
            }
        }
        Item {
            visible:app.kind==="editor"; y:app.bar;width:parent.width;height:parent.height-app.bar
            Rectangle { width:tokens.sidebar;height:parent.height;color:tokens.inset;bottomLeftRadius:tokens.radius }
            Column { x:24;y:32;spacing:20
                Label { tokens:app.tokens;text:"CUADERNO";font.pixelSize:12;font.letterSpacing:2;color:tokens.muted }
                Tool { tokens:app.tokens;fonts:app.fonts;icon:"file-text";label:"Visión";selected:true;width:tokens.sidebar-32;leftAligned:true }
                Tool { tokens:app.tokens;fonts:app.fonts;icon:"squares-four";label:"Materiales";width:tokens.sidebar-32;leftAligned:true }
                Tool { tokens:app.tokens;fonts:app.fonts;icon:"compass";label:"Referencias";width:tokens.sidebar-32;leftAligned:true }
            }
            Column { x:tokens.sidebar+60;y:54;width:parent.width-tokens.sidebar-120;spacing:25
                Label { tokens:app.tokens;text:"SINGLR  /  NOTAS DE DISEÑO";font.pixelSize:13;font.letterSpacing:2;color:tokens.accent }
                Label { tokens:app.tokens;text:"Espacio para\npensar con claridad.";font.pixelSize:tokens.editorTitle;font.weight:Font.DemiBold;lineHeight:1.12 }
                Label { tokens:app.tokens;width:parent.width;text:"Un escritorio sereno, preciso y personal. La tecnología\nacompaña al trabajo y deja que las ideas respiren.";font.pixelSize:tokens.body+1;lineHeight:1.6;color:tokens.muted }
                Rectangle { width:parent.width;height:1;color:tokens.line }
                Label { tokens:app.tokens;text:"01   El trabajo, en primer plano";font.pixelSize:24;font.weight:Font.Medium }
                Label { tokens:app.tokens;width:parent.width;text:"Superficies tranquilas para leer y crear. Controles que\naparecen donde se necesitan; profundidad que orienta.";font.pixelSize:19;lineHeight:1.6;color:tokens.muted }
                Row { spacing:12
                    Repeater { model:["Identidad propia","Claridad","Continuidad"]
                        Rectangle { required property string modelData; width:tag.implicitWidth+26;height:36;radius:5;color:tokens.selected
                            Label { id:tag;tokens:app.tokens;text:modelData;font.pixelSize:14;anchors.centerIn:parent;color:tokens.accent }
                        }
                    }
                }
                Label { tokens:app.tokens;text:"02   Una capa de calma";font.pixelSize:24;font.weight:Font.Medium }
            }
            Label { x:tokens.sidebar+60;anchors.bottom:parent.bottom;anchors.bottomMargin:22;tokens:app.tokens;text:"Guardado localmente     ·     Markdown";font.pixelSize:13;color:tokens.muted }
        }
        Column {
            visible:app.kind==="terminal";x:28;y:app.bar+24;spacing:14
            Label { tokens:app.tokens;text:"~/Proyectos/singlr  ·  main";color:tokens.accent;font.pixelSize:18 }
            Label { tokens:app.tokens;text:"❯  git status --short\n  M  prototypes/directions/a/Main.qml\n  M  prototypes/directions/b/Main.qml\n\n❯  qml6 --version\nQml Runtime 6.12.0\n\n❯  ls prototypes/directions\na/   b/   common/   captures/";font.family:"monospace";font.pixelSize:16;lineHeight:1.5 }
            Label { tokens:app.tokens;text:"❯  _";color:tokens.accent }
        }
    }
}
