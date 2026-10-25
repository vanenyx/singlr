pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Singlr.Ui
import Singlr.Shell
import org.kde.plasma.networkmanagement as Network

Item {
    id: fixture
    width: 360; height: 760
    property int calls: 0
    Component { id: menuFactory; ContextMenu { onTriggered: fixture.calls++ } }
    QtObject {
        id: handler
        signal connectionActivationFailed(string path, string message)
        property string operation: ""
        function removeConnection(path) { operation = "remove:" + path; }
        function deactivateConnection(path, device) { operation = "disconnect:" + path; }
        function activateConnection(path, device, ap) { operation = "connect:" + path; }
    }
    SystemControls { id: testAudio }
    QtObject { id: testNotifications; property bool inhibited: false }
    Component { id: panelFactory; ControlCenter { width: 340; audio: testAudio; notifications: testNotifications; networkActions: handler } }
    QtObject {
        id: pending
        signal finished(var result)
    }
    QtObject {
        id: adapterStub
        function removeDevice(device) { handler.operation = "forgetBluetooth"; return pending; }
    }
    QtObject {
        id: deviceStub
        property bool connected: false
        property var adapter: adapterStub
        function connectToDevice() { handler.operation = "connectBluetooth"; return pending; }
        function disconnectFromDevice() { handler.operation = "disconnectBluetooth"; return pending; }
    }
    TestCase {
        name: "ContextMenu"; when: windowShown
        function init() { fixture.calls = 0; handler.operation = ""; }
        function makeMenu() {
            return createTemporaryObject(menuFactory, fixture, {entries: [
                {label: "Conectar", shortcut: "⏎"},
                {label: "Olvidar red", destructive: true, confirmation: "¿Olvidar red? Pulsa de nuevo"},
                {label: "Ajustes…", separator: true}
            ]});
        }
        function test_doubleConfirmationAndEscape() {
            const menu = makeMenu(); menu.showAt(fixture, 350, 750); wait(30);
            verify(menu.opened); verify(menu.x + menu.width <= fixture.width); verify(menu.y + menu.height <= fixture.height);
            const row = findChild(menu.contentItem, "contextAction1");
            const height = menu.height;
            mouseClick(row); compare(menu.confirmingIndex, 1); compare(fixture.calls, 0); compare(row.height, 28); compare(menu.height, height);
            keyClick(Qt.Key_Escape); wait(20); verify(!menu.visible); compare(menu.confirmingIndex, -1); compare(fixture.calls, 0);
            menu.showAt(fixture, 20, 20); wait(20);
            mouseClick(row); compare(fixture.calls, 0); mouseClick(row); compare(fixture.calls, 1); verify(!menu.visible);
        }
        function test_keyboardAndOutsideClick() {
            const menu = makeMenu(); menu.showAt(fixture, 20, 20); wait(20);
            keyClick(Qt.Key_Up); compare(menu.currentIndex, 2);
            keyClick(Qt.Key_Down); compare(menu.currentIndex, 0);
            keyClick(Qt.Key_Return); compare(fixture.calls, 1); verify(!menu.visible);
            menu.showAt(fixture, 20, 20); wait(20);
            mouseClick(fixture, 320, 700); wait(20); verify(!menu.visible);
        }
        function test_bluetoothActionsAndConfirmation() {
            const panel = createTemporaryObject(panelFactory, fixture);
            wait(60); panel.height = panel.implicitHeight;
            panel.openPage("bluetooth"); wait(150);
            const height = panel.height;
            panel.openDeviceMenu(deviceStub, panel, 20, 40); wait(20);
            const menu = findChild(panel, "controlContextMenu");
            keyClick(Qt.Key_Return); compare(handler.operation, "connectBluetooth");
            panel.openDeviceMenu(deviceStub, panel, 20, 40); wait(20);
            mouseClick(findChild(menu.contentItem, "contextAction1")); compare(handler.operation, "connectBluetooth");
            keyClick(Qt.Key_Escape); compare(handler.operation, "connectBluetooth");
            panel.openDeviceMenu(deviceStub, panel, 20, 40); wait(20);
            mouseClick(findChild(menu.contentItem, "contextAction1")); mouseClick(findChild(menu.contentItem, "contextAction1"));
            compare(handler.operation, "forgetBluetooth"); compare(panel.height, height); compare(panel.page, "bluetooth");
        }
        function test_wifiPanelGeometryAndActions() {
            const panel = createTemporaryObject(panelFactory, fixture);
            wait(60); panel.height = panel.implicitHeight;
            panel.openPage("wifi"); wait(150);
            const height = panel.height;
            const data = {Name:"Test", Ssid:"Test", Uuid:"known", ConnectionPath:"/known", DevicePath:"/device", SpecificPath:"/ap", SecurityType:Network.Enums.Wpa2Psk, ConnectionState:Network.Enums.Activated};
            panel.openNetworkMenu(data, panel, 330, height - 10); wait(20);
            const menu = findChild(panel, "controlContextMenu");
            compare(menu.entries[0].label, "Desconectar"); compare(panel.height, height); compare(panel.implicitHeight, height); compare(panel.page, "wifi");
            mouseClick(findChild(menu.contentItem, "contextAction1")); compare(handler.operation, ""); compare(panel.height, height);
            mouseClick(findChild(menu.contentItem, "contextAction1")); compare(handler.operation, "remove:/known"); compare(panel.page, "wifi");
            panel.openNetworkMenu(data, panel, 330, height - 10); wait(20); keyClick(Qt.Key_Return); compare(handler.operation, "disconnect:/known");
            panel.openNetworkMenu(Object.assign({}, data, {Uuid:""}), panel, 20, 40); wait(20); compare(menu.entries.length, 2);
            keyClick(Qt.Key_Escape); wait(20); compare(panel.page, "wifi"); compare(panel.height, height);
            panel.openNetworkMenu(Object.assign({}, data, {Uuid:"", ConnectionState:Network.Enums.Deactivated}), panel, 20, 40); wait(20);
            keyClick(Qt.Key_Return); wait(150); compare(panel.page, "network"); compare(panel.height, height);
            verify(findChild(panel.navigation.currentItem, "wifiPassword").activeFocus);
        }
    }
}
