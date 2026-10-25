pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import org.kde.plasma.workspace.keyboardlayout as Keyboards
import Singlr.Ui

Item {
    id: indicator
    property var backend: layout
    readonly property Item windowRoot: Window.window ? Window.window.contentItem : null
    property Item menuHost: null
    property bool opened: false
    property real menuX: 0
    property var entries: []
    readonly property real menuHeight: Math.min(288, 8 + entries.length * 28)
    readonly property var popup: menuLoader.item
    width: 58; height: 22
    visible: backend.layoutsList.length > 1
    Keyboards.KeyboardLayout { id: layout }
    function close() { opened = false; }
    function showMenu() {
        // Snapshot: configuration changes cannot move entries in an open menu.
        entries = backend.layoutsList.map((entry, index) => ({label: entry.longName || entry.displayName || entry.shortName,
                    icon: index === backend.layout ? "check" : "keyboard", layoutIndex: index}));
        menuX = mapToItem(null, 0, 0).x;
        opened = true;
        if (popup) popup.open();
    }
    Tool {
        id: button; objectName: "keyboardLayoutButton"; anchors.fill: parent; icon: "keyboard"; iconSize: 15
        label: indicator.backend.layoutsList.length > indicator.backend.layout
               ? indicator.backend.layoutsList[indicator.backend.layout].shortName.toUpperCase().slice(0, 2) : ""
        description: "Distribución de teclado · " + (indicator.backend.layoutsList.length > indicator.backend.layout
                     ? indicator.backend.layoutsList[indicator.backend.layout].longName : "")
        onClicked: indicator.backend.switchToNextLayout()
        TapHandler { acceptedButtons: Qt.RightButton; onTapped: indicator.showMenu() }
        Keys.onMenuPressed: indicator.showMenu()
        Keys.onPressed: event => { if (event.key === Qt.Key_F10 && event.modifiers & Qt.ShiftModifier) { indicator.showMenu(); event.accepted = true; } }
    }
    DeferredLoader {
        id: menuLoader; opened: indicator.opened
        onLoaded: if (indicator.opened) (item as ContextMenu).open()
        sourceComponent: Component {
            ContextMenu {
                parent: indicator.menuHost || indicator.windowRoot || indicator
                x: indicator.menuHost ? 0 : Math.min(indicator.menuX, parent.width - width - 4)
                y: indicator.menuHost ? 0 : 32
                visible: indicator.opened
                entries: indicator.entries; fixedHeight: indicator.menuHeight
                onTriggered: entry => { indicator.backend.layout = entry.layoutIndex; indicator.close(); }
                onClosed: indicator.close()
            }
        }
    }
}
