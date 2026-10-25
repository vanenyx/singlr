pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import org.kde.plasma.networkmanagement as Network
import Singlr.Shell

Item {
    id: fixture
    width: 340; height: 600
    QtObject {
        id: handlerStub
        signal connectionActivationFailed(string path, string message)
        function removeConnection(path) { fixture.removedPath = path; }
    }
    QtObject {
        id: scanModel
        property var entries: []
        signal dataChanged()
        signal rowsInserted()
        signal rowsRemoved()
        signal rowsMoved()
        signal layoutChanged()
        signal modelReset()
        function rowCount() { return entries.length; }
        function index(row, column) { return row; }
        function data(row, roleNumber) {
            const roles = ["Name", "Ssid", "Uuid", "DevicePath", "SpecificPath", "ConnectionPath", "Signal", "SecurityType", "Type", "ItemType", "ConnectionState"];
            for (const role of roles) if (Network.NetworkModel[role + "Role"] === roleNumber) return entries[row].payload[role];
            return undefined;
        }
        function scan(entries) { scanModel.entries = entries; layoutChanged(); dataChanged(); }
    }
    property string removedPath: ""
    SystemControls { id: testAudio }
    QtObject { id: testNotifications; property bool inhibited: false; function setInhibited(value) { inhibited = value; } }
    Component { id: panelFactory; ControlCenter { width: 340; audio: testAudio; notifications: testNotifications; networkSource: scanModel; networkActions: handlerStub } }
    Component { id: listFactory; StableWifiList { width: 308; height: 200; handler: handlerStub; pageActive: true } }
    TestCase {
        name: "StableWifi"; when: windowShown
        function entry(name, signal, uuid = "", active = false) {
            const data = {Name: name, Ssid: name, Uuid: uuid, DevicePath: "/device", SpecificPath: "/ap/" + name,
                ConnectionPath: "/connection/" + name, Signal: signal, SecurityType: Network.Enums.Wpa2Psk,
                Type: Network.Enums.Wireless, ItemType: Network.NetworkModelItem.AvailableAccessPoint,
                ConnectionState: active ? Network.Enums.Activated : Network.Enums.Deactivated};
            return {deviceKey: uuid ? "uuid:" + uuid : "ssid:" + JSON.stringify([name, data.SecurityType]), payload: data, rank: signal, active: active};
        }
        function setupList() {
            const list = createTemporaryObject(listFactory, fixture);
            list.stableModel.sync([entry("A", 90), entry("B", 50, "b"), entry("C", 20)]);
            list.forceLayout(); wait(40);
            return list;
        }
        function test_scanPreservesRowsAndViewport() {
            const list = setupList(); const row = list.itemAtIndex(1);
            const height = list.height;
            for (let i = 0; i < 10; ++i) {
                list.stableModel.sync([entry("B", i, "b"), entry("D", 70), entry("A", 1)]);
                list.forceLayout(); wait(10);
                compare(list.itemAtIndex(1), row); compare(row.height, 36);
                compare(row.networkData.Signal, i); compare(list.height, height);
            }
            list.stableModel.sync([entry("B", 80, "b")]);
            compare(list.height, height); compare(row.height, 36);
        }
        function test_connectionChangesRestoreOpeningOrder() {
            const list = setupList();
            list.stableModel.sync([entry("A", 1), entry("B", 10, "b", true), entry("C", 100)]);
            compare(list.stableModel.rows.get(0).payload.Name, "B");
            list.stableModel.sync([entry("A", 1), entry("B", 10, "b"), entry("C", 100, "", true)]);
            compare(list.stableModel.rows.get(0).payload.Name, "C");
            compare(list.stableModel.rows.get(1).payload.Name, "A");
            compare(list.stableModel.rows.get(2).payload.Name, "B");
        }
        function test_panelHeightAndNavigation() {
            scanModel.entries = [entry("A", 90), entry("B", 50, "b")];
            const panel = createTemporaryObject(panelFactory, fixture);
            wait(80); const height = panel.implicitHeight; panel.height = height;
            panel.openPage("wifi"); wait(150);
            const list = findChild(panel, "wifiList"); list.forceLayout();
            const data = list.stableModel.rows.get(0).payload;
            for (let i = 0; i < 5; ++i) {
                scanModel.scan([entry("B", i, "b"), entry("A", 90-i), entry("New"+i, i)]);
                wait(30); list.forceLayout();
                compare(panel.implicitHeight, height); compare(panel.height, height);
                for (let j = 0; j < list.count; ++j) if (list.itemAtIndex(j)) compare(list.itemAtIndex(j).height, 36);
            }
            panel.openNetworkMenu(data, list, list.width - 10, 40); wait(30);
            const menu = findChild(panel, "controlContextMenu");
            verify(menu.opened); compare(panel.navigation.depth, 2); compare(panel.implicitHeight, height);
            keyClick(Qt.Key_Escape); wait(30); verify(!menu.visible); compare(panel.page, "wifi");
            panel.openNetwork(data, true); wait(150); compare(panel.implicitHeight, height);
            const field = findChild(panel.navigation.currentItem, "wifiPassword"); field.forceActiveFocus(); keyClick(Qt.Key_Escape); wait(150);
            compare(panel.page, "wifi"); compare(panel.navigation.depth, 2);
            panel.forceActiveFocus(); keyClick(Qt.Key_Escape); wait(150); compare(panel.page, "main");
            panel.openPage("bluetooth"); wait(150); compare(panel.implicitHeight, height);
            panel.back(); wait(150); compare(panel.page, "main");
        }
        function test_orderFixedUntilNextOpening() {
            const list = setupList();
            list.stableModel.sync([entry("C", 100), entry("B", 80, "b"), entry("A", 1)]);
            compare(list.stableModel.rows.get(0).payload.Name, "A");
            list.stableModel.openSession();
            compare(list.stableModel.rows.get(0).payload.Name, "C");
        }
    }
}
