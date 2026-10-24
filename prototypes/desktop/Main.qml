pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import "Data.js" as Data
Window {
    id: window
    width:2048; height:1280; visible:true; color:Theme.background
    title:"Singlr · Escritorio"
    property string desktopState:argument("state","desktop")
    property string capturePath:argument("capture","")
    property string activeApp:"tasks"
    property bool crystal:argument("material","glass")!=="mate"
    property var hiddenApps:[]
    property string maximizedApp:""
    property string feedback:""
    property alias launcher:searchPanel
    property alias systemPanel:controls
    function argument(name,fallback) {
        var prefix="--"+name+"=";
        for(var arg of Qt.application.arguments) if(arg.indexOf(prefix)===0) return arg.slice(prefix.length);
        return fallback;
    }
    function setState(name) {
        desktopState=name;
        if(name==="search" || name==="actions") { searchPanel.actionsOpen=name==="actions"; searchPanel.forceActiveFocus(); }
        else canvas.forceActiveFocus();
    }
    function showApp(kind) { hiddenApps=hiddenApps.filter(function(k){return k!==kind;}); activeApp=kind;setState("desktop"); }
    function hideApp(kind) { hiddenApps=hiddenApps.concat([kind]); }
    function invoke(kind) {
        if(kind==="mode") {Theme.dark=!Theme.dark;setState("desktop");}
        else if(kind==="dnd") {controls.dnd=!controls.dnd;setState("controls");}
        else if(kind==="browser") {setState("desktop");notify("Firefox · Apertura simulada");}
        else showApp(kind);
    }
    function notify(message) {feedback=message;feedbackTimer.restart();}
    Component.onCompleted:{Theme.dark=argument("mode","dark")!=="light";setState(desktopState);}
    Shortcut { sequence:"1"; enabled:!searchPanel.visible; onActivated:window.setState("desktop") }
    Shortcut { sequence:"2"; enabled:!searchPanel.visible; onActivated:window.setState("search") }
    Shortcut { sequence:"3"; enabled:!searchPanel.visible; onActivated:window.setState("actions") }
    Shortcut { sequence:"4"; enabled:!searchPanel.visible; onActivated:window.setState("multitask") }
    Shortcut { sequence:"5"; enabled:!searchPanel.visible; onActivated:window.setState("controls") }
    Shortcut { sequence:"L"; enabled:!searchPanel.visible; onActivated:Theme.dark=!Theme.dark }
    Shortcut { sequence:"Escape"; enabled:!searchPanel.visible; onActivated:window.setState("desktop") }
    Shortcut { sequence:"Ctrl+Space"; onActivated:window.setState(searchPanel.visible?"desktop":"search") }
    Item {
        id:canvas; anchors.fill:parent; focus:true
        Item {
            id:sceneBackdrop; anchors.fill:parent
            Rectangle { anchors.fill:parent; color:Theme.background
                // A two-step neutral luminance field; no decorative wallpaper.
                gradient:Gradient {
                    GradientStop { position:0; color:Theme.background }
                    GradientStop { position:.58; color:Theme.panel }
                    GradientStop { position:1; color:Theme.background }
                }
            }
            Item { anchors.fill:parent; visible:window.desktopState!=="multitask"
                AppWindow { id:files; kind:"files"; active:window.activeApp===kind; z:active?3:1
                    x:window.maximizedApp===kind?24:180; y:window.maximizedApp===kind?60:182
                    width:window.maximizedApp===kind?parent.width-48:990; height:window.maximizedApp===kind?parent.height-150:650
                    visible:window.hiddenApps.indexOf(kind)<0
                    onActivated:window.activeApp=kind; onDismissed:window.hideApp(kind); onMinimized:window.hideApp(kind); onMaximized:window.maximizedApp=window.maximizedApp===kind?"":kind
                }
                AppWindow { id:terminal; kind:"terminal"; active:window.activeApp===kind; z:active?3:1
                    x:window.maximizedApp===kind?24:300; y:window.maximizedApp===kind?60:792
                    width:window.maximizedApp===kind?parent.width-48:620; height:window.maximizedApp===kind?parent.height-150:304
                    visible:window.hiddenApps.indexOf(kind)<0
                    onActivated:window.activeApp=kind; onDismissed:window.hideApp(kind); onMinimized:window.hideApp(kind); onMaximized:window.maximizedApp=window.maximizedApp===kind?"":kind
                }
                AppWindow { id:tasks; kind:"tasks"; active:window.activeApp===kind; z:active?3:2
                    x:window.maximizedApp===kind?24:838; y:window.maximizedApp===kind?60:366
                    width:window.maximizedApp===kind?parent.width-48:1040; height:window.maximizedApp===kind?parent.height-150:660
                    visible:window.hiddenApps.indexOf(kind)<0
                    onActivated:window.activeApp=kind; onDismissed:window.hideApp(kind); onMinimized:window.hideApp(kind); onMaximized:window.maximizedApp=window.maximizedApp===kind?"":kind
                }
            }
            Multitask { anchors.fill:parent; visible:window.desktopState==="multitask"; onChosen:kind=>window.showApp(kind) }
        }
        Rectangle { width:parent.width; height:38; color:Theme.dark?"#18000000":"#28ffffff"
            Row { x:24; height:38; spacing:16
                Rectangle { width:13; height:13; radius:7; color:"transparent"; border.width:1.5; border.color:Theme.muted; anchors.verticalCenter:parent.verticalCenter }
                UiText { text:"Singlr"; height:38; font.pixelSize:12; color:Theme.muted; weight:510 }
                Tool { icon:"squares-four"; label:"Escritorio"; y:5; onClicked:window.setState("multitask") }
            }
            UiText { anchors.centerIn:parent; text:"Sáb 24 oct    11:42"; font.pixelSize:12; color:Theme.muted }
            Row { anchors.right:parent.right; anchors.rightMargin:22; y:5; spacing:7
                Tool { icon:controls.dnd?"bell-slash":"bell"; description:"Notificaciones"; onClicked:window.setState("controls") }
                Tool { icon:"wifi-high"; description:"Red"; onClicked:window.setState("controls") }
                Tool { icon:"speaker-high"; description:"Audio"; onClicked:window.setState("controls") }
                Tool { icon:"battery-high"; label:"86 %"; description:"Controles del sistema"; onClicked:window.setState("controls") }
            }
        }
        Item { id:shelf; width:452; height:48; x:(parent.width-width)/2; y:parent.height-78
            Shadow { anchors.fill:parent; strength:.5 }
            Rectangle { anchors.fill:parent; radius:10; color:Theme.panel; border.color:Theme.border }
            Row { x:10; y:7; spacing:6
                Tool { icon:"magnifying-glass"; description:"Buscar · Ctrl Espacio"; width:34; height:34; onClicked:window.setState("search") }
                Rectangle { width:1; height:18; y:8; color:Theme.border }
                Repeater { model:Data.apps
                    Rectangle { id:dockApp; required property var modelData; required property int index
                        width:index===3?40:91; height:34; radius:6
                        color:window.activeApp===dockApp.modelData.kind?Theme.raised:dockHover.containsMouse?Theme.hover:"transparent"
                        Row { anchors.centerIn:parent; spacing:7
                            Image { width:20; height:20; source:dockApp.modelData.logo; visible:!!dockApp.modelData.logo }
                            Icon { name:dockApp.modelData.icon; visible:!dockApp.modelData.logo; height:20; color:Theme.secondary }
                            UiText { visible:dockApp.index<3; height:20; text:dockApp.modelData.name; font.pixelSize:12; color:Theme.muted }
                        }
                        Rectangle { anchors.horizontalCenter:parent.horizontalCenter; y:37; width:window.activeApp===dockApp.modelData.kind?12:3; height:2; radius:1; color:window.activeApp===dockApp.modelData.kind?Theme.accentText:Theme.faint; visible:dockApp.index<3 && window.hiddenApps.indexOf(dockApp.modelData.kind)<0 }
                        Accessible.role:Accessible.Button; Accessible.name:dockApp.modelData.name; activeFocusOnTab:true
                        Keys.onReturnPressed:window.invoke(dockApp.modelData.kind)
                        MouseArea { id:dockHover; anchors.fill:parent; hoverEnabled:true; onClicked:window.invoke(dockApp.modelData.kind) }
                    }
                }
                Rectangle { width:1; height:18; y:8; color:Theme.border }
                Tool { icon:"squares-four"; description:"Multitarea"; width:34; height:34; onClicked:window.setState("multitask") }
            }
        }
        Rectangle { anchors.fill:parent; visible:searchPanel.visible; color:Theme.dark?"#38000000":"#18000000"
            MouseArea { anchors.fill:parent; onClicked:window.setState("desktop") }
        }
        Launcher {
            id:searchPanel; x:Math.round((parent.width-width)/2); y:286
            visible:window.desktopState==="search" || window.desktopState==="actions"
            backdrop:sceneBackdrop; crystal:window.crystal
            onInvoked:kind=>window.invoke(kind)
            onClosed:window.setState("desktop")
            onActionInvoked:(action,name)=>window.notify(action+" · "+name+" (simulado)")
        }
        SystemPanel { id:controls; x:parent.width-width-24; y:52; visible:window.desktopState==="controls"; backdrop:sceneBackdrop; crystal:window.crystal
            onCrystalChanged:window.crystal=crystal
            onPowerRequested:window.notify("Energía · Menú simulado")
        }
        Rectangle { visible:!!window.feedback; anchors.horizontalCenter:parent.horizontalCenter; y:parent.height-126; width:feedbackLabel.implicitWidth+28; height:32; radius:6; color:Theme.raised; border.color:Theme.border
            UiText { id:feedbackLabel; anchors.centerIn:parent; text:window.feedback; font.pixelSize:12; color:Theme.secondary }
        }
        Timer { id:feedbackTimer; interval:2400; onTriggered:window.feedback="" }
    }
    Timer { id:renderReport; interval:300; running:true; onTriggered:{
        console.log("BACKEND="+canvas.GraphicsInfo.api+"; "+(canvas.GraphicsInfo.api===GraphicsInfo.Software?"SOFTWARE: material mate de respaldo, sin desenfoque":"RHI: cristal con desenfoque real"));
    } }
    Timer {
        interval:1100; running:!!window.capturePath; repeat:false
        onTriggered:canvas.grabToImage(function(result){
            if(!result.saveToFile(window.capturePath)) {console.error("CAPTURE_FAILED "+window.capturePath);Qt.exit(1);return;}
            console.log("CAPTURE_OK "+window.capturePath+" 2048x1280"); Qt.quit();
        },Qt.size(2048,1280))
    }
}
