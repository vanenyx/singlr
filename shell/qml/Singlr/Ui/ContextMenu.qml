pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls

Controls.Popup {
    id: menu
    property var entries: []
    property int currentIndex: 0
    property int confirmingIndex: -1
    property Item returnFocus: null
    signal triggered(var entry)
    width: 240
    height: 8 + entries.reduce((sum, entry) => sum + 28 + (entry.separator ? 9 : 0), 0)
    padding: 4
    margins: 4
    focus: true
    modal: true
    dim: false
    popupType: Controls.Popup.Item
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
    function showAt(anchor, px, py) {
        returnFocus = anchor;
        const point = anchor.mapToItem(parent, px, py);
        x = Math.max(4, Math.min(point.x, parent.width - width - 4));
        y = Math.max(4, Math.min(point.y, parent.height - height - 4));
        open();
    }
    function move(direction) {
        confirmingIndex = -1;
        for (let i = 0; i < entries.length; ++i) {
            currentIndex = (currentIndex + direction + entries.length) % entries.length;
            if (entries[currentIndex].enabled !== false) return;
        }
    }
    function activate(index) {
        const entry = entries[index];
        if (!entry || entry.enabled === false) return;
        currentIndex = index;
        if (entry.destructive && confirmingIndex !== index) { confirmingIndex = index; return; }
        triggered(entry);
        close();
    }
    onAboutToShow: {
        confirmingIndex = -1; currentIndex = entries.length - 1; move(1);
        contentItem.forceActiveFocus();
    }
    onClosed: {
        confirmingIndex = -1;
        if (returnFocus) returnFocus.forceActiveFocus();
        returnFocus = null;
    }
    background: Rectangle {
        radius: 8; color: Theme.raised; border.color: Theme.border
        // Small layered shadow also works with the software renderer.
        Repeater {
            model: 4
            Rectangle {
                required property int index
                z: -1; x: -index - 1; y: -index + 1
                width: parent.width + 2 * (index + 1); height: parent.height + 2 * (index + 1)
                radius: 9 + index; color: "transparent"; border.color: "#10000000"; border.width: 2
            }
        }
    }
    contentItem: Column {
        focus: true
        Keys.onUpPressed: menu.move(-1)
        Keys.onDownPressed: menu.move(1)
        Keys.onReturnPressed: menu.activate(menu.currentIndex)
        Keys.onEnterPressed: menu.activate(menu.currentIndex)
        Keys.onEscapePressed: menu.close()
        Repeater {
            model: menu.entries
            delegate: Column {
                id: row
                required property var modelData
                required property int index
                width: menu.availableWidth
                Item {
                    width: parent.width; height: row.modelData.separator ? 9 : 0
                    Rectangle { visible: parent.height > 0; anchors.centerIn: parent; width: parent.width - 8; height: 1; color: Theme.border }
                }
                Rectangle {
                    objectName: "contextAction" + row.index
                    width: parent.width; height: 28; radius: 4
                    color: menu.currentIndex === row.index ? Theme.hover : "transparent"
                    opacity: row.modelData.enabled === false ? 0.4 : 1
                    Accessible.role: Accessible.MenuItem
                    Accessible.name: caption.text
                    Icon { x: 6; anchors.verticalCenter: parent.verticalCenter; width: 14; height: 14; font.pixelSize: 14; name: row.modelData.icon || (row.modelData.active ? "check" : "dots-three"); color: caption.color }
                    UiText {
                        id: caption; x: 28; height: 28; width: parent.width - x - hint.width - 10
                        font.pixelSize: 13
                        text: menu.confirmingIndex === row.index ? (row.modelData.confirmation || "¿Confirmar? Pulsa de nuevo") : row.modelData.label
                        color: menu.confirmingIndex === row.index ? (Theme.dark ? "#ef9a9a" : "#ae3535") : Theme.text
                        elide: Text.ElideRight
                    }
                    UiText { id: hint; anchors.right: parent.right; anchors.rightMargin: 6; height: 28; text: menu.confirmingIndex === row.index ? "" : row.modelData.shortcut || ""; font.pixelSize: 13; color: Theme.muted }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true
                        onEntered: menu.currentIndex = row.index
                        onClicked: menu.activate(row.index)
                    }
                }
            }
        }
    }
}
