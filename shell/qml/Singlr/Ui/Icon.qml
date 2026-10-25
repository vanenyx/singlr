pragma ComponentBehavior: Bound
import QtQuick
import "Icons.js" as Icons
Text {
    property string name: "circle"
    // Glyphs are decorative unless the caller supplies a human-readable label.
    Accessible.role: Accessible.Graphic
    Accessible.ignored: !Accessible.name
    width: 16; height: 16
    text: String.fromCodePoint(Icons.glyphs[name] || Icons.glyphs.circle)
    font.family: Theme.icons
    font.pixelSize: 16
    color: Theme.muted
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
