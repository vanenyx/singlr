pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import org.kde.kitemmodels as KItemModels
import Singlr.Ui

FocusScope {
    id: panel
    Accessible.role: Accessible.Pane
    Accessible.name: "Portapapeles"
    required property var history
    property alias query: search.text
    property alias selectedIndex: list.currentIndex
    readonly property int resultCount: list.count
    readonly property alias menu: actions
    property var actionModel: null
    property string actionUuid: ""
    signal closed()
    Keys.onUpPressed: { panel.move(-1); if (list.currentItem) list.currentItem.forceActiveFocus(Qt.TabFocusReason); }
    Keys.onDownPressed: { panel.move(1); if (list.currentItem) list.currentItem.forceActiveFocus(Qt.TabFocusReason); }
    width: 760; height: 542
    function focusInput() { search.forceActiveFocus(); }
    function open() { query = ""; selectedIndex = 0; focusInput(); }
    function close() { actions.close(); closed(); }
    function move(delta) {
        if (list.count) selectedIndex = (Math.max(0, selectedIndex) + delta + list.count) % list.count;
    }
    function copy(uuid) { history.moveToTop(uuid); close(); }
    readonly property ClipboardEntry currentEntry: list.currentItem as ClipboardEntry
    function run() { if (currentEntry) copy(currentEntry.model.uuid); }
    function openMenu(data, anchor, px, py) {
        actionModel = data; actionUuid = data ? data.uuid : "";
        actions.entries = [
            {label: data && data.starred ? "Desfijar" : "Fijar", icon: "push-pin", action: "pin", enabled: !!data},
            {label: "Eliminar", icon: "trash", action: "remove", enabled: !!data},
            {label: "Vaciar historial", icon: "trash", action: "clear", separator: true,
                enabled: typeof panel.history.removeRows === "function", destructive: true, confirmation: "¿Vaciar todo? Pulsa de nuevo"}
        ];
        actions.showAt(anchor, px, py);
    }
    onVisibleChanged: if (!visible) actions.close()
    onQueryChanged: { selectedIndex = 0; actions.close(); }
    Keys.onEscapePressed: close()
    Glass { anchors.fill: parent; compositorBlur: Qt.platform.pluginName.startsWith("wayland") }
    Icon { x: 24; y: 25; width: 20; height: 20; font.pixelSize: 20; name: "magnifying-glass" }
    TextInput {
        activeFocusOnTab: true
        id: search; objectName: "clipboardSearch"
        x: 62; y: 18; width: parent.width - 124; height: 40; clip: true; focus: true
        color: Theme.text; selectionColor: Theme.selection; selectedTextColor: Theme.text
        font.family: Theme.family; font.pixelSize: 13; verticalAlignment: TextInput.AlignVCenter
        Accessible.role: Accessible.EditableText
        Accessible.description: "Flechas para seleccionar, Enter para abrir, Escape para cerrar"
        Rectangle { anchors.fill: parent; anchors.margins: -3; z: -1; radius: Theme.radius; color: "transparent"; border.color: parent.activeFocus ? Theme.accentText : "transparent" }
        Accessible.name: "Buscar en el portapapeles"
        Keys.onUpPressed: panel.move(-1)
        Keys.onDownPressed: panel.move(1)
        Keys.onReturnPressed: panel.run()
        Keys.onEnterPressed: panel.run()
        UiText { anchors.fill: parent; text: "Buscar en el portapapeles…"; color: Theme.faint; visible: !search.text }
    }
    ShortcutHint { x: parent.width - 47; y: 27; text: "esc" }
    Rectangle { y: 76; width: parent.width; height: 1; color: Theme.border }
    ListView {
        id: list; objectName: "clipboardList"
        x: 10; y: 88; width: parent.width - 20; height: parent.height - 146
        clip: true; currentIndex: 0; highlightMoveDuration: 0
        boundsBehavior: Flickable.StopAtBounds
        onCountChanged: { currentIndex = count ? Math.max(0, Math.min(currentIndex, count - 1)) : -1; }
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        model: KItemModels.KSortFilterProxyModel {
            sourceModel: panel.history
            filterRoleName: "display"
            // Literal search: brackets and other regexp characters remain ordinary text.
            filterRegularExpression: new RegExp(search.text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "i")
        }
        delegate: ClipboardEntry {}
    }
    component ClipboardEntry: ListItem {
        id: entry
        required property var model
        required property int index
            onActiveFocusChanged: if (activeFocus) panel.selectedIndex = index
        required property int type
        width: list.width; height: 44; trailingWidth: 72
        title: entry.type === 4 ? "Imagen" : String(model.display || "").replace(/\s+/g, " ")
        selected: list.currentIndex === index
        Keys.onMenuPressed: panel.openMenu(entry.model, entry, width - 28, height)
        onClicked: { list.currentIndex = index; panel.copy(model.uuid); }
        Image {
            objectName: "clipboardThumbnail"
            x: 14; anchors.verticalCenter: parent.verticalCenter; width: 24; height: 28
            visible: entry.type === 4; source: visible ? entry.model.decoration : ""
            sourceSize: Qt.size(48 * Screen.devicePixelRatio, 56 * Screen.devicePixelRatio)
            fillMode: Image.PreserveAspectFit; cache: false
        }
        Icon { objectName: "clipboardTypeIcon"; x: 16; anchors.verticalCenter: parent.verticalCenter; visible: entry.type !== 4; name: entry.type === 8 || /^https?:\/\//.test(String(entry.model.display)) ? "link" : "clipboard-text" }
        Icon { anchors.right: more.left; anchors.verticalCenter: parent.verticalCenter; visible: !!entry.model.starred; name: "push-pin" }
        TapHandler { acceptedButtons: Qt.RightButton; onTapped: point => panel.openMenu(entry.model, entry, point.position.x, point.position.y) }
        Tool { id: more; objectName: "clipboardMore"; anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter; description: "Acciones"; onClicked: panel.openMenu(entry.model, more, 0, more.height) }
    }
    UiText { x: list.x; y: list.y; width: list.width; height: list.height; horizontalAlignment: Text.AlignHCenter; visible: list.count === 0; text: panel.query ? "Sin resultados" : "Portapapeles vacío"; color: Theme.muted }
    Rectangle { y: parent.height - 42; width: parent.width; height: 1; color: Theme.border }
    Tool { x: 18; y: parent.height - 35; icon: "dots-three"; description: "Acciones del historial"; onClicked: panel.openMenu(panel.currentEntry ? panel.currentEntry.model : null, panel, 18, panel.height - 42) }
    Row { anchors.right: parent.right; anchors.rightMargin: 16; y: parent.height - 31; spacing: 8
        ShortcutHint { text: "⏎" }
        UiText { height: 20; text: "Copiar"; color: Theme.secondary }
    }
    ContextMenu {
        id: actions; parent: panel
        onClosed: { panel.actionModel = null; panel.actionUuid = ""; }
        onTriggered: entry => {
            if (entry.action === "clear") {
                // clearHistory() opens a QWidget confirmation in Klipper 6.8.1.
                // The menu already confirmed: use the same KDE model row action.
                const count = panel.history.rowCount();
                if (count) panel.history.removeRows(0, count);
            }
            else if (entry.action === "remove") panel.history.remove(panel.actionUuid);
            else if (panel.actionModel) panel.actionModel.starred = !panel.actionModel.starred;
        }
    }
    // Do not retain a delegate role object after insertion/removal/reordering.
    Connections {
        target: panel.history; ignoreUnknownSignals: true
        function onRowsAboutToBeRemoved() { actions.close(); }
        function onRowsAboutToBeInserted() { actions.close(); }
        function onRowsAboutToBeMoved() { actions.close(); }
        function onModelAboutToBeReset() { actions.close(); }
        function onLayoutAboutToBeChanged() { actions.close(); }
    }
}
