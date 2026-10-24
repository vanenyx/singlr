pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import Singlr.Ui
Item {
    id: center
    property Component backendOverride: null
    readonly property var backendObject: backend.item
    readonly property int visiblePopupCount: Math.min(3, popups.length)
    property bool live: false
    property bool sessionMode: false
    property bool historyOpen: false
    property var entries: backend.item ? backend.item.entries : []
    property var popups: []
    property var seen: ({})
    property var hovered: ({})
    property bool unread: false
    readonly property bool inhibited: backend.item ? backend.item.inhibited : false
    readonly property bool serverValid: backend.item ? backend.item.serverValid : false
    readonly property string ownerName: backend.item ? backend.item.ownerName : ""
    readonly property var grouped: entries.slice().sort((a,b) => a.app.localeCompare(b.app) || new Date(b.time) - new Date(a.time))
    width: 360; height: historyOpen ? panel.height : stack.height
    ListModel { id: popupRows }
    // Keep delegates alive across arrivals/updates so hover and animation stay stable.
    onPopupsChanged: {
        const ids = popups.slice(0, 3).map(p => p.entry.id);
        for (let row = popupRows.count - 1; row >= 0; --row)
            if (ids.indexOf(popupRows.get(row).notificationId) < 0) popupRows.remove(row);
        for (let row = 0; row < ids.length; ++row) {
            let existing = -1;
            for (let i = row; i < popupRows.count; ++i)
                if (popupRows.get(i).notificationId === ids[row]) { existing = i; break; }
            if (existing < 0) popupRows.insert(row, {notificationId: ids[row]});
            else if (existing !== row) popupRows.move(existing, row, 1);
        }
    }
    function toggle() { historyOpen = !historyOpen; }
    function setInhibited(value) { if (backend.item) backend.item.setInhibited(value); }
    function dispatch(id, action) {
        popups = popups.filter(p => p.entry.id !== id);
        if (backend.item) backend.item.dispatch(id, action);
    }
    function clearAll() { for (const e of entries.slice()) dispatch(e.id, "close"); unread = false; }
    function ingest() {
        let next = popups.filter(p => entries.some(e => e.id === p.entry.id && !e.expired && !e.dismissed));
        const known = Object.assign({}, seen);
        for (const e of entries) {
            const stamp = String(new Date(e.time).getTime());
            if (known[e.id] === stamp) {
                const popup = next.find(p => p.entry.id === e.id);
                if (popup) popup.entry = e;
                continue;
            }
            known[e.id] = stamp;
            next = next.filter(p => p.entry.id !== e.id);
            if (!historyOpen) unread = true;
            if (!e.expired && !e.dismissed && !e.suppressed && (!inhibited || e.critical)) {
                next.push({entry: e, remaining: e.critical || e.timeout === 0 ? -1 : e.timeout > 0 ? e.timeout : 5000});
                console.log("NOTIFICATION_POPUP " + e.app + ": " + e.title);
            }
        }
        seen = known; popups = next;
    }
    onEntriesChanged: ingest()
    onHistoryOpenChanged: if (historyOpen) { unread = false; if (backend.item) backend.item.markRead(); }
    Loader {
        id: backend
        sourceComponent: center.backendOverride || (center.live ? realBackend : demoBackend)
        onLoaded: center.ingest()
    }
    Component { id: realBackend; NotificationsBackend {} }
    Component {
        id: demoBackend
        Item {
            id: demo
            property bool inhibited: false
            property bool serverValid: false
            property string ownerName: "Demostración"
            property var entries: [{id: 1, app: "Singlr", icon: "dialog-information", title: "Prueba de notificación", body: "Las notificaciones de tus aplicaciones aparecerán aquí.", time: new Date(), timeout: 5000, critical: false, expired: false, dismissed: false, suppressed: false, defaultAction: false, actionNames: [], actionLabels: []}]
            function setInhibited(value) { inhibited = value; }
            function markRead() {}
            function dispatch(id, action) {
                entries = entries.filter(e => e.id !== id || action === "expire").map(e => e.id === id ? Object.assign({}, e, {expired: true}) : e);
            }
        }
    }
    Timer {
        interval: 100; repeat: true; running: center.popups.length > 0
        onTriggered: {
            const expired = [];
            const next = center.popups.slice();
            for (let i = 0; i < Math.min(3, next.length); ++i) {
                const p = next[i];
                if (p.remaining < 0 || center.hovered[p.entry.id] || center.historyOpen) continue;
                p.remaining -= 100;
                if (p.remaining <= 0) expired.push(p.entry.id);
            }
            for (const id of expired) center.dispatch(id, "expire");
        }
    }
    Column {
        id: stack; width: 360; spacing: 8; visible: !center.historyOpen
        Repeater {
            model: popupRows
            NotificationCard {
                id: popup
                required property int notificationId
                entry: center.popups.find(p => p.entry.id === notificationId)?.entry || ({app:"",title:"",body:"",time:new Date(),icon:""})
                sessionMode: center.sessionMode
                onHoveredChanged: center.hovered[notificationId] = hovered
                Component.onDestruction: delete center.hovered[notificationId]
                onDismissed: center.dispatch(notificationId, "close")
                onInvoked: action => center.dispatch(notificationId, action)
            }
        }
        add: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160 } NumberAnimation { property: "x"; from: 8; to: 0; duration: 160 } } }
        move: Transition { NumberAnimation { properties: "y"; duration: 160 } }
    }
    Rectangle {
        id: panel; width: 360; height: Math.min(620, panelHeader.height + history.contentHeight + 28); visible: center.historyOpen
        radius: 10; color: center.sessionMode ? "#e6191a1b" : Theme.raised; border.color: Theme.border
        Column {
            id: panelHeader; x: 14; y: 10; width: parent.width - 28; spacing: 4
            Row {
                width: parent.width
                UiText { width: 198; height: 28; text: "Notificaciones"; weight: 590 }
                Controls.AbstractButton {
                    id: clearButton
                    width: 104; height: 28; text: "Borrar todo"; enabled: center.entries.length > 0
                    contentItem: UiText { text: clearButton.text; color: Theme.secondary; horizontalAlignment: Text.AlignHCenter }
                    background: Rectangle { radius: 6; color: clearButton.hovered || clearButton.activeFocus ? Theme.hover : "transparent" }
                    onClicked: center.clearAll()
                }
                Tool { icon: "x"; width: 28; description: "Cerrar historial"; onClicked: center.historyOpen = false }
            }
            Controls.Switch {
                id: dnd; width: parent.width; height: 32; leftPadding: 0; rightPadding: 48
                text: "No molestar"; checked: center.inhibited
                onToggled: center.setInhibited(checked)
                contentItem: UiText { text: dnd.text; color: Theme.secondary }
                indicator: Rectangle {
                    x: dnd.width - width; y: (dnd.height - height) / 2
                    width: 32; height: 18; radius: 9
                    color: dnd.checked ? Theme.accent : Theme.hover
                    border.color: dnd.activeFocus ? Theme.accentText : Theme.focusBorder
                    Rectangle { x: dnd.checked ? 16 : 3; y: 3; width: 12; height: 12; radius: 6; color: Theme.secondary; Behavior on x { NumberAnimation { duration: 160 } } }
                }
            }
            UiText { visible: center.live && !center.serverValid; width: parent.width; text: "Servidor no disponible · " + center.ownerName; color: Theme.secondary; wrapMode: Text.Wrap }
            UiText { visible: !center.entries.length; height: visible ? 40 : 0; text: "No tienes notificaciones"; color: Theme.muted }
        }
        ListView {
            id: history; x: 0; y: panelHeader.height + 18; width: parent.width; height: parent.height - y - 10; clip: true; spacing: 6
            model: center.grouped
            delegate: Column {
                id: historyRow
                required property var modelData
                required property int index
                width: 360
                UiText {
                    width: 332; x: 14; height: visible ? 28 : 0
                    visible: historyRow.index === 0 || center.grouped[historyRow.index - 1].app !== historyRow.modelData.app
                    text: historyRow.modelData.app; color: Theme.muted; font.pixelSize: 11; weight: 590
                }
                NotificationCard {
                    entry: historyRow.modelData; sessionMode: center.sessionMode
                    onDismissed: center.dispatch(historyRow.modelData.id, "close")
                    onInvoked: action => center.dispatch(historyRow.modelData.id, action)
                }
            }
        }
    }
}
