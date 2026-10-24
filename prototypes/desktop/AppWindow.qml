pragma ComponentBehavior: Bound
import QtQuick
import "Data.js" as Data
Item {
    id: app
    property string kind: "files"
    property bool active: false
    property bool thumbnail: false
    property int selectedRow: kind === "files" ? 3 : 1
    readonly property bool files: kind === "files"
    readonly property bool terminal: kind === "terminal"
    readonly property string title: files ? "Archivos" : terminal ? "Terminal" : "Tareas"
    signal activated()
    signal dismissed()
    signal minimized()
    signal maximized()
    Shadow { anchors.fill: parent; strength: app.active?1:.55 }
    Rectangle { anchors.fill: parent; radius:12; color:Theme.content }
    // Navigation recedes; work content keeps the strongest contrast.
    Rectangle { visible:!app.terminal; width:184; height:parent.height; radius:12; color:Theme.panel }
    Rectangle { visible:!app.terminal; x:172; width:12; height:parent.height; color:Theme.panel }
    TapHandler { onTapped: app.activated() }
    Item { id: chrome; width:parent.width; height:40
        Row { x:16; spacing:8; height:40
            Image { visible:app.files || app.terminal; source:app.files?Data.apps[0].logo:Data.apps[1].logo; width:16; height:16; anchors.verticalCenter:parent.verticalCenter }
            Icon { visible:!app.files && !app.terminal; name:"check-circle"; color:Theme.muted; anchors.verticalCenter:parent.verticalCenter }
            UiText { text:app.title; color:app.active?Theme.secondary:Theme.muted; weight:510; height:40; font.pixelSize:12 }
        }
        UiText { visible:app.terminal; anchors.centerIn:parent; text:"singlr — bash"; font.pixelSize:12; color:Theme.faint }
        Row { anchors.right:parent.right; anchors.rightMargin:8; y:6; spacing:2
            Tool { icon:"minus"; description:"Minimizar "+app.title; onClicked:app.minimized() }
            Tool { icon:"arrows-out"; description:"Maximizar "+app.title; onClicked:app.maximized() }
            Tool { icon:"x"; description:"Cerrar "+app.title; onClicked:app.dismissed() }
        }
    }
    Item { visible:!app.terminal; x:0; y:48; width:184; height:parent.height-48
        Row { x:16; y:8; spacing:8
            Rectangle { width:18; height:18; radius:5; color:Theme.hover
                Rectangle { anchors.centerIn:parent; width:9; height:9; radius:5; color:"transparent"; border.width:1.5; border.color:Theme.secondary }
            }
            UiText { text:"Singlr"; weight:590; color:Theme.secondary; height:18 }
            Icon { name:"caret-down"; width:14; height:18; font.pixelSize:12 }
        }
        Column { x:8; y:48; spacing:2
            Repeater {
                model:app.files ? [["house","Inicio"],["clock","Recientes"],["star","Favoritos"],["folder","Proyectos"],["download","Descargas"]] : [["tray","Bandeja de entrada"],["list-bullets","Mis tareas"],["squares-four","Proyectos"],["clock","Actividad"]]
                Rectangle {
                    id: navRow
                    required property var modelData
                    required property int index
                    width:168; height:30; radius:5
                    color: index===(app.files?3:1) ? Theme.hover : navHover.containsMouse ? Theme.raised : "transparent"
                    Row { x:10; spacing:8; height:30
                        Icon { name:navRow.modelData[0]; anchors.verticalCenter:parent.verticalCenter; color:Theme.muted }
                        UiText { text:navRow.modelData[1]; height:30; color:navRow.index===(app.files?3:1)?Theme.secondary:Theme.muted; font.pixelSize:12 }
                    }
                    MouseArea { id:navHover; anchors.fill:parent; hoverEnabled:true; onClicked:app.activated() }
                }
            }
            Item { width:168; height:30 }
            UiText { x:10; text:app.files?"Ubicaciones":"Proyecto"; height:26; color:Theme.faint; font.pixelSize:11; weight:510 }
            Repeater { model:app.files ? [["folder","Singlr"],["hard-drives","Este equipo"],["archive","Papelera"]] : [["circle","Escritorio"],["list-bullets","Todas las tareas"],["archive","Archivo"]]
                Item { id:locationRow; required property var modelData; width:168; height:30
                    Row { x:10; spacing:8; height:30
                        Icon { name:locationRow.modelData[0]; anchors.verticalCenter:parent.verticalCenter; color:Theme.faint }
                        UiText { text:locationRow.modelData[1]; height:30; font.pixelSize:12; color:Theme.muted }
                    }
                }
            }
        }
        Row { x:18; y:parent.height-40; spacing:8
            Icon { name:"gear"; color:Theme.faint }
            UiText { text:app.files?"Disco local · 128 GB libres":"Preferencias"; font.pixelSize:11; color:Theme.faint; height:16 }
        }
    }
    Item { id: body; visible:!app.terminal; x:184; y:40; width:parent.width-184; height:parent.height-40
        Item { width:parent.width; height:42
            Row { x:20; spacing:10; height:42
                Icon { name:app.files?"folder":"circle"; anchors.verticalCenter:parent.verticalCenter }
                UiText { text:app.files?"Proyectos":"Escritorio"; height:42; color:Theme.muted; font.pixelSize:12 }
                Icon { name:"caret-right"; width:12; height:42; font.pixelSize:12; color:Theme.faint }
                UiText { text:app.files?"Singlr":"Mis tareas"; height:42; color:Theme.secondary; weight:510; font.pixelSize:12 }
            }
            Row { anchors.right:parent.right; anchors.rightMargin:14; y:7; spacing:6
                Tool { icon:"magnifying-glass"; description:"Buscar"; onClicked:app.activated() }
                Tool { icon:"sliders-horizontal"; description:"Opciones de vista"; onClicked:app.selectedRow=-1 }
                Tool { icon:"dots-three"; description:"Más opciones"; onClicked:app.activated() }
            }
        }
        Rectangle { y:42; width:parent.width; height:1; color:Theme.faintBorder }
        Item { x:24; y:61; width:parent.width-48; height:40
            UiText { text:app.files?"Singlr":"Mis tareas"; display:true; font.pixelSize:20; weight:590; height:30 }
            UiText { anchors.right:parent.right; y:6; text:app.files?"7 elementos":"8 tareas"; color:Theme.faint; font.pixelSize:12; height:20 }
        }
        Item { visible:app.files; x:16; y:112; width:parent.width-32; height:parent.height-160
            Item { width:parent.width; height:28
                UiText { x:12; text:"Nombre"; font.pixelSize:11; color:Theme.faint; height:28 }
                UiText { x:parent.width-310; text:"Modificado"; font.pixelSize:11; color:Theme.faint; height:28 }
                UiText { x:parent.width-144; text:"Tamaño"; font.pixelSize:11; color:Theme.faint; height:28 }
            }
            Column { y:30; width:parent.width; spacing:2
                Repeater { model:Data.files
                    Rectangle { id:fileRow; required property var modelData; required property int index
                        width:parent.width; height:36; radius:5
                        color:app.selectedRow===index?(app.active?Theme.selection:Theme.hover):fileMouse.containsMouse?Theme.hover:"transparent"
                        Row { x:12; height:36; spacing:10
                            Icon { name:fileRow.modelData[4]; color:app.active && app.selectedRow===fileRow.index?Theme.accentText:Theme.muted; anchors.verticalCenter:parent.verticalCenter }
                            UiText { text:fileRow.modelData[0]; height:36; font.pixelSize:13; color:Theme.secondary }
                        }
                        UiText { x:parent.width-310; text:fileRow.modelData[3]; height:36; font.pixelSize:12; color:Theme.muted }
                        UiText { x:parent.width-144; text:fileRow.modelData[2]; height:36; font.pixelSize:12; color:Theme.muted }
                        MouseArea { id:fileMouse; anchors.fill:parent; hoverEnabled:true; onClicked:{ app.selectedRow=fileRow.index; app.activated(); } }
                    }
                }
            }
        }
        Item { visible:!app.files; x:16; y:109; width:parent.width-32; height:parent.height-155
            Row { x:8; spacing:6
                Rectangle { width:62; height:25; radius:5; color:Theme.raised
                    UiText { anchors.centerIn:parent; text:"Asignadas"; font.pixelSize:11; color:Theme.secondary; weight:510 }
                }
                UiText { text:"Creadas"; height:25; width:62; horizontalAlignment:Text.AlignHCenter; font.pixelSize:11; color:Theme.faint }
            }
            Column { y:40; width:parent.width; spacing:1
                Repeater { model:Data.tasks
                    Rectangle { id:taskRow; required property var modelData; required property int index
                        readonly property bool group: modelData.length===2
                        width:parent.width; height:group?30:36; radius:5
                        color:!group && app.selectedRow===index?(app.active?Theme.selection:Theme.hover):!group && taskMouse.containsMouse?Theme.hover:"transparent"
                        Row { x:8; spacing:8; height:parent.height
                            Icon { name:taskRow.group?"caret-down":taskRow.modelData[3]; color:taskRow.group?Theme.faint:taskRow.index<3 && app.active?Theme.accentText:Theme.muted; anchors.verticalCenter:parent.verticalCenter; font.pixelSize:taskRow.group?12:16 }
                            UiText { text:taskRow.modelData[0]; height:parent.height; width:taskRow.group?implicitWidth:64; color:taskRow.group?Theme.secondary:Theme.faint; font.pixelSize:taskRow.group?12:11; weight:taskRow.group?510:400 }
                            UiText { text:taskRow.modelData[1]; height:parent.height; font.pixelSize:taskRow.group?11:13; color:taskRow.group?Theme.faint:Theme.secondary }
                        }
                        UiText { visible:!taskRow.group; x:parent.width-164; text:taskRow.group?"":taskRow.modelData[2]; color:Theme.muted; font.pixelSize:12; height:parent.height }
                        UiText { visible:!taskRow.group; anchors.right:parent.right; anchors.rightMargin:12; text:taskRow.group?"":taskRow.modelData[4]; color:Theme.muted; font.pixelSize:12; height:parent.height }
                        MouseArea { id:taskMouse; anchors.fill:parent; enabled:!taskRow.group; hoverEnabled:true; onClicked:{ app.selectedRow=taskRow.index; app.activated(); } }
                    }
                }
            }
        }
        UiText { x:24; y:parent.height-30; height:20; text:app.files?(app.selectedRow<0?"7 elementos":"1 seleccionado · "+Data.files[app.selectedRow][1]):"Escritorio / Fase 1"; color:Theme.faint; font.pixelSize:11 }
    }
    Item { visible:app.terminal; x:22; y:62; width:parent.width-44; height:parent.height-84
        Column { spacing:14; width:parent.width
            UiText { text:"~/Proyectos/singlr"; color:Theme.secondary; font.family:"monospace"; font.pixelSize:12 }
            UiText { text:"❯  git status --short"; color:Theme.secondary; font.family:"monospace"; font.pixelSize:12 }
            UiText { text:"   M  prototypes/desktop/Main.qml\n   M  prototypes/desktop/Theme.qml"; lineHeight:1.8; color:Theme.muted; font.family:"monospace"; font.pixelSize:12 }
            Row { spacing:8
                UiText { text:"❯"; color:Theme.accentText; font.family:"monospace"; font.pixelSize:12 }
                Rectangle { width:6; height:15; color:Theme.muted }
            }
        }
    }
    Rectangle { anchors.fill:parent; radius:12; color:"transparent"; border.width:1; border.color:app.active?Theme.focusBorder:Theme.faintBorder }
    Rectangle { x:12; y:1; width:parent.width-24; height:1; color:app.active?(Theme.dark?"#0cffffff":"#aaffffff"):"transparent" }
}
