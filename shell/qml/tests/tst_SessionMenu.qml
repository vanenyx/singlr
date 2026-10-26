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
        property bool canLock: true
        property bool canLogout: true
        property bool canReboot: true
        property bool canShutdown: true
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
        function init() {
            backend.operation = ""; backend.canSuspend = true; backend.canHibernate = true;
            backend.canLock = true; backend.canLogout = true; backend.canReboot = true; backend.canShutdown = true;
        }
        function test_sessionActionsDispatchDirectly_data() {
            return [{tag: "logout", action: "logout"}, {tag: "reboot", action: "reboot"}, {tag: "powerOff", action: "powerOff"}];
        }
        function test_sessionActionsDispatchDirectly(data) {
            const menu = createTemporaryObject(factory, fixture);
            menu.open();
            const row = menu.entries.findIndex(e => e.action === data.action);
            menu.activate(row); compare(backend.operation, data.action);
            verify(!menu.visible);
        }
        function test_escapeClosesWithoutDispatch() {
            const menu = createTemporaryObject(factory, fixture);
            menu.open();
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
            menu.systemBridge = ({}); menu.open(); compare(menu.entries.length, 1); compare(menu.headerName, "Usuario");
            menu.dispatch("lockScreen"); compare(backend.operation, "");
        }
        function test_otherCapabilities() {
            const menu = createTemporaryObject(factory, fixture);
            backend.canLock = false; backend.canLogout = false; backend.canReboot = false; backend.canShutdown = false;
            menu.open();
            compare(menu.entries.map(e => e.action).join(","), "settings,suspend,hibernate");
        }
        function test_windowedOnlyLogs() {
            const menu = createTemporaryObject(factory, fixture, {sessionMode: false});
            for (const action of ["lockScreen", "suspend", "hibernate", "reboot", "powerOff", "logout", "settings"])
                menu.dispatch(action);
            compare(backend.operation, "");
        }
    }
}
