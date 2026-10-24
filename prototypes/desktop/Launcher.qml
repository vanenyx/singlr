pragma ComponentBehavior: Bound
import QtQuick
import "Data.js" as Data
FocusScope {
    id: launcher
    property Item backdrop
    property bool actionsOpen: false
    property bool crystal: true
    property int selectedIndex: 0
    property int actionIndex: 0
    property alias query: input.text
    readonly property var results: Data.filter(query)
    readonly property var selected: results.length ? results[selectedIndex] : null
    readonly property var actionRows: [["arrow-up-right","Abrir","↵"],["push-pin","Fijar en la barra","Ctrl P"],["link","Copiar nombre","Ctrl C"]]
    signal invoked(string kind)
    signal actionInvoked(string action, string name)
    signal closed()
    width:760; height:542
    onQueryChanged: { selectedIndex=0; actionsOpen=false; }
    onVisibleChanged: if (visible) { input.text=""; selectedIndex=0; actionIndex=0; input.forceActiveFocus(); }
    function move(delta) {
        if(actionsOpen) actionIndex=(actionIndex+delta+actionRows.length)%actionRows.length;
        else if(results.length) selectedIndex=(selectedIndex+delta+results.length)%results.length;
    }
    function run() {
        if(!selected) return;
        if(actionsOpen && actionIndex>0) { actionInvoked(actionRows[actionIndex][1],selected.title); actionsOpen=false; }
        else invoked(selected.kind);
    }
    function openActions() { if(selected) { actionsOpen=!actionsOpen; actionIndex=0; } }
    Shadow { anchors.fill:parent; strength:1.35 }
    Glass { anchors.fill:parent; backdrop:launcher.backdrop; crystal:launcher.crystal }
    Icon { x:24; y:25; width:24; height:24; font.pixelSize:24; name:"magnifying-glass"; color:Theme.muted }
    TextInput {
        id:input; objectName:"launcherInput"
        x:62; y:18; width:parent.width-124; height:40
        focus:true; color:Theme.text; selectionColor:Theme.selection; selectedTextColor:Theme.text
        font.family:Theme.family; font.pixelSize:21; font.weight:400; font.variableAxes:({"opsz":32,"wght":400})
        verticalAlignment:TextInput.AlignVCenter; clip:true
        Accessible.name:"Buscar aplicaciones, archivos y comandos"
        Keys.onUpPressed:event=>{ launcher.move(-1); event.accepted=true; }
        Keys.onDownPressed:event=>{ launcher.move(1); event.accepted=true; }
        Keys.onReturnPressed:launcher.run()
        Keys.onEscapePressed:{ if(launcher.actionsOpen) launcher.actionsOpen=false; else launcher.closed(); }
        Keys.onPressed:event=>{
            if((event.modifiers & Qt.ControlModifier) && event.key===Qt.Key_K) { launcher.openActions(); event.accepted=true; }
            if(launcher.actionsOpen && (event.modifiers & Qt.ControlModifier) && (event.key===Qt.Key_P || event.key===Qt.Key_C)) {
                launcher.actionIndex=event.key===Qt.Key_P?1:2; launcher.run(); event.accepted=true;
            }
        }
        UiText { anchors.fill:parent; text:"Buscar aplicaciones, archivos, comandos…"; font.pixelSize:21; display:true; color:Theme.faint; visible:!input.text }
    }
    Rectangle { x:parent.width-47; y:27; width:27; height:20; radius:4; color:"transparent"; border.color:Theme.border
        UiText { anchors.centerIn:parent; text:"esc"; color:Theme.faint; font.pixelSize:10 }
    }
    Rectangle { y:76; width:parent.width; height:1; color:Theme.border }
    ListView {
        id:list; x:10; y:88; width:parent.width-20; height:parent.height-146
        clip:true; model:launcher.results; currentIndex:launcher.selectedIndex
        highlightMoveDuration:0; boundsBehavior:Flickable.StopAtBounds
        onCurrentIndexChanged:positionViewAtIndex(currentIndex,ListView.Contain)
        delegate:Item {
            id:result; required property var modelData; required property int index
            readonly property bool sectionStart: index===0 || launcher.results[index-1].section!==modelData.section
            width:list.width; height:sectionStart?72:44
            UiText { x:14; y:0; height:28; text:result.modelData.section; visible:result.sectionStart; color:Theme.faint; font.pixelSize:11; weight:510 }
            Rectangle {
                y:result.sectionStart?28:0; width:parent.width; height:44; radius:6
                color:launcher.selectedIndex===result.index?Theme.selection:rowHover.containsMouse?Theme.hover:"transparent"
                Image { x:14; y:12; width:20; height:20; visible:result.modelData.app>=0 && !!Data.apps[result.modelData.app].logo; source:result.modelData.app>=0?Data.apps[result.modelData.app].logo:"" }
                Icon { x:16; y:14; name:result.modelData.icon; visible:result.modelData.app<0 || !Data.apps[result.modelData.app].logo; color:Theme.secondary }
                UiText { x:48; y:4; height:20; text:result.modelData.title; weight:510 }
                UiText { x:48; y:24; height:15; text:result.modelData.subtitle; font.pixelSize:11; color:Theme.muted }
                UiText { anchors.right:parent.right; anchors.rightMargin:16; height:44; text:launcher.selectedIndex===result.index?"↵":result.modelData.accessory; color:Theme.faint; font.pixelSize:11 }
                MouseArea { id:rowHover; anchors.fill:parent; hoverEnabled:true; onClicked:{ launcher.selectedIndex=result.index; launcher.run(); } }
                Accessible.role:Accessible.ListItem; Accessible.name:result.modelData.title+", "+result.modelData.subtitle; Accessible.selected:launcher.selectedIndex===result.index
            }
        }
        UiText { anchors.centerIn:parent; visible:launcher.results.length===0; text:"Sin resultados"; color:Theme.muted }
    }
    Rectangle { y:parent.height-42; width:parent.width; height:1; color:Theme.border }
    Row { x:24; y:parent.height-30; spacing:8
        Rectangle { width:14; height:14; radius:7; color:"transparent"; border.width:1.5; border.color:Theme.faint }
        UiText { text:"Singlr"; height:14; font.pixelSize:11; color:Theme.faint }
    }
    Row { anchors.right:parent.right; anchors.rightMargin:16; y:parent.height-35; spacing:12
        Tool { icon:"key-return"; label:"Abrir"; description:"Abrir resultado seleccionado"; onClicked:launcher.run() }
        Rectangle { width:1; height:14; y:7; color:Theme.border }
        Tool { icon:"command"; label:"Acciones  Ctrl K"; description:"Abrir acciones"; onClicked:launcher.openActions() }
    }
    Item {
        id:actions; visible:launcher.actionsOpen; x:width>0?launcher.width-width-14:0; y:launcher.height-height-54; width:300; height:218
        Shadow { anchors.fill:parent; strength:.9 }
        // Independent neutral material, isolated from the launcher backdrop.
        Rectangle { anchors.fill:parent; radius:8; color:Theme.raised; border.color:Theme.focusBorder }
        UiText { x:14; y:8; height:28; width:parent.width-28; text:launcher.selected?launcher.selected.title:""; font.pixelSize:11; weight:510; color:Theme.muted }
        Rectangle { x:10; y:41; width:parent.width-20; height:1; color:Theme.faintBorder }
        Column { x:6; y:49; spacing:3
            Repeater { model:launcher.actionRows
                Rectangle { id:actionRow; required property var modelData; required property int index
                    width:288; height:36; radius:5; color:launcher.actionIndex===index?Theme.selection:actionHover.containsMouse?Theme.hover:"transparent"
                    Icon { x:10; y:10; name:actionRow.modelData[0]; color:Theme.secondary }
                    UiText { x:36; height:36; text:actionRow.modelData[1]; font.pixelSize:12; color:Theme.secondary }
                    UiText { anchors.right:parent.right; anchors.rightMargin:10; height:36; text:actionRow.modelData[2]; font.pixelSize:10; color:Theme.muted }
                    MouseArea { id:actionHover; anchors.fill:parent; hoverEnabled:true; onClicked:{launcher.actionIndex=actionRow.index;launcher.run();} }
                }
            }
        }
        UiText { x:16; y:184; text:"↑ ↓  Navegar"; height:20; font.pixelSize:10; color:Theme.faint }
    }
}
