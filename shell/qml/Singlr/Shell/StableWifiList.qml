pragma ComponentBehavior: Bound
import QtQuick
import org.kde.plasma.networkmanagement as Network

ListView {
    id: list
    required property var handler
    property var sourceModel: null
    property bool pageActive: false
    readonly property alias stableModel: stable
    property var pendingPassword: null
    property WifiRow editingRow: null
    signal menuRequested(var data, var anchor, real px, real py)
    signal networkUpdated(string key, var data)
    signal settingsRequested()
    clip: true
    reuseItems: false
    currentIndex: -1
    model: stable.rows
    add: null; remove: null; displaced: null; move: null; populate: null
    StableDeviceModel { id: stable; promoteActive: false }
    function connectNetwork(data) {
        const row = rowFor(data);
        if (row) row.connectNetwork();
    }
    function rowFor(data) {
        for (let i = 0; i < count; ++i) {
            const candidate = stable.rows.get(i).payload;
            if ((data.Uuid && candidate.Uuid === data.Uuid) || (!data.Uuid && candidate.Ssid === data.Ssid && candidate.SecurityType === data.SecurityType)) {
                positionViewAtIndex(i, ListView.Contain); forceLayout();
                return itemAtIndex(i);
            }
        }
        return null;
    }
    function showPassword(data, retry = false) {
        pendingPassword = {data: data, retry: retry};
        resolvePassword();
    }
    function resolvePassword() {
        if (!pendingPassword) return;
        for (let i = 0; i < count; ++i) {
            const data = stable.rows.get(i).payload;
            if ((pendingPassword.data.Uuid && data.Uuid === pendingPassword.data.Uuid) || data.Ssid === pendingPassword.data.Ssid) {
                positionViewAtIndex(i, ListView.Contain); forceLayout();
                const target = itemAtIndex(i);
                if (!target) { Qt.callLater(resolvePassword); return; }
                const pending = pendingPassword; pendingPassword = null;
                if (editingRow && editingRow !== target) editingRow.closePassword();
                target.showPassword(pending.retry);
                return;
            }
        }
    }
    function closePassword() { pendingPassword = null; if (editingRow) editingRow.closePassword(); }

    function keyFor(data) {
        // Saving a new connection assigns a UUID; keep its existing delegate and position.
        for (let i = 0; i < stable.rows.count; ++i) {
            const entry = stable.rows.get(i);
            if (data.Uuid && entry.payload.Uuid === data.Uuid) return entry.deviceKey;
        }
        for (let i = 0; i < stable.rows.count; ++i) {
            const entry = stable.rows.get(i); const previous = entry.payload;
            if ((!previous.Uuid || !data.Uuid) && previous.Ssid === data.Ssid && previous.SecurityType === data.SecurityType) return entry.deviceKey;
        }
        return data.Uuid ? "uuid:" + data.Uuid : "ssid:" + JSON.stringify([data.Ssid, data.SecurityType]);
    }
    // Also used by tests with an independently changing source model.
    function refresh() {
        if (!sourceModel) return;
        const snapshot = [];
        const roles = ["Name", "Ssid", "Uuid", "DevicePath", "SpecificPath", "ConnectionPath", "Signal", "SecurityType", "Type", "ItemType", "ConnectionState"];
        for (let i = 0; i < sourceModel.rowCount(); ++i) {
            const data = {};
            const index = sourceModel.index(i, 0);
            for (const role of roles) data[role] = sourceModel.data(index, Network.NetworkModel[role + "Role"]);
            if (data.Type !== Network.Enums.Wireless || data.ItemType === Network.NetworkModelItem.UnavailableConnection || !data.SpecificPath || data.SpecificPath === "/") continue;
            const key = keyFor(data);
            if (snapshot.some(entry => entry.deviceKey === key)) continue;
            snapshot.push({deviceKey: key, payload: data, rank: data.Signal, active: data.ConnectionState === Network.Enums.Activated});
        }
        stable.sync(snapshot);
        for (const entry of snapshot) networkUpdated(entry.deviceKey, entry.payload);
        resolvePassword();
    }
    Connections {
        target: list.sourceModel
        function onDataChanged() { list.scheduleRefresh(); }
        function onRowsInserted() { list.scheduleRefresh(); }
        function onRowsRemoved() { list.scheduleRefresh(); }
        function onRowsMoved() { list.scheduleRefresh(); }
        function onLayoutChanged() { list.scheduleRefresh(); }
        function onModelReset() { list.scheduleRefresh(); }
    }
    function scheduleRefresh() { Qt.callLater(refresh); }
    Component.onCompleted: scheduleRefresh()
    onPageActiveChanged: if (pageActive) { refresh(); stable.openSession(); }
    delegate: WifiRow {
        required property string deviceKey
        required property var payload
        width: list.width
        networkData: payload
        handler: list.handler
        onEditingChanged: {
            if (editing) {
                if (list.editingRow && list.editingRow !== this) list.editingRow.closePassword();
                list.editingRow = this;
            } else if (list.editingRow === this) list.editingRow = null;
        }
        onMenuRequested: (anchor, px, py) => list.menuRequested(networkData, anchor, px, py)
        onSettingsRequested: list.settingsRequested()
    }
}
