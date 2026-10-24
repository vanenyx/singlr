import QtQuick
Item {
    id:root
    property var tokens
    property var fonts
    property int workspace:0
    property bool alternate:false
    clip:true
    Rectangle { anchors.fill:parent;color:tokens.dark?"#454545":"#bdbdbd" }
    AppWindow { thumbnail:true; x:parent.width*.49;y:12;width:1320;height:900;scale:Math.min((parent.width*.45)/1320,(parent.height-26)/900);transformOrigin:Item.TopLeft;tokens:root.tokens;fonts:root.fonts;kind:"terminal";active:false }
    AppWindow { thumbnail:true; x:12;y:10;width:1320;height:900;scale:Math.min((parent.width*.7)/1320,(parent.height-22)/900);transformOrigin:Item.TopLeft;tokens:root.tokens;fonts:root.fonts;kind:root.workspace===0?"files":root.workspace===1?"editor":"terminal" }
}
