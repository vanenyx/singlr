pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
Item {
    id: panel
    property Item backdrop
    property bool crystal: true
    property bool wifi: true
    property bool bluetooth: true
    property bool dnd: false
    property int notificationCount: 2
    width:364; height:654
    signal powerRequested()
    Shadow { anchors.fill:parent; strength:1.1 }
    Glass { anchors.fill:parent; backdrop:panel.backdrop; crystal:panel.crystal }
    UiText { x:20; y:14; height:28; text:"Controles"; weight:590 }
    Row { anchors.right:parent.right; anchors.rightMargin:12; y:14; spacing:4
        Tool { icon:"gear"; description:"Cambiar apariencia"; onClicked:Theme.dark=!Theme.dark }
        Tool { icon:"power"; description:"Energía"; onClicked:panel.powerRequested() }
    }
    Column { x:12; y:53; spacing:3
        Repeater { model:[{icon:"wifi-high",title:"Red",detail:panel.wifi?"Estudio · Conectado":"Desconectada",on:panel.wifi},{icon:"bluetooth",title:"Bluetooth",detail:panel.bluetooth?"2 dispositivos":"Desactivado",on:panel.bluetooth}]
            Rectangle { id:connectRow; required property var modelData; required property int index
                width:340; height:48; radius:6; color:connectHover.containsMouse?Theme.hover:"transparent"
                Icon { x:8; y:16; name:connectRow.modelData.icon; color:connectRow.modelData.on?Theme.secondary:Theme.faint }
                UiText { x:36; y:4; height:21; text:connectRow.modelData.title; font.pixelSize:12; color:Theme.secondary }
                UiText { x:36; y:25; height:16; text:connectRow.modelData.detail; font.pixelSize:11; color:Theme.muted }
                Rectangle { x:292; y:16; width:28; height:16; radius:8; color:connectRow.modelData.on?Theme.accent:Theme.hover
                    Rectangle { x:connectRow.modelData.on?14:2; y:2; width:12; height:12; radius:6; color:Theme.dark?"#eeeeef":"white" }
                }
                Accessible.role:Accessible.CheckBox; Accessible.name:connectRow.modelData.title; Accessible.checked:connectRow.modelData.on
                activeFocusOnTab:true
                function toggle() { if(index===0) panel.wifi=!panel.wifi; else panel.bluetooth=!panel.bluetooth; }
                Keys.onSpacePressed:toggle()
                MouseArea { id:connectHover; anchors.fill:parent; hoverEnabled:true; onClicked:connectRow.toggle() }
            }
        }
    }
    Rectangle { x:20; y:159; width:parent.width-40; height:1; color:Theme.faintBorder }
    Column { x:20; y:173; spacing:12
        Repeater { model:[["speaker-high","Audio",62,"Altavoces integrados"],["sun","Brillo",74,"Pantalla integrada"]]
            Item { id:sliderRow; required property var modelData; width:324; height:57
                Icon { x:0; y:2; name:sliderRow.modelData[0] }
                UiText { x:28; height:20; text:sliderRow.modelData[1]; font.pixelSize:12; color:Theme.secondary }
                UiText { anchors.right:parent.right; height:20; text:Math.round(slider.value)+" %"; font.pixelSize:11; color:Theme.muted }
                Slider { id:slider; x:25; y:21; width:300; height:24; from:0; to:100; value:sliderRow.modelData[2]
                    Accessible.name:sliderRow.modelData[1]
                    background:Rectangle { x:slider.leftPadding; y:(slider.height-height)/2; width:slider.availableWidth; height:4; radius:2; color:Theme.hover
                        Rectangle { width:slider.visualPosition*parent.width; height:4; radius:2; color:Theme.secondary }
                    }
                    handle:Rectangle { x:slider.leftPadding+slider.visualPosition*(slider.availableWidth-width); y:(slider.height-height)/2; width:12; height:12; radius:6; color:Theme.text; border.color:slider.activeFocus?Theme.accent:Theme.border }
                }
                UiText { x:28; y:44; height:14; text:sliderRow.modelData[3]; font.pixelSize:10; color:Theme.faint }
            }
        }
    }
    Rectangle { x:20; y:315; width:parent.width-40; height:1; color:Theme.faintBorder }
    Row { x:20; y:331; spacing:12
        Icon { name:"battery-high"; color:Theme.muted; y:4 }
        UiText { text:"Energía"; height:24; width:100; font.pixelSize:12; color:Theme.secondary }
        UiText { text:"86 % · Equilibrado"; height:24; width:180; horizontalAlignment:Text.AlignRight; font.pixelSize:11; color:Theme.muted }
    }
    Rectangle { x:12; y:367; width:340; height:38; radius:6; color:dndMouse.containsMouse?Theme.hover:"transparent"; activeFocusOnTab:true
        Accessible.role:Accessible.CheckBox; Accessible.name:"No molestar"; Accessible.checked:panel.dnd
        Keys.onSpacePressed:panel.dnd=!panel.dnd
        Icon { x:8; y:11; name:"moon" }
        UiText { x:36; height:38; text:"No molestar"; font.pixelSize:12; color:Theme.secondary }
        UiText { anchors.right:parent.right; anchors.rightMargin:12; height:38; text:panel.dnd?"Activado":"Desactivado"; font.pixelSize:11; color:panel.dnd?Theme.accentText:Theme.muted }
        MouseArea { id:dndMouse; anchors.fill:parent; hoverEnabled:true; onClicked:panel.dnd=!panel.dnd }
    }
    Item { x:20; y:416; width:324; height:28
        UiText { text:"Material"; height:28; font.pixelSize:12; color:Theme.secondary }
        Row { anchors.right:parent.right; spacing:2
            Repeater { model:["Mate","Cristal"]
                Rectangle { id:materialButton; required property string modelData; required property int index; width:62; height:26; radius:5
                    color:panel.crystal===(index===1)?Theme.hover:"transparent"
                    border.color:activeFocus?Theme.accentText:"transparent"; activeFocusOnTab:true
                    Accessible.role:Accessible.RadioButton; Accessible.name:modelData; Accessible.checked:panel.crystal===(index===1)
                    Keys.onSpacePressed:panel.crystal=index===1
                    UiText { anchors.centerIn:parent; text:materialButton.modelData; font.pixelSize:11; color:panel.crystal===(materialButton.index===1)?Theme.secondary:Theme.faint }
                    MouseArea { anchors.fill:parent; onClicked:panel.crystal=materialButton.index===1 }
                }
            }
        }
    }
    Rectangle { x:20; y:461; width:parent.width-40; height:1; color:Theme.border }
    UiText { x:20; y:475; height:24; text:"Notificaciones"; font.pixelSize:12; weight:590; color:Theme.secondary }
    UiText { x:parent.width-38; y:475; height:24; text:panel.notificationCount; font.pixelSize:11; color:Theme.faint }
    Column { x:20; y:512; spacing:16
        Repeater { model:panel.notificationCount ? [["check-circle","Tareas","Revisión de interfaz","La revisión empieza a las 12:00.","8 min"],["download","Archivos","Descarga completada","Inter-4.1.zip · 2,8 MB","22 min"]] : []
            Item { id:notification; required property var modelData; width:324; height:47
                Icon { x:0; y:2; name:notification.modelData[0]; color:Theme.faint }
                UiText { x:28; height:15; text:notification.modelData[1]; font.pixelSize:10; color:Theme.faint }
                UiText { anchors.right:parent.right; height:15; text:notification.modelData[4]; font.pixelSize:10; color:Theme.faint }
                UiText { x:28; y:17; height:17; text:notification.modelData[2]; font.pixelSize:12; color:Theme.secondary }
                UiText { x:28; y:36; height:14; text:notification.modelData[3]; font.pixelSize:11; color:Theme.muted }
            }
        }
    }
}
