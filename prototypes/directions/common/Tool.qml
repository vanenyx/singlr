import QtQuick
Rectangle {
    id: root
    property var tokens
    property var fonts
    property string icon: "magnifying-glass"
    property string label: ""
    property bool selected: false
    property bool leftAligned:false
    signal clicked()
    width: label ? row.width + 24 : 44; height: tokens.navHeight
    radius: 7; color: selected || mouse.containsMouse ? tokens.selected : "transparent"
    Row { id: row; anchors.verticalCenter:parent.verticalCenter; x:root.leftAligned?12:(parent.width-width)/2; spacing: 12
        Icon { name: root.icon; fonts: root.fonts; color: root.selected ? root.tokens.accent : root.tokens.muted; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 22 }
        Label { tokens: root.tokens; text: root.label; font.pixelSize: root.tokens.navFont; visible: root.label !== ""; height: 28 }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
    Accessible.role: Accessible.Button
    Accessible.name: label || icon
}
