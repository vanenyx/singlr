pragma ComponentBehavior: Bound
import QtQuick
import Singlr.Ui
Rectangle {
    id: tile
    required property var task
    signal activated()
    signal contextRequested()
    readonly property bool running: !!task.IsWindow || !!task.IsGroupParent
    width: Math.min(150, Math.max(48, caption.implicitWidth + 46)); height: 34; radius: 6
    color: task.IsActive ? Theme.raised : pointer.containsMouse || activeFocus ? Theme.hover : "transparent"
    border.color: activeFocus ? Theme.accentText : "transparent"
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: String(task.AppName || task.display || "Aplicación")
    Keys.onMenuPressed: contextRequested()
    Keys.onReturnPressed: activated()
    Keys.onSpacePressed: activated()
    Row { anchors.centerIn: parent; spacing: 7
        AppIcon { source: tile.task.decoration; width: 20; height: 20 }
        UiText { id: caption; text: String(tile.task.AppName || tile.task.display || ""); width: Math.min(104, implicitWidth); height: 20; font.pixelSize: 12; color: Theme.muted }
    }
    Rectangle { visible: tile.running; anchors.horizontalCenter: parent.horizontalCenter; y: 37; width: tile.task.IsActive ? 12 : 3; height: 2; radius: 1; color: tile.task.IsActive ? Theme.accentText : Theme.faint }
    MouseArea { id: pointer; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: mouse => { if (mouse.button === Qt.RightButton) tile.contextRequested(); else tile.activated(); } }
}
