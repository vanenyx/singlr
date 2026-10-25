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
    property Item dockOwner: null
    property var fileAcceptor: null
    property bool fileTarget: false
    signal fileDragChanged(bool inside)
    signal reorderDragChanged(bool active)
    signal reorderFinished(point position)
    signal filesDropped(var urls)
    signal interacted()
    signal newInstanceRequested()
    signal activated()
    signal contextRequested()
    signal tooltipRequested(string text, real center)
    readonly property bool running: !!task?.IsWindow || !!task?.IsGroupParent
    property int dockHeight: 48
    readonly property real sizeFactor: dockHeight / 48
    readonly property int iconSize: Math.round(dockHeight * 2 / 3)
    width: iconSize; height: dockHeight; padding: 0
    // Marco de foco solo para navegación con teclado, nunca al hacer clic.
    background: Rectangle { radius: 6; color: tile.fileTarget ? Theme.selection : "transparent"; border.color: tile.fileTarget ? Theme.accentText : tile.activeFocus && tile.keyboardFocus ? Theme.accentText : "transparent" }
    activeFocusOnTab: true
    onActiveFocusChanged: keyboardFocus = activeFocus
    Accessible.role: Accessible.Button
    Accessible.name: String(task?.AppName || task?.display || "Aplicación")
    Keys.onMenuPressed: { interacted(); contextRequested(); }
    Accessible.onPressAction: activated()
    Keys.onEnterPressed: activated()
    Keys.onReturnPressed: activated()
    Keys.onSpacePressed: activated()
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter; y: Math.round(23 * tile.sizeFactor); width: Math.round(30 * tile.sizeFactor); height: Math.round(17 * tile.sizeFactor); radius: Math.round(8 * tile.sizeFactor)
        color: Theme.accentText; opacity: 0.16
        visible: !!tile.task?.IsDemandingAttention && !tile.task?.IsActive
        layer.enabled: visible
        layer.effect: MultiEffect { blurEnabled: true; blurMax: 16; blur: 1 }
    }
    Item {
        id: iconContainer
        anchors.horizontalCenter: parent.horizontalCenter; y: Math.round(5 * tile.sizeFactor); width: tile.iconSize; height: tile.iconSize
        scale: 1
        Item {
            id: pulse; anchors.fill: parent
            AppIcon { visible: !tile.task?.singlrGrid; anchors.fill: parent; source: tile.task?.decoration }
            Icon { anchors.centerIn: parent; visible: !!tile.task?.singlrGrid; name: "squares-four"; width: Math.round(24 * tile.sizeFactor); height: width; font.pixelSize: width; color: Theme.secondary }

        }
    }
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: tile.height - height - Math.round(4 * tile.sizeFactor)
        width: Math.max(3, Math.round(3 * tile.sizeFactor)); height: width; radius: width / 2
        color: tile.task?.IsActive ? Theme.text : Theme.muted
        visible: tile.running
    }
    // MouseArea keeps its grab outside the dock. Only a release over an app
    // commits a move; releasing anywhere else leaves the model untouched.
    Item { id: dragProxy; width: 1; height: 1 }
    DropArea {
        anchors.fill: parent
        onEntered: event => {
            tile.fileDragChanged(event.hasUrls);
            tile.fileTarget = event.hasUrls && !!tile.fileAcceptor && tile.fileAcceptor(event.urls);
            event.accepted = tile.fileTarget;
        }
        onExited: { tile.fileTarget = false; tile.fileDragChanged(false); }
        onDropped: event => {
            tile.fileDragChanged(false);
            if (event.hasUrls && tile.fileAcceptor && tile.fileAcceptor(event.urls)) {
                tile.filesDropped(event.urls); event.acceptProposedAction();
            } else event.accepted = false;
            tile.fileTarget = false;
        }
    }
    MouseArea {
        id: pointer; anchors.fill: parent; hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        drag.target: tile.dockOwner ? dragProxy : null
        property bool dragged: false
        Connections {
            target: pointer.drag
            function onActiveChanged() { tile.reorderDragChanged(pointer.drag.active); }
        }
        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.ArrowCursor
        onContainsMouseChanged: {
            const center = tile.mapToItem(null, tile.width / 2, 0).x;
            tile.tooltipRequested(containsMouse && !drag.active ? tile.Accessible.name : "", center);
        }
        onPressed: mouse => {
            drag.target = mouse.button === Qt.LeftButton && tile.dockOwner ? dragProxy : null;
            dragged = false; dragProxy.x = mouse.x; dragProxy.y = mouse.y;
            tile.keyboardFocus = false; tile.interacted(); tile.tooltipRequested("", 0);
        }
        onPositionChanged: { if (drag.active) { dragged = true; tile.tooltipRequested("", 0); } }
        onReleased: mouse => {
            if ((dragged || drag.active) && tile.dockOwner) {
                dragged = true;
                tile.reorderFinished(tile.mapToItem(tile.dockOwner, mouse.x, mouse.y));
            }
        }
        onClicked: mouse => {
            if (dragged) return;
            if (mouse.button === Qt.RightButton) tile.contextRequested();
            else if (mouse.button === Qt.MiddleButton) tile.newInstanceRequested();
            else tile.activated();
        }
    }
}
