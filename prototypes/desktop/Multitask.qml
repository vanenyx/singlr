pragma ComponentBehavior: Bound
import QtQuick
Item {
    id: overview
    property int space:0
    signal chosen(string kind)
    Row { x:164; y:140; spacing:12
        UiText { text:"Espacios"; font.pixelSize:13; weight:590; height:28; color:Theme.secondary }
        Icon { name:"caret-right"; height:28; width:12; font.pixelSize:12; color:Theme.faint }
        UiText { text:["Escritorio","Lectura","Personal"][overview.space]; height:28; font.pixelSize:12; color:Theme.muted }
    }
    Repeater { model:[{kind:"files",x:164,y:234,w:990,h:650,s:.69},{kind:"tasks",x:948,y:234,w:1040,h:660,s:.78},{kind:"terminal",x:164,y:766,w:620,h:304,s:.78}]
        Item { id:preview; required property var modelData; width:modelData.w*modelData.s; height:modelData.h*modelData.s+42; x:modelData.x; y:modelData.y
            AppWindow { kind:preview.modelData.kind; width:preview.modelData.w; height:preview.modelData.h; scale:preview.modelData.s; transformOrigin:Item.TopLeft; thumbnail:true; active:false; enabled:false }
            Rectangle { anchors.fill:parent; anchors.bottomMargin:42; radius:12; color:"transparent"; border.color:previewMouse.containsMouse?Theme.accentText:"transparent" }
            Row { y:parent.height-25; spacing:8
                Icon { name:preview.modelData.kind==="files"?"folder":preview.modelData.kind==="tasks"?"check-circle":"terminal"; color:Theme.muted }
                UiText { text:preview.modelData.kind==="files"?"Archivos · Singlr":preview.modelData.kind==="tasks"?"Tareas · Mis tareas":"Terminal · singlr"; height:16; color:Theme.secondary; font.pixelSize:12 }
            }
            MouseArea { id:previewMouse; anchors.fill:parent; hoverEnabled:true; onClicked:overview.chosen(preview.modelData.kind) }
        }
    }
    Row { x:948; y:908; spacing:16
        Repeater { model:["Escritorio","Lectura","Personal"]
            Item { id:spaceCard; required property string modelData; required property int index; width:236; height:164
                Rectangle { width:236; height:132; radius:8; color:Theme.panel; border.color:overview.space===spaceCard.index?Theme.accentText:Theme.border
                    Rectangle { x:16; y:18; width:110; height:74; radius:3; color:Theme.content; border.color:Theme.border; visible:spaceCard.index===0 }
                    Rectangle { x:89; y:46; width:130; height:72; radius:3; color:Theme.raised; border.color:Theme.border; visible:spaceCard.index===0 }
                    Rectangle { x:22; y:18; width:192; height:96; radius:3; color:Theme.content; border.color:Theme.border; visible:spaceCard.index===1
                        Column { x:14; y:18; spacing:8
                            Repeater { model:6; Rectangle { required property int index; width:index===0?80:150; height:2; color:Theme.hover } }
                        }
                    }
                    Icon { anchors.centerIn:parent; name:"plus"; visible:spaceCard.index===2; color:Theme.faint }
                }
                UiText { y:142; height:20; text:(spaceCard.index+1)+"  "+spaceCard.modelData; font.pixelSize:11; color:overview.space===spaceCard.index?Theme.secondary:Theme.faint }
                MouseArea { anchors.fill:parent; onClicked:overview.space=spaceCard.index }
            }
        }
    }
}
