pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import org.kde.plasma.networkmanagement as Network
import Singlr.Ui
import Singlr.Shell

Item {
    id: fixture
    width: 340; height: 400
    QtObject {
        id: networkHandlerStub
        property string operation: ""
        property var args: []
        signal connectionActivationFailed(string path, string message)
        function activateConnection(path, device, ap) { operation = "activate"; args = [path, device, ap]; }
        function addAndActivateConnection(device, ap, password = "") { operation = "add"; args = [device, ap, password]; }
        function removeConnection(path) { operation = "remove"; args = [path]; }
        function deactivateConnection(path, device) { operation = "deactivate"; args = [path, device]; }
    }
    Component {
        id: rowComponent
        WifiRow {
            width: 308
            handler: networkHandlerStub
            onEditRequested: editing = true
            onEditFinished: editing = false
        }
    }
    Component { id: toggleComponent; Toggle { text: "Wi-Fi"; width: 308 } }
    Component { id: sliderComponent; SliderControl { width: 308; from: 0; to: 100; value: 50 } }
    TestCase {
        name: "ControlCenterConnections"; when: windowShown
        function networkFixture(overrides = {}) {
            return Object.assign({Name: "Red de prueba", Ssid: "Test", Uuid: "", DevicePath: "/device/1", SpecificPath: "/ap/1", ConnectionPath: "", Signal: 72,
                SecurityType: Network.Enums.Wpa2Psk, Type: Network.Enums.Wireless,
                ItemType: Network.NetworkModelItem.AvailableAccessPoint, ConnectionState: Network.Enums.Deactivated}, overrides);
        }
        function createRow(overrides = {}) {
            return createTemporaryObject(rowComponent, fixture, {networkData: networkFixture(overrides)});
        }
        function init() { networkHandlerStub.operation = ""; networkHandlerStub.args = []; }
        function test_availableAndSignal() {
            const row = createRow(); verify(row.eligible);
            compare(findChild(row, "networkRow").glyph, "wifi-medium");
            row.networkData = networkFixture({Signal: 15}); compare(findChild(row, "networkRow").glyph, "wifi-none");
            row.networkData = networkFixture({Signal: 35}); compare(findChild(row, "networkRow").glyph, "wifi-low");
            row.networkData = networkFixture({Signal: 90}); compare(findChild(row, "networkRow").glyph, "wifi-high");
            row.networkData = networkFixture({ItemType: Network.NetworkModelItem.UnavailableConnection}); verify(!row.eligible);
            row.networkData = networkFixture({SpecificPath: "/"}); verify(!row.eligible);
        }
        function test_knownAndOpenConnections() {
            const known = createRow({Uuid: "known", ConnectionPath: "/connection/1"});
            mouseClick(findChild(known, "networkRow")); compare(networkHandlerStub.operation, "activate");
            compare(networkHandlerStub.args, ["/connection/1", "/device/1", "/ap/1"]);
            verify(known.requested); verify(findChild(known, "networkRow").busy);
            known.destroy();
            const open = createRow({SecurityType: Network.Enums.NoneSecurity});
            mouseClick(findChild(open, "networkRow")); compare(networkHandlerStub.operation, "add"); compare(networkHandlerStub.args, ["/device/1", "/ap/1", ""]);
        }
        function test_passwordEnterEscapeAndInlineError() {
            const row = createRow(); const button = findChild(row, "networkRow");
            mouseClick(button); verify(row.editing); compare(networkHandlerStub.operation, "");
            const field = findChild(row, "wifiPassword"); verify(field.activeFocus);
            field.text = "example-password";
            keyClick(Qt.Key_Escape); verify(!row.editing); compare(field.text, ""); compare(networkHandlerStub.operation, "");
            mouseClick(button); field.text = "example-password";
            keyClick(Qt.Key_Return); compare(networkHandlerStub.operation, "add"); compare(networkHandlerStub.args[2], "example-password");
            verify(!row.editing); compare(field.text, ""); verify(row.requested);
            networkHandlerStub.connectionActivationFailed("", "Contraseña incorrecta");
            compare(row.failure, "Contraseña incorrecta"); verify(!row.requested); verify(!button.busy);
            mouseClick(button); verify(row.editing);
        }
        function test_activationFailureAndSuccess() {
            const row = createRow({Uuid: "known", ConnectionPath: "/connection/1"});
            mouseClick(findChild(row, "networkRow"));
            row.networkData = networkFixture({Uuid: "known", ConnectionState: Network.Enums.Activating});
            row.networkData = networkFixture({Uuid: "known", ConnectionState: Network.Enums.Deactivated});
            verify(row.failure.length > 0); verify(!row.requested);
            row.networkData = networkFixture({Uuid: "known", ConnectionPath: "/connection/1", ConnectionState: Network.Enums.Activated});
            compare(row.failure, ""); const button = findChild(row, "networkRow"); compare(button.status, "Conectada");
            button.actionTriggered(); verify(row.menuOpen); wait(30);
            mouseClick(findChild(row, "disconnectNetwork")); compare(networkHandlerStub.operation, "deactivate"); compare(networkHandlerStub.args, ["/connection/1", "/device/1"]);
        }
        function test_forgetConfirmationAndRightClick() {
            const row = createRow({Uuid: "known", ConnectionPath: "/connection/1"});
            mouseClick(findChild(row, "networkRow"), 60, 18, Qt.RightButton);
            verify(row.menuOpen); wait(30); compare(networkHandlerStub.operation, "");
            mouseClick(findChild(row, "forgetNetwork")); verify(row.confirmingForget); wait(30);
            compare(networkHandlerStub.operation, "");
            mouseClick(findChild(row, "confirmForget")); compare(networkHandlerStub.operation, "remove");
            compare(networkHandlerStub.args, ["/connection/1"]); verify(!row.menuOpen);
        }
        function test_neutralControlsKeyboard() {
            const toggle = createTemporaryObject(toggleComponent, fixture);
            compare(toggle.indicator.color, Qt.color("#1fffffff"));
            toggle.forceActiveFocus(); keyClick(Qt.Key_Space); verify(toggle.checked); tryCompare(toggle.indicator, "color", Theme.control);
            toggle.checked = false; wait(150); compare(toggle.indicator.color, Qt.color("#1fffffff"));
            toggle.destroy();
            const slider = createTemporaryObject(sliderComponent, fixture);
            slider.forceActiveFocus(); keyClick(Qt.Key_Right); verify(slider.value > 50);
        }
    }
}
