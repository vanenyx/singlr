pragma ComponentBehavior: Bound
import QtQuick
Rectangle {
    id: tool
    property int iconSize: 16
    property string icon: "dots-three"
    property string label: ""
    property string description: label
    signal clicked()
    width: label ? caption.implicitWidth+42 : 28; height: 28; radius: 6
    color: pointer.containsMouse || activeFocus ? "#0dffffff" : "transparent"
    border.color: activeFocus ? Theme.accentText : "transparent"
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: description
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    Row { anchors.centerIn: parent; spacing: 7
        Icon { name: tool.icon; width: tool.iconSize; height: tool.iconSize; font.pixelSize: tool.iconSize; color: Theme.secondary; anchors.verticalCenter: parent.verticalCenter }
        UiText { id: caption; text: tool.label; visible: !!tool.label; color: Theme.secondary; font.pixelSize: 13; height: 20 }
    }
    MouseArea { id: pointer; anchors.fill: parent; hoverEnabled: true; onClicked: { tool.forceActiveFocus(); tool.clicked(); } }
}
