import QtQuick
Text {
    property var tokens
    color: tokens.text
    font.family: tokens.family
    font.pixelSize: tokens.body
    renderType: Text.QtRendering
    verticalAlignment: Text.AlignVCenter
}
