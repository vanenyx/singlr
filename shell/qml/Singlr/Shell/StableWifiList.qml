pragma ComponentBehavior: Bound
import QtQuick
import org.kde.plasma.networkmanagement as Network

ListView {
    id: list
    required property var handler
    property var sourceModel: null
    property string suppressedSsid: ""
    property bool secretActive: false
    property bool pageActive: false
    property string editingKey: ""
    property string menuKey: ""
    property bool pointerInside: hover.hovered
    readonly property alias stableModel: stable
    signal settingsRequested()
    implicitHeight: contentHeight
    height: contentHeight
    interactive: false
    reuseItems: false
    currentIndex: -1
    cacheBuffer: 100000
    model: stable.rows
    add: null; remove: null; displaced: null; move: null; populate: null
    HoverHandler { id: hover; acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad }
    StableDeviceModel {
        id: stable
        frozen: list.pointerInside || !!list.editingKey || !!list.menuKey || list.secretActive
    }
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
    onPageActiveChanged: {
        if (pageActive) { refresh(); stable.openSession(); }
        else {
            if (editingKey) { const state = stable.stateFor(editingKey); state.password = ""; state.editing = false; }
            if (menuKey) { const state = stable.stateFor(menuKey); state.menuOpen = false; state.confirmingForget = false; }
            editingKey = ""; menuKey = "";
        }
    }
    delegate: WifiRow {
        required property string deviceKey
        required property var payload
        required property var interaction
        width: list.width
        networkData: payload
        rowState: interaction
        handler: list.handler
        visible: !(list.secretActive && networkData.Ssid === list.suppressedSsid)
        height: visible ? implicitHeight : 0
        editing: list.pageActive && list.editingKey === deviceKey
        onEditRequested: {
            if (list.editingKey && list.editingKey !== deviceKey) stable.stateFor(list.editingKey).password = "";
            list.editingKey = deviceKey;
        }
        onEditFinished: list.editingKey = ""
        onMenuOpenChanged: {
            if (menuOpen) {
                if (list.menuKey && list.menuKey !== deviceKey) stable.stateFor(list.menuKey).menuOpen = false;
                list.menuKey = deviceKey;
            } else if (list.menuKey === deviceKey) list.menuKey = "";
        }
        onSettingsRequested: list.settingsRequested()
    }
}
