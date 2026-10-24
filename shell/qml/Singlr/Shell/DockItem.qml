pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import Singlr.Ui
Rectangle {
    id: tile
    property bool sessionMode: false
    required property var task
    signal activated()
    signal contextRequested()
    signal tooltipRequested(string text, real center)
    readonly property bool running: !!task?.IsWindow || !!task?.IsGroupParent
    width: 32; height: 48; radius: 6
    color: "transparent"
    // Marco de foco solo para navegación con teclado, nunca al hacer clic.
    border.color: activeFocus && !pointer.pressed && !pointer.containsMouse ? Theme.accentText : "transparent"
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: String(task?.AppName || task?.display || "Aplicación")
    Keys.onMenuPressed: contextRequested()
    Keys.onReturnPressed: activated()
    Keys.onSpacePressed: activated()
    Item {
        anchors.horizontalCenter: parent.horizontalCenter; y: 5; width: 32; height: 32
        scale: pointer.pressed ? 0.94 : pointer.containsMouse ? 1.1 : 1
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        AppIcon { visible: !tile.task?.singlrGrid; anchors.fill: parent; source: tile.task?.decoration }
        Icon { anchors.centerIn: parent; visible: !!tile.task?.singlrGrid; name: "squares-four"; width: 24; height: 24; font.pixelSize: 24; color: Theme.secondary }
    }
    MouseArea { id: pointer; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton; onContainsMouseChanged: {
        const center = tile.mapToItem(null, tile.width / 2, 0).x;
        tile.tooltipRequested(containsMouse ? tile.Accessible.name : "", center);
    }
    onPressedChanged: if (pressed) tile.tooltipRequested("", 0)
    onClicked: mouse => { if (mouse.button === Qt.RightButton) tile.contextRequested(); else tile.activated(); } }
    Controls.Popup {
        visible: !tile.sessionMode && pointer.containsMouse && !pointer.pressed
        popupType: Controls.Popup.Item
        x: (tile.width-width)/2; y: -height-8; padding: 8
        closePolicy: Controls.Popup.NoAutoClose
        background: Rectangle { radius: 8; color: "#ef191a1b"; border.color: Theme.border }
        contentItem: UiText { text: tile.Accessible.name; font.pixelSize: 12 }
    }
}
