pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import org.kde.plasma.networkmanagement as Network
import Singlr.Shell

Item {
    id: fixture
    width: 360; height: 760
    QtObject {
        id: battery
        property int percent: 78
        property double smoothedRemainingMsec: 11100000
    }
    QtObject {
        id: power
        property var profiles: ["power-saver", "balanced", "performance"]
        property string activeProfile: "balanced"
        property string profileError: ""
        function setProfile(key) { activeProfile = key; }
    }
    QtObject {
        id: handler
        property string operation: ""
        property int calls: 0
        signal connectionActivationFailed(string path, string message)
        function activateConnection(path, device, ap) { operation = "activate:" + path; calls++; }
        function addAndActivateConnection(device, ap, password = "") { operation = "add:" + ap + ":" + password; calls++; }
    }
    QtObject { id: pending; signal finished(var result) }
    QtObject {
        id: device
        property string address: "00:01"
        property string friendlyName: "Auriculares"
        property bool connected: false
        property bool paired: true
        function pair() { handler.operation = "pair"; handler.calls++; return pending; }
        function connectToDevice() { handler.operation = "connectBluetooth"; handler.calls++; return pending; }
        function disconnectFromDevice() { handler.operation = "disconnectBluetooth"; handler.calls++; return pending; }
    }
    SystemControls { id: audio }
    QtObject { id: notifications; property bool inhibited: false }
    Component { id: batteryFactory; BatteryRow { width: 308; battery: battery; power: power } }
    Component { id: panelFactory; ControlCenter { width: 340; audio: audio; notifications: notifications; networkActions: handler; networkSource: null; bluetoothDevices: [device] } }
    TestCase {
        name: "MinimumControls"; when: windowShown
        function init() {
            power.activeProfile = "balanced"; power.profiles = ["power-saver", "balanced", "performance"];
            handler.calls = 0; handler.operation = ""; device.paired = true; device.connected = false;
        }
        function test_batteryProfilesGeometryAndKeyboard() {
            const row = createTemporaryObject(batteryFactory, fixture);
            const percent = findChild(row, "batteryPercent");
            compare(percent.font.pixelSize, 13); compare(percent.font.weight, 590);
            const keys = ["power-saver", "balanced", "performance"];
            const tints = ["#4ea7fc", "#f7f8f8", "#eb5757"];
            for (let i = 0; i < keys.length; ++i) {
                const button = findChild(row, "profile-" + keys[i]);
                const circle = findChild(button, "profileCircle");
                compare(circle.width, 12); compare(circle.height, 12); compare(circle.border.width, 1.5);
                compare(circle.border.color, Qt.color(tints[i]));
                button.forceActiveFocus(); keyClick(Qt.Key_Space);
                compare(power.activeProfile, keys[i]); compare(circle.color, Qt.color(tints[i])); compare(row.height, 36);
                for (let j = 0; j < keys.length; ++j) if (j !== i)
                    compare(findChild(findChild(row, "profile-" + keys[j]), "profileCircle").color, Qt.color("transparent"));
            }
            power.profiles = ["balanced"];
            verify(!findChild(row, "profile-performance").enabled);
            mouseClick(findChild(row, "profile-performance")); compare(power.activeProfile, "performance");
        }
        function network(uuid = "", security = Network.Enums.Wpa2Psk) {
            return {Name: "Test", Ssid: "Test", Uuid: uuid, ConnectionPath: "/connection", DevicePath: "/device", SpecificPath: "/ap", Signal: 70,
                SecurityType: security, Type: Network.Enums.Wireless, ItemType: Network.NetworkModelItem.AvailableAccessPoint, ConnectionState: Network.Enums.Deactivated};
        }
        function test_clickAndMenuShareConnectionPath_data() {
            return [{tag: "known", uuid: "known", security: Network.Enums.Wpa2Psk}, {tag: "open", uuid: "", security: Network.Enums.NoneSecurity}, {tag: "password", uuid: "", security: Network.Enums.Wpa2Psk}];
        }
        function test_clickAndMenuShareConnectionPath(data) {
            const panel = createTemporaryObject(panelFactory, fixture);
            wait(60); panel.height = panel.implicitHeight; panel.openPage("wifi"); wait(150);
            const list = panel.wifiView; const n = network(data.uuid, data.security);
            list.stableModel.sync([{deviceKey: "test", payload: n, active: false, rank: 70}]); list.forceLayout();
            const row = list.itemAtIndex(0); const y = row.y;
            mouseClick(findChild(row, "networkRow"));
            const operation = handler.operation;
            const editing = row.editing;
            if (editing) {
                findChild(row, "wifiPassword").text = "password"; keyClick(Qt.Key_Return);
                compare(handler.operation, "add:/ap:password");
            }
            row.closePassword(); row.requested = false; handler.operation = "";
            panel.openNetworkMenu(n, row, 50, 18); wait(20); keyClick(Qt.Key_Return); wait(30);
            compare(row.editing, editing); compare(handler.operation, operation);
            if (editing) {
                findChild(row, "wifiPassword").text = "password"; keyClick(Qt.Key_Return);
                compare(handler.operation, "add:/ap:password");
            }
            compare(row.y, y); compare(row.height, 36);
            verify(row.requested);
        }
        function test_bluetoothClickPairAndMenu() {
            const panel = createTemporaryObject(panelFactory, fixture);
            wait(60); panel.height = panel.implicitHeight; const height = panel.height;
            panel.openPage("bluetooth"); wait(150);
            const row = findChild(panel, "bluetoothDeviceRow"); verify(row);
            mouseClick(row); compare(handler.operation, "connectBluetooth");
            pending.finished({error: false}); device.connected = true;
            wait(120); mouseClick(row); compare(handler.operation, "disconnectBluetooth");
            pending.finished({error: false}); device.connected = false; device.paired = false;
            wait(120); mouseClick(row); compare(handler.operation, "pair");
            pending.finished({error: true, errorText: "No se pudo emparejar"});
            wait(120); verify(row.status.indexOf("emparejar") >= 0);
            panel.openDeviceMenu(device, row, 20, 18); wait(20); keyClick(Qt.Key_Return);
            compare(handler.operation, "pair");
            device.paired = true; pending.finished({error: false});
            compare(handler.operation, "connectBluetooth"); pending.finished({error: false});
            compare(panel.height, height); compare(row.height, 36);
        }
    }
}
