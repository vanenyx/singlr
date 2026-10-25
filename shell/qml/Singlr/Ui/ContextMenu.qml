pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic as Controls

Controls.Popup {
    id: menu
    property var entries: []
    property string headerName: ""
    property url headerIcon: ""
    property int currentIndex: 0
    property real fixedHeight: 0
    readonly property real entriesHeight: 8 + (headerName ? 45 : 0) + entries.reduce((sum, entry) => sum + (entry.separatorOnly ? 9 : 28 + (entry.separator ? 9 : 0)), 0)
    property int confirmingIndex: -1
    property Item returnFocus: null
    property point actionPosition: Qt.point(0, 0)
    signal auxiliaryTriggered(var entry, int button)
    signal scrolled(var entry, real delta, string orientation)
    signal triggered(var entry)
    width: 240
    height: fixedHeight > 0 ? fixedHeight : entriesHeight
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
            if (entries[currentIndex].enabled !== false && !entries[currentIndex].separatorOnly) return;
        }
    }
    onCurrentIndexChanged: {
        const row = menuRows.itemAt(currentIndex);
        if (row && visible) row.actionItem.forceActiveFocus();
        if (row) viewport.contentY = Math.max(0, Math.min(viewport.contentHeight - viewport.height,
            row.y < viewport.contentY ? row.y : Math.max(viewport.contentY, row.y + row.height - viewport.height)));
    }
    function activate(index) {
        const entry = entries[index];
        if (!entry || entry.enabled === false || entry.separatorOnly) return;
        currentIndex = index;
        if (entry.destructive && confirmingIndex !== index) { confirmingIndex = index; return; }
        triggered(entry);
        if (!entry.keepOpen) close();
    }
    onAboutToShow: {
        confirmingIndex = -1; currentIndex = entries.length - 1; move(1);
        Qt.callLater(function() {
            const row = menuRows.itemAt(menu.currentIndex);
            if (menu.visible && row) row.actionItem.forceActiveFocus();
        });
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
                radius: 9 + index; color: "transparent"; border.color: Theme.softShadow; border.width: 2
            }
        }
    }
    contentItem: Flickable {
        id: viewport
        Accessible.role: Accessible.PopupMenu
        Accessible.name: menu.headerName || "Acciones"
        clip: true
        contentHeight: rows.height
        boundsBehavior: Flickable.StopAtBounds
        Controls.ScrollBar.vertical: Controls.ScrollBar {}
        focus: true
        Keys.onTabPressed: menu.move(1)
        Keys.onBacktabPressed: menu.move(-1)
        Keys.onSpacePressed: menu.activate(menu.currentIndex)
        Keys.onUpPressed: menu.move(-1)
        Keys.onDownPressed: menu.move(1)
        Keys.onReturnPressed: menu.activate(menu.currentIndex)
        Keys.onEnterPressed: menu.activate(menu.currentIndex)
        Keys.onEscapePressed: menu.close()
        Column {
        id: rows
        width: viewport.width
        Item {
            width: rows.width; height: menu.headerName ? 45 : 0; visible: !!menu.headerName
            Rectangle {
                x: 6; y: 6; width: 24; height: 24; radius: 12; color: Theme.hover
                UiText { anchors.centerIn: parent; text: menu.headerName.charAt(0).toUpperCase(); visible: avatar.status !== Image.Ready }
                Image { id: avatar; anchors.fill: parent; source: menu.headerIcon; sourceSize: Qt.size(24, 24); fillMode: Image.PreserveAspectCrop; visible: status === Image.Ready }
            }
            UiText { x: 38; y: 4; height: 28; width: parent.width - 44; text: menu.headerName; elide: Text.ElideRight; weight: 590 }
            Rectangle { x: 4; y: 40; width: parent.width - 8; height: 1; color: Theme.border }
        }
        Repeater {
            id: menuRows
            model: menu.entries
            delegate: Column {
                id: row
                property alias actionItem: actionItem
                required property var modelData
                required property int index
                width: menu.availableWidth
                Item {
                    width: parent.width; height: (row.modelData.separator || row.modelData.separatorOnly) ? 9 : 0
                    Rectangle { visible: parent.height > 0; anchors.centerIn: parent; width: parent.width - 8; height: 1; color: Theme.border }
                }
                Rectangle {
                    id: actionItem
                    objectName: "contextAction" + row.index
                    enabled: row.modelData.enabled !== false && !row.modelData.separatorOnly
                    Accessible.focusable: enabled
                    Accessible.onPressAction: menu.activate(row.index)
                    Accessible.description: row.modelData.shortcut || ""
                    Accessible.checkable: !!row.modelData.toggleType
                    Accessible.checked: !!row.modelData.toggleState
                    border.color: activeFocus ? Theme.accentText : "transparent"
                    width: parent.width; height: row.modelData.separatorOnly ? 0 : 28; visible: !row.modelData.separatorOnly; radius: 4
                    color: menu.currentIndex === row.index ? Theme.hover : "transparent"
                    opacity: row.modelData.enabled === false ? 0.4 : 1
                    Accessible.role: Accessible.MenuItem
                    Accessible.name: caption.text
                    Image {
        sourceSize: Qt.size(Math.max(1, Math.ceil(width * Screen.devicePixelRatio)), Math.max(1, Math.ceil(height * Screen.devicePixelRatio))); x: 6; anchors.verticalCenter: parent.verticalCenter; width: 14; height: 14; source: row.modelData.imageSource || ""; visible: !!String(source); fillMode: Image.PreserveAspectFit }
                    AppIcon { x: 6; anchors.verticalCenter: parent.verticalCenter; width: 14; height: 14; name: row.modelData.iconName || ""; visible: !!row.modelData.iconName && !row.modelData.imageSource && !row.modelData.toggleType }
                    Rectangle {
                        x: 7; anchors.verticalCenter: parent.verticalCenter; width: 12; height: 12
                        visible: !!row.modelData.toggleType
                        radius: row.modelData.toggleType === "radio" ? 6 : 2
                        color: "transparent"; border.color: Theme.secondary
                        Rectangle { anchors.centerIn: parent; width: 6; height: row.modelData.toggleState === -1 ? 2 : 6; radius: row.modelData.toggleType === "radio" ? 3 : 1; color: Theme.text; visible: row.modelData.toggleState !== 0 }
                    }
                    Icon { visible: !row.modelData.iconName && !row.modelData.imageSource && !row.modelData.toggleType; x: 6; anchors.verticalCenter: parent.verticalCenter; width: 14; height: 14; font.pixelSize: 14; name: row.modelData.icon || (row.modelData.active ? "check" : "dots-three"); color: caption.color }
                    UiText {
                        id: caption; x: 28; height: 28; width: parent.width - x - hint.width - 10
                        font.pixelSize: 13
                        text: menu.confirmingIndex === row.index ? (row.modelData.confirmation || "¿Confirmar? Pulsa de nuevo") : (row.modelData.label || "")
                        color: menu.confirmingIndex === row.index ? Theme.error : Theme.text
                        elide: Text.ElideRight
                    }
                    UiText { id: hint; anchors.right: parent.right; anchors.rightMargin: 6; height: 28; text: menu.confirmingIndex === row.index ? "" : row.modelData.shortcut || ""; font.pixelSize: 13; color: Theme.muted }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true
                        onEntered: menu.currentIndex = row.index
                        acceptedButtons: Qt.LeftButton | (row.modelData.trayItem ? Qt.RightButton | Qt.MiddleButton : Qt.NoButton)
                        onClicked: mouse => {
                            menu.actionPosition = mapToGlobal(mouse.x, mouse.y);
                            if (mouse.button === Qt.LeftButton) menu.activate(row.index);
                            else menu.auxiliaryTriggered(row.modelData, mouse.button);
                        }
                        onWheel: wheel => {
                            if (!row.modelData.trayItem) { wheel.accepted = false; return; }
                            if (wheel.angleDelta.y) menu.scrolled(row.modelData, wheel.angleDelta.y, "vertical");
                            if (wheel.angleDelta.x) menu.scrolled(row.modelData, wheel.angleDelta.x, "horizontal");
                        }
                    }
                }
            }
        }
    }
    }
}
