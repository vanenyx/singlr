import QtQuick
Rectangle {
    id: row
    property string title: ""
    property string subtitle: ""
    property var iconSource: ""
    property real trailingWidth: 16
    property bool selected: false
    property var resultActions: []
    signal clicked()
    implicitHeight: 36
    radius: 6
    color: selected ? Theme.selection : hover.containsMouse ? Theme.hover : "transparent"
    border.color: activeFocus ? Theme.accentText : "transparent"
    activeFocusOnTab: true
    Accessible.focusable: true
    Accessible.role: Accessible.ListItem
    Accessible.name: title + (subtitle ? ", " + subtitle : "")
    Accessible.selected: selected
    Accessible.onPressAction: clicked()
    Keys.onEnterPressed: clicked()
    Keys.onSpacePressed: clicked()
    Keys.onReturnPressed: clicked()
    AppIcon { x: 14; anchors.verticalCenter: parent.verticalCenter; source: row.iconSource; width: 20; height: 20 }
    UiText { x: 48; y: 0; height: parent.height; width: row.subtitle ? parent.width*0.58-48 : parent.width-48-row.trailingWidth; text: row.title; weight: 510 }
    UiText { x: parent.width*0.58; y: 0; height: parent.height; width: parent.width*0.42-16; text: row.subtitle; font.pixelSize: 13; color: Theme.muted }
    MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; onClicked: row.clicked() }
}
