pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Singlr.Shell

Item {
    id: fixture
    width: 600; height: 500
    QtObject {
        id: backend
        property string userName: "Ada"
        property string userIcon: ""
        property bool canSuspend: true
        property bool canHibernate: true
        property string operation: ""
        function lockScreen() { operation = "lockScreen"; }
        function suspend() { operation = "suspend"; }
        function hibernate() { operation = "hibernate"; }
        function reboot() { operation = "reboot"; }
        function powerOff() { operation = "powerOff"; }
        function logout() { operation = "logout"; }
    }
    Component { id: factory; SessionMenu { systemBridge: backend; sessionMode: true } }
    TestCase {
        name: "SessionMenu"; when: windowShown
        function init() { backend.operation = ""; backend.canSuspend = true; backend.canHibernate = true; }
        function test_destructiveActionsConfirmInPlace() {
            const menu = createTemporaryObject(factory, fixture);
            menu.showAt(fixture, 20, 20); wait(20);
            compare(menu.headerName, "Ada"); compare(menu.entries[1].shortcut, "Meta+L");
            const height = menu.height;
            for (let i = 4; i < 7; ++i) {
                menu.open();
                menu.activate(i); compare(backend.operation, ""); compare(menu.confirmingIndex, i); compare(menu.height, height);
                menu.activate(i); compare(backend.operation, menu.entries[i].action); verify(!menu.visible);
                backend.operation = "";
            }
            menu.open(); menu.activate(5); menu.close(); menu.open();
            compare(menu.confirmingIndex, -1);
            menu.activate(1); compare(backend.operation, "lockScreen");
        }
        function test_capabilitiesAndMissingBridge() {
            const menu = createTemporaryObject(factory, fixture);
            backend.canSuspend = false; backend.canHibernate = false;
            menu.open(); compare(menu.entries.length, 5);
            // Capabilities changing in the background must not resize the open menu.
            const height = menu.height;
            backend.canSuspend = true; compare(menu.height, height); compare(menu.entries.length, 5);
            menu.close(); menu.open(); compare(menu.entries.length, 6); menu.close();
            menu.systemBridge = ({}); menu.open(); compare(menu.entries.length, 5); compare(menu.headerName, "Usuario");
            menu.dispatch("lockScreen"); compare(backend.operation, "");
        }
        function test_windowedOnlyLogs() {
            const menu = createTemporaryObject(factory, fixture, {sessionMode: false});
            for (const action of ["lockScreen", "suspend", "hibernate", "reboot", "powerOff", "logout", "settings"])
                menu.dispatch(action);
            compare(backend.operation, "");
        }
    }
}
