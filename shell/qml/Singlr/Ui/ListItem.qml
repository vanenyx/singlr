import QtQuick
Rectangle {
    id: row
    property string title: ""
    property string subtitle: ""
    property var iconSource: ""
    property bool selected: false
    property var resultActions: []
    signal clicked()
    implicitHeight: 44
    radius: 6
    color: selected ? Theme.selection : hover.containsMouse ? Theme.hover : "transparent"
    border.color: activeFocus ? Theme.accentText : "transparent"
    activeFocusOnTab: true
    Accessible.role: Accessible.ListItem
    Accessible.name: title + (subtitle ? ", " + subtitle : "")
    Accessible.selected: selected
    Keys.onReturnPressed: clicked()
    AppIcon { x: 14; anchors.verticalCenter: parent.verticalCenter; source: row.iconSource; width: 20; height: 20 }
    UiText { x: 48; y: row.subtitle ? 4 : 0; height: row.subtitle ? 20 : parent.height; width: parent.width-64; text: row.title; weight: 510 }
    UiText { x: 48; y: 24; height: 15; width: parent.width-64; text: row.subtitle; font.pixelSize: 11; color: Theme.muted }
    MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; onClicked: row.clicked() }
}
