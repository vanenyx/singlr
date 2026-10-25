pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Controls as Controls
import Singlr.Ui
Controls.Control {
    id: tile
    property bool sessionMode: false
    required property var task
    property bool launching: false
    property bool keyboardFocus: false
    signal interacted()
    signal newInstanceRequested()
    signal activated()
    signal contextRequested()
    signal tooltipRequested(string text, real center)
    readonly property bool running: !!task?.IsWindow || !!task?.IsGroupParent
    width: 32; height: 48; padding: 0
    // Marco de foco solo para navegación con teclado, nunca al hacer clic.
    background: Rectangle { radius: 6; color: "transparent"; border.color: tile.activeFocus && tile.keyboardFocus ? Theme.accentText : "transparent" }
    activeFocusOnTab: true
    onActiveFocusChanged: keyboardFocus = activeFocus && (focusReason === Qt.TabFocusReason || focusReason === Qt.BacktabFocusReason)
    Accessible.role: Accessible.Button
    Accessible.name: String(task?.AppName || task?.display || "Aplicación")
    Keys.onMenuPressed: { interacted(); contextRequested(); }
    Keys.onReturnPressed: activated()
    Keys.onSpacePressed: activated()
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter; y: 23; width: 30; height: 17; radius: 8
        color: Theme.accentText; opacity: 0.16
        visible: !!tile.task?.IsDemandingAttention && !tile.task?.IsActive
        layer.enabled: true
        layer.effect: MultiEffect { blurEnabled: true; blurMax: 16; blur: 1 }
    }
    Item {
        id: iconContainer
        anchors.horizontalCenter: parent.horizontalCenter; y: 5; width: 32; height: 32
        scale: 1
        Item {
            id: pulse; anchors.fill: parent
            AppIcon { visible: !tile.task?.singlrGrid; anchors.fill: parent; source: tile.task?.decoration }
            Icon { anchors.centerIn: parent; visible: !!tile.task?.singlrGrid; name: "squares-four"; width: 24; height: 24; font.pixelSize: 24; color: Theme.secondary }

        }
    }
    MouseArea { id: pointer; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton; onContainsMouseChanged: {
        const center = tile.mapToItem(null, tile.width / 2, 0).x;
        tile.tooltipRequested(containsMouse ? tile.Accessible.name : "", center);
    }
    onPressed: { tile.keyboardFocus = false; tile.interacted(); tile.tooltipRequested("", 0); }
    onClicked: mouse => { if (mouse.button === Qt.RightButton) tile.contextRequested(); else if (mouse.button === Qt.MiddleButton) tile.newInstanceRequested(); else tile.activated(); } }
}
