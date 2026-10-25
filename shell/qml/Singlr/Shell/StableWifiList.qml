pragma ComponentBehavior: Bound
import QtQuick
import org.kde.plasma.networkmanagement as Network

ListView {
    id: list
    required property var handler
    property var sourceModel: null
    property bool pageActive: false
    readonly property alias stableModel: stable
    signal passwordRequested(var data)
    signal menuRequested(var data, var anchor, real px, real py)
    signal networkUpdated(string key, var data)
    signal settingsRequested()
    clip: true
    reuseItems: false
    currentIndex: -1
    model: stable.rows
    add: null; remove: null; displaced: null; move: null; populate: null
    StableDeviceModel { id: stable }
    function keyFor(data) {
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
        onPasswordRequested: list.passwordRequested(networkData)
        onMenuRequested: (anchor, px, py) => list.menuRequested(networkData, anchor, px, py)
        onSettingsRequested: list.settingsRequested()
    }
}
