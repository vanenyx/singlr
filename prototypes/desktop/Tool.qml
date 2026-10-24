pragma ComponentBehavior: Bound
import QtQuick
Rectangle {
    id: tool
    property string icon: "dots-three"
    property string label: ""
    property string description: label
    signal clicked()
    width: label ? caption.implicitWidth+42 : 28; height: 28; radius: 5
    color: pointer.containsMouse || activeFocus ? Theme.hover : "transparent"
    border.color: activeFocus ? Theme.accentText : "transparent"
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: description
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    Row { anchors.centerIn: parent; spacing: 7
        Icon { name: tool.icon; anchors.verticalCenter: parent.verticalCenter }
        UiText { id: caption; text: tool.label; visible: !!tool.label; color: Theme.secondary; font.pixelSize: 12; height: 20 }
    }
    MouseArea { id: pointer; anchors.fill: parent; hoverEnabled: true; onClicked: tool.clicked() }
}
