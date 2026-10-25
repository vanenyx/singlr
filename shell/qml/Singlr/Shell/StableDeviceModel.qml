pragma ComponentBehavior: Bound
import QtQuick

// Snapshots may arrive in any order. Only this model owns structural changes.
Item {
    id: stable
    property bool frozen: false
    property var pending: []
    property bool opening: true
    property string activeKey: ""
    property var sessionOrder: []
    property var states: ({})
    readonly property alias rows: rows
    ListModel { id: rows; dynamicRoles: true }
    Component {
        id: stateFactory
        QtObject {
            property bool editing: false
            property bool menuOpen: false
            property bool confirmingForget: false
            property string password: ""
        }
    }
    function stateFor(key) {
        if (!states[key]) states[key] = stateFactory.createObject(stable);
        return states[key];
    }
    function indexOf(key) {
        for (let i = 0; i < rows.count; ++i) if (rows.get(i).deviceKey === key) return i;
        return -1;
    }
    function openSession() { opening = true; sync(pending); }
    function sync(snapshot) {
        pending = snapshot;
        const seen = {};
        for (const entry of snapshot) {
            seen[entry.deviceKey] = true;
            const i = indexOf(entry.deviceKey);
            if (i >= 0) rows.setProperty(i, "payload", entry.payload);
        }
        if (frozen) return;
        for (let i = rows.count - 1; i >= 0; --i) {
            if (!seen[rows.get(i).deviceKey]) {
                // Never keep credentials for a network that has disappeared.
                const state = stateFor(rows.get(i).deviceKey);
                state.password = ""; state.editing = false; state.menuOpen = false; state.confirmingForget = false;
                rows.remove(i);
            }
        }
        const ordered = snapshot.slice();
        if (opening) ordered.sort((a, b) => b.rank - a.rank);
        for (const entry of ordered) if (indexOf(entry.deviceKey) < 0)
            rows.append({deviceKey: entry.deviceKey, payload: entry.payload, interaction: stateFor(entry.deviceKey)});
        if (opening) sessionOrder = ordered.map(entry => entry.deviceKey);
        else {
            sessionOrder = sessionOrder.filter(key => seen[key]);
            for (const entry of ordered) if (sessionOrder.indexOf(entry.deviceKey) < 0) sessionOrder.push(entry.deviceKey);
        }
        const active = snapshot.find(entry => entry.active);
        const nextActive = active ? active.deviceKey : "";
        if (opening || nextActive !== activeKey) {
            const desired = sessionOrder.filter(key => key !== nextActive);
            if (nextActive) desired.unshift(nextActive);
            for (let i = 0; i < desired.length; ++i) {
                const from = indexOf(desired[i]);
                if (from !== i) rows.move(from, i, 1);
            }
            activeKey = nextActive;
        }
        opening = false;
    }
    onFrozenChanged: if (!frozen) sync(pending)
}
