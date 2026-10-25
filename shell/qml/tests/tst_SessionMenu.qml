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
        signal sessionActionCancelled(string action)
        function lockScreen() { operation = "lockScreen"; }
        function suspend() { operation = "suspend"; }
        function hibernate() { operation = "hibernate"; }
        function reboot() { operation = "reboot"; }
        function powerOff() { operation = "powerOff"; }
        function logout() { operation = "logout"; }
    }
    Component { id: factory; SessionMenu { systemBridge: backend; sessionMode: true } }
    Component { id: barFactory; TopBar { width: 600 } }
    Component { id: sessionFactory; Session { screens: []; systemBridge: backend } }
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
                menu.activate(i); tryCompare(backend, "operation", menu.entries[i].action); verify(!menu.visible);
                backend.operation = "";
            }
            menu.open(); menu.activate(5); menu.close(); menu.open();
            compare(menu.confirmingIndex, -1);
            menu.activate(1); compare(backend.operation, "lockScreen");
        }
        function test_sessionActionsDispatchDirectly_data() {
            return [{tag: "logout", action: "logout"}, {tag: "reboot", action: "reboot"}, {tag: "powerOff", action: "powerOff"}];
        }
        function test_sessionActionsDispatchDirectly(data) {
            const menu = createTemporaryObject(factory, fixture);
            menu.open();
            const row = menu.entries.findIndex(e => e.action === data.action);
            menu.activate(row); compare(backend.operation, "");
            menu.activate(row); compare(backend.operation, data.action);
            verify(!menu.visible);
        }
        function test_escapeCancelsConfirmation() {
            const menu = createTemporaryObject(factory, fixture);
            menu.open(); menu.activate(6);
            keyClick(Qt.Key_Escape);
            tryCompare(menu, "visible", false);
            compare(backend.operation, "");
            menu.open(); compare(menu.confirmingIndex, -1);
        }
        function test_ringTogglesMenu() {
            const bar = createTemporaryObject(barFactory, fixture);
            const ring = findChild(bar, "sessionRing");
            mouseClick(ring); tryVerify(() => bar.menu !== null && bar.menu.visible);
            mouseClick(ring); tryCompare(bar, "menuOpen", false);
            compare(backend.operation, "");
        }
        function test_otherActionsDispatchDirectly() {
            const menu = createTemporaryObject(factory, fixture);
            for (const action of ["lockScreen", "suspend", "hibernate"]) {
                menu.dispatch(action); compare(backend.operation, action);
            }
        }
        function test_cancelledActionNotification_data() { return test_sessionActionsDispatchDirectly_data(); }
        function test_cancelledActionNotification(data) {
            const session = createTemporaryObject(sessionFactory, fixture);
            backend.sessionActionCancelled(data.action);
            compare(session.notificationCenter.localEntries.length, 1);
            const entry = session.notificationCenter.localEntries[0];
            verify(entry.title.indexOf("cancelado por una aplicación") >= 0);
            compare(entry.actionNames, []); compare(entry.actionLabels, []);
            compare(backend.operation, "");
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
