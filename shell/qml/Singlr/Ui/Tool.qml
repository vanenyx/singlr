pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
Rectangle {
    id: tool
    property int iconSize: 16
    property string icon: "dots-three"
    property string label: ""
    property string description: label
    signal clicked()
    width: label ? caption.implicitWidth+42 : 28; height: 28; radius: 6
    // Foco visible solo al navegar con teclado (Tab); un clic nunca deja marco ni fondo.
    property bool keyboardFocus: false
    onActiveFocusChanged: keyboardFocus = activeFocus
    color: pointer.containsMouse || keyboardFocus ? Theme.toolHover : "transparent"
    border.color: keyboardFocus ? Theme.accentText : "transparent"
    activeFocusOnTab: true
    Controls.ToolTip.visible: pointer.containsMouse && !!description
    Controls.ToolTip.text: description
    Accessible.role: Accessible.Button
    Accessible.name: description
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    Row { anchors.centerIn: parent; spacing: 7
        Icon { name: tool.icon; width: tool.iconSize; height: tool.iconSize; font.pixelSize: tool.iconSize; color: Theme.secondary; anchors.verticalCenter: parent.verticalCenter }
        UiText { id: caption; text: tool.label; visible: !!tool.label; color: Theme.secondary; font.pixelSize: 13; height: 20 }
    }
    MouseArea { id: pointer; anchors.fill: parent; hoverEnabled: true; onClicked: tool.clicked() }
}
