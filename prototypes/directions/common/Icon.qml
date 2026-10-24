import QtQuick
import "IconMap.js" as Map
Text {
    property string name: "circle"
    property string weight: "regular"
    property var fonts
    text: String.fromCodePoint(Map.glyphs[weight][name] || Map.glyphs.regular["question"])
    font.family: fonts ? fonts[weight] : "Phosphor"
    font.pixelSize: 24
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    width: font.pixelSize + 4; height: width
    color: "white"
}
