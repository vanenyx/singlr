import QtQuick
import org.kde.kirigami as Kirigami
import "../../../../../../shell/qml/Singlr/Ui" as Ui

FocusScope {
    id: frame
    focus: true
    property var windowModel: null
    property int selectedIndex: 0
    property rect screenGeometry: Qt.rect(0, 0, 1280, 800)
    property Component thumbnailComponent
    signal activated(int index)
    signal selectionRequested(int index)
    width: Math.min(frame.screenGeometry.width * .88, 1000)
    height: Math.min(frame.screenGeometry.height * .7, 460)
    Rectangle {
        anchors.fill: parent
        color: Ui.Theme.surface
        radius: Ui.Theme.radius
        border.color: Ui.Theme.focusBorder
    }
    GridView {
        objectName: "switcherGrid"
        id: grid
        anchors.fill: parent
        anchors.margins: 16
        cellWidth: width / Math.max(1, Math.floor(width / 230))
        cellHeight: 196
        clip: true
        focus: true
        model: frame.windowModel
        currentIndex: frame.selectedIndex
        keyNavigationWraps: true
        highlightMoveDuration: 0
        onCurrentIndexChanged: frame.selectionRequested(currentIndex)
        delegate: MouseArea {
            id: card
            required property int index
            required property var model
            width: grid.cellWidth; height: grid.cellHeight
            hoverEnabled: true
            Accessible.role: Accessible.ListItem
            Accessible.name: model.caption
            Accessible.selected: GridView.isCurrentItem
            Accessible.onPressAction: frame.activated(index)
            onClicked: frame.activated(index)
            Rectangle {
                anchors.fill: parent; anchors.margins: 4
                radius: 8
                color: card.GridView.isCurrentItem || card.containsMouse ? Ui.Theme.hover : Ui.Theme.content
                border.color: card.GridView.isCurrentItem ? Ui.Theme.text : Ui.Theme.border
                Loader {
                    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: caption.top; margins: 10 }
                    property var windowId: card.model.windowId
                    sourceComponent: frame.thumbnailComponent
                }
                Row {
                    id: caption
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
                    spacing: 8; height: 20
                    Kirigami.Icon { width: 20; height: 20; source: card.model.icon }
                    Text {
                        width: parent.width - 28; height: 20
                        text: card.model.caption; textFormat: Text.PlainText
                        font.family: Ui.Theme.family; font.pixelSize: 12
                        color: Ui.Theme.text; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Left) grid.moveCurrentIndexLeft();
        else if (event.key === Qt.Key_Right) grid.moveCurrentIndexRight();
        else if (event.key === Qt.Key_Up) grid.moveCurrentIndexUp();
        else if (event.key === Qt.Key_Down) grid.moveCurrentIndexDown();
        else { event.accepted = false; return; }
        event.accepted = true;
    }
}
