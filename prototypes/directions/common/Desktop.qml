import QtQuick
import QtQuick.Window
import "Arguments.js" as Args
import "Data.js" as Data
Window {
    id:window
    width:2048;height:1280;visible:true
    title:"Singlr · "+(alternate?"Margen":"Estrato")+" · Exploración visual"
    property bool alternate:false
    property var tokens
    property bool dark:Args.value(Qt.application.arguments,"mode","dark")!=="light"
    property string desktopState:Args.value(Qt.application.arguments,"state","desktop")
    property int material:Args.material(Qt.application.arguments,"glass")
    property real intensity:.55
    property string capture:Args.value(Qt.application.arguments,"capture","")
    Fonts { id:fontSet }
    function changeState(n) { desktopState=["desktop","search","multitask","controls"][n] }
    Shortcut { sequence:"1";onActivated:window.changeState(0) }
    Shortcut { sequence:"2";onActivated:window.changeState(1) }
    Shortcut { sequence:"3";onActivated:window.changeState(2) }
    Shortcut { sequence:"4";onActivated:window.changeState(3) }
    Shortcut { sequence:"L";onActivated:window.dark=!window.dark }
    Shortcut { sequence:"G";onActivated:window.material=(window.material+1)%3 }
    Shortcut { sequence:"Escape";onActivated:window.desktopState="desktop" }
    Item {
        id:canvas;anchors.fill:parent
        Item {
            id:sceneBackdrop;anchors.fill:parent
            Wallpaper { anchors.fill:parent;dark:window.dark;alternate:window.alternate }
            Item {
                id:work;anchors.fill:parent;visible:window.desktopState!=="multitask"
                AppWindow { x:window.alternate?1180:1240;y:window.alternate?106:95;width:window.alternate?770:700;height:710;tokens:window.tokens;fonts:fontSet;kind:"terminal";active:false }
                AppWindow { x:window.alternate?330:240;y:window.alternate?330:294;width:window.alternate?1370:1260;height:window.alternate?820:730;tokens:window.tokens;fonts:fontSet;kind:"files";alternate:window.alternate }
            }
        }
        // A: a quiet global line and a single compact launch / switching shelf.
        Item { visible:!window.alternate;anchors.fill:parent
            Row { x:32;y:22;spacing:18
                Rectangle { width:25;height:25;radius:13;color:"transparent";border.width:3;border.color:tokens.text }
                Label { tokens:window.tokens;text:"Singlr";font.pixelSize:18;font.weight:Font.DemiBold;height:26 }
                Label { tokens:window.tokens;text:window.desktopState==="multitask"?"Espacios":"Archivos";font.pixelSize:16;color:tokens.muted;height:26 }
            }
            Label { anchors.horizontalCenter:parent.horizontalCenter;y:25;tokens:window.tokens;text:"Sábado 24 de octubre   ·   11:42";font.pixelSize:15;color:tokens.text }
            Row { anchors.right:parent.right;anchors.rightMargin:32;y:17;spacing:14
                Tool { tokens:window.tokens;fonts:fontSet;icon:"wifi-high";width:30;onClicked:window.changeState(3) }
                Tool { tokens:window.tokens;fonts:fontSet;icon:"speaker-high";width:30;onClicked:window.changeState(3) }
                Tool { tokens:window.tokens;fonts:fontSet;icon:"battery-high";label:"86 %";onClicked:window.changeState(3) }
            }
            Item { x:(parent.width-width)/2;y:parent.height-100;width:838;height:68
                Glass { anchors.fill:parent;tokens:window.tokens;backdrop:sceneBackdrop;material:0;intensity:window.intensity }
                Row { x:14;y:10;spacing:10
                    Tool { tokens:window.tokens;fonts:fontSet;icon:"magnifying-glass";width:48;height:48;onClicked:window.changeState(1) }
                    Rectangle { width:1;height:30;color:tokens.line;anchors.verticalCenter:parent.verticalCenter }
                    Repeater { model:Data.apps
                        Rectangle { required property var modelData;required property int index;width:index===0?164:126;height:48;radius:7;color:index===0?tokens.selected:tokens.surface
                            Row { anchors.centerIn:parent;spacing:10
                                Image { source:modelData.path;width:32;height:32 }
                                Label { tokens:window.tokens;text:modelData.name;font.pixelSize:15;height:32 }
                            }
                            Rectangle { visible:index<3;anchors.bottom:parent.bottom;anchors.bottomMargin:-8;anchors.horizontalCenter:parent.horizontalCenter;width:14;height:2;radius:1;color:index===0?tokens.accent:tokens.muted }
                            MouseArea { anchors.fill:parent;onClicked:window.changeState(0) }
                        }
                    }
                    Rectangle { width:1;height:30;color:tokens.line;anchors.verticalCenter:parent.verticalCenter }
                    Tool { tokens:window.tokens;fonts:fontSet;icon:"squares-four";width:48;height:48;onClicked:window.changeState(2) }
                }
            }
            Row { x:32;y:parent.height-88;spacing:8
                Repeater { model:3
                    Rectangle { required property int index;width:index===0?126:48;height:44;radius:5;color:index===0?tokens.selected:tokens.surface;border.color:tokens.line
                        Label { anchors.centerIn:parent;tokens:window.tokens;text:index===0?"01  Personal":"0"+(index+1);font.pixelSize:15;color:index===0?tokens.accent:tokens.text }
                        MouseArea { anchors.fill:parent;onClicked:window.changeState(2) }
                    }
                }
            }
        }
        // B: persistent vertical navigation, workspace orientation at hand.
        Item { visible:window.alternate;anchors.fill:parent
            Glass { x:24;y:24;width:108;height:parent.height-48;tokens:window.tokens;backdrop:sceneBackdrop;material:window.material;intensity:window.intensity;radius:12 }
            Rectangle { x:62;y:57;width:32;height:32;radius:16;color:"transparent";border.color:tokens.text;border.width:3 }
            Column { x:52;y:146;spacing:20
                Tool { tokens:window.tokens;fonts:fontSet;icon:"magnifying-glass";width:52;height:52;onClicked:window.changeState(1) }
                Tool { tokens:window.tokens;fonts:fontSet;icon:"squares-four";width:52;height:52;selected:window.desktopState==="multitask";onClicked:window.changeState(2) }
                Rectangle { x:9;width:34;height:1;color:tokens.line }
                Repeater { model:Data.apps
                    Item { required property var modelData;required property int index;width:52;height:60
                        Rectangle { anchors.fill:parent;radius:7;color:index===0?tokens.selected:"transparent" }
                        Image { anchors.centerIn:parent;source:modelData.path;width:36;height:36 }
                        Rectangle { visible:index===0;x:-18;y:20;width:3;height:20;radius:1;color:tokens.accent }
                        MouseArea { anchors.fill:parent;onClicked:window.changeState(0) }
                    }
                }
            }
            Column { x:52;y:parent.height-280;spacing:15
                Repeater { model:3
                    Rectangle { required property int index;width:52;height:40;radius:6;color:index===0?tokens.selected:"transparent"
                        Label { anchors.centerIn:parent;tokens:window.tokens;text:"0"+(index+1);font.pixelSize:16;color:index===0?tokens.accent:tokens.muted }
                        MouseArea { anchors.fill:parent;onClicked:window.changeState(2) }
                    }
                }
                Tool { tokens:window.tokens;fonts:fontSet;icon:"sliders-horizontal";width:52;height:46;onClicked:window.changeState(3) }
            }
            Column { x:181;y:49;spacing:8
                Label { tokens:window.tokens;text:"Personal";font.pixelSize:16;color:tokens.muted }
                Label { tokens:window.tokens;text:"Espacio 01";font.pixelSize:24;font.weight:Font.Medium }
            }
            Item { x:parent.width-width-40;y:38;width:statusRow.width+32;height:54
                Glass { anchors.fill:parent;tokens:window.tokens;backdrop:sceneBackdrop;material:window.material;intensity:window.intensity*.4;radius:10 }
                Row { id:statusRow;x:16;y:9;spacing:12
                    Tool { tokens:window.tokens;fonts:fontSet;icon:"wifi-high";width:28;height:36;onClicked:window.changeState(3) }
                    Tool { tokens:window.tokens;fonts:fontSet;icon:"battery-high";label:"86 %";height:36;onClicked:window.changeState(3) }
                    Label { tokens:window.tokens;text:"Sáb 24   11:42";font.pixelSize:15;height:36 }
                }
            }
        }
        Item {
            visible:window.desktopState==="multitask";anchors.fill:parent
            Label { x:window.alternate?200:200;y:window.alternate?174:142;tokens:window.tokens;text:"Ventanas y espacios";font.pixelSize:window.alternate?36:28;font.weight:Font.DemiBold }
            Label { x:200;y:window.alternate?232:202;tokens:window.tokens;text:"Personal   /   3 ventanas abiertas";font.pixelSize:18;color:tokens.muted }
            Repeater { model:3
                Item { required property int index
                    x:window.alternate?(index===0?220:1030):(180+index*578)
                    y:window.alternate?(index===0?330:(index===1?310:725)):340
                    width:window.alternate?(index===0?740:720):550
                    height:window.alternate?(index===0?530:350):390
                    Rectangle { x:-7;y:-7;width:parent.width+14;height:parent.height+14;radius:tokens.radius;color:"transparent";border.color:index===0?tokens.accent:"transparent";border.width:2 }
                    Item { anchors.fill:parent;clip:true
                        AppWindow { thumbnail:true;width:parent.width/(parent.height/900);height:900;scale:parent.height/900;transformOrigin:Item.TopLeft;tokens:window.tokens;fonts:fontSet;kind:index===0?"files":index===1?"terminal":"editor";active:index===0 }
                    }
                    Row { y:parent.height+23;spacing:10
                        Image { source:Data.apps[index===0?0:index===1?2:3].path;width:24;height:24 }
                        Label { tokens:window.tokens;text:index===0?"Singlr · Archivos":index===1?"singlr · Terminal":"Visión del escritorio · Kate";font.pixelSize:16;height:24 }
                        Label { tokens:window.tokens;text:index===0?"EN FOCO":"";font.pixelSize:11;color:tokens.accent;height:24 }
                    }
                    MouseArea { anchors.fill:parent;onClicked:window.changeState(0) }
                }
            }
            Item { visible:!window.alternate;x:465;y:900;width:1120;height:190
                Row { spacing:28
                    Repeater { model:["01   Personal","02   Lectura","03   Laboratorio"]
                        Item { required property int index;required property string modelData;width:330;height:180
                            Rectangle { anchors.fill:parent;radius:8;color:tokens.inset;border.color:index===0?tokens.accent:tokens.line;border.width:index===0?2:1 }
                            WorkspaceThumb { x:8;y:8;width:parent.width-16;height:122;tokens:window.tokens;fonts:fontSet;workspace:index;alternate:window.alternate }
                            Label { x:18;y:143;tokens:window.tokens;text:modelData;font.pixelSize:14;color:index===0?tokens.accent:tokens.muted }
                        }
                    }
                }
            }
            Column { visible:window.alternate;x:1800;y:310;spacing:18
                Repeater { model:["01  Personal","02  Lectura","03  Laboratorio"]
                    Rectangle { required property int index;required property string modelData;width:185;height:130;radius:8;color:tokens.inset;border.color:index===0?tokens.accent:tokens.line
                        WorkspaceThumb { x:6;y:6;width:parent.width-12;height:78;tokens:window.tokens;fonts:fontSet;workspace:index;alternate:window.alternate }
                        Label { x:16;y:96;tokens:window.tokens;text:modelData;font.pixelSize:13;color:index===0?tokens.accent:tokens.muted }
                    }
                }
                Tool { tokens:window.tokens;fonts:fontSet;icon:"plus";label:"Nuevo espacio";width:185 }
            }
        }
        Rectangle { anchors.fill:parent;visible:window.desktopState==="search";color:window.dark?"#30000000":"#35ffffff" }
        SearchPanel { visible:window.desktopState==="search";x:window.alternate?180:599;y:window.alternate?170:205;width:window.alternate?900:820;height:window.alternate?820:760;tokens:window.tokens;fonts:fontSet;backdrop:sceneBackdrop;material:window.material;intensity:window.intensity;alternate:window.alternate;onDismissed:window.changeState(0) }
        ControlsPanel { visible:window.desktopState==="controls";x:window.alternate?1390:1516;y:window.alternate?124:84;width:window.alternate?590:490;height:1040;tokens:window.tokens;fonts:fontSet;backdrop:sceneBackdrop;material:window.material;intensity:window.intensity;onMaterialSelected:value=>window.material=value;onIntensitySelected:value=>window.intensity=value }
    }
    Timer {
        id:captureTimer;interval:2400;running:window.capture!=="";repeat:true
        onTriggered: {
            if(!fontSet.ready) return;
            stop();
            window.contentItem.grabToImage(function(result) {
                if(!result.saveToFile(window.capture)) { console.error("CAPTURE FAILED",window.capture);Qt.exit(2); }
                else { console.log("CAPTURE",window.capture,window.desktopState,window.dark?"dark":"light","material",window.material,"fonts ready",fontSet.ready,"backend",canvas.GraphicsInfo.api);Qt.quit(); }
            });
        }
    }
}
