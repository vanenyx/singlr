import QtQuick
QtObject {
    property bool dark:true
    readonly property string family:"Inter Variable"
    readonly property color text:dark?"#eeeeee":"#252525"
    readonly property color muted:dark?"#b5b5b5":"#656565"
    readonly property color surface:dark?"#242424":"#f6f6f6"
    readonly property color inset:dark?"#1e1e1e":"#ececec"
    readonly property color raised:dark?"#303030":"#ffffff"
    readonly property color line:dark?"#404040":"#d5d5d5"
    readonly property color accent:dark?"#efb794":"#935239"
    readonly property color selected:dark?"#49372f":"#eed6c4"
    readonly property color glass:dark?"#70222222":"#88f5f5f5"
    readonly property color liquidTint:dark?"#40222222":"#60f5f5f5"
    readonly property color shadow:"#55000000"
    readonly property int radius:16
    readonly property int space:16
    readonly property int body:20
    readonly property int heading:36
    readonly property int titlebar:64
    readonly property int sidebar:256
    readonly property int rowHeight:70
    readonly property int tableTop:220
    readonly property int navHeight:52
    readonly property int navFont:19
    readonly property int editorTitle:48
    readonly property int material:1
    readonly property real blur:0.65
    readonly property real shadowBlur:1.0
}
