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
    Component { id: listFactory; StableWifiList { width: 308; handler: handlerStub; pageActive: true } }
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
            list.pointerInside = false;
            list.stableModel.sync([entry("A", 90), entry("B", 50, "b"), entry("C", 20)]);
            list.forceLayout(); wait(40);
            return list;
        }
        function test_changingSourceEvery100msWhileTyping() {
            const list = setupList();
            scanModel.entries = [entry("A", 90), entry("B", 50, "b"), entry("C", 20)];
            list.sourceModel = scanModel;
            const row = list.itemAtIndex(0);
            verify(row); row.editRequested();
            const field = findChild(row, "wifiPassword");
            field.text = "secret-kept-on-A";
            const key = row.deviceKey;
            for (let i = 0; i < 10; ++i) {
                // Double of an NM scan: order, strength, connection, arrivals and removals change.
                scanModel.scan([entry("C", 99 - i, "", true), entry("B", i, "b"), entry("D", 70), entry("A", i)]);
                wait(100);
                compare(list.itemAtIndex(0), row);
                compare(row.deviceKey, key); compare(field.text, "secret-kept-on-A");
                compare(list.stableModel.rows.count, 3);
                compare(row.networkData.Signal, i);
            }
            row.editFinished(); wait(40); list.forceLayout();
            compare(list.stableModel.rows.get(0).payload.Name, "C");
            compare(list.stableModel.rows.count, 4);
            compare(field.text, "");
        }
        function test_menuAndForgetStayOnKey() {
            const list = setupList(); const row = list.itemAtIndex(1);
            mouseClick(findChild(row, "networkRow"), 60, 18, Qt.RightButton);
            verify(row.menuOpen); wait(40); compare(list.menuKey, "uuid:b");
            mouseClick(findChild(row, "forgetNetwork")); verify(row.confirmingForget);
            list.stableModel.sync([entry("C", 100, "", true), entry("B", 1, "b"), entry("D", 70)]);
            wait(100); compare(list.itemAtIndex(1), row); compare(row.deviceKey, "uuid:b");
            mouseClick(findChild(row, "confirmForget")); compare(fixture.removedPath, "/connection/B");
            wait(30); compare(list.menuKey, ""); compare(list.stableModel.rows.count, 3);
            compare(list.stableModel.indexOf(entry("A", 0).deviceKey), -1);
        }
        function test_hoverDefersStructureButNotSignal() {
            const list = setupList();
            list.pointerInside = true;
            list.stableModel.sync([entry("B", 99, "b", true), entry("D", 10)]);
            compare(list.stableModel.rows.count, 3);
            compare(list.stableModel.rows.get(0).payload.Name, "A");
            compare(list.stableModel.rows.get(1).payload.Signal, 99);
            list.pointerInside = false;
            compare(list.stableModel.rows.count, 2);
            compare(list.stableModel.rows.get(0).deviceKey, "uuid:b");
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
        function test_orderFixedUntilNextOpening() {
            const list = setupList();
            list.stableModel.sync([entry("C", 100), entry("B", 80, "b"), entry("A", 1)]);
            compare(list.stableModel.rows.get(0).payload.Name, "A");
            list.stableModel.openSession();
            compare(list.stableModel.rows.get(0).payload.Name, "C");
        }
    }
}
