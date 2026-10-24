pragma ComponentBehavior: Bound
import QtQuick
Text {
    property bool display: false
    property int weight: 400
    color: Theme.text
    font.family: Theme.family
    font.pixelSize: 13
    font.weight: weight
    font.variableAxes: ({"wght":weight,"opsz":display?32:14})
    textFormat: Text.PlainText
    verticalAlignment: Text.AlignVCenter
    renderType: Text.QtRendering
    elide: Text.ElideRight
}
