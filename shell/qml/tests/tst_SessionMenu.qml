pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Singlr.Shell
import org.kde.taskmanager as TaskManager

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
    QtObject {
        id: tasks
        property var rows: []
        property var requested: []
        property int count: rows.length
        signal rowsRemoved()
        function index(row, column) { return row; }
        function data(row, role) {
            const w = rows[row];
            if (role === TaskManager.AbstractTasksModel.IsWindow) return !w.launcher;
            if (role === TaskManager.AbstractTasksModel.IsLauncher) return !!w.launcher;
            if (role === TaskManager.AbstractTasksModel.IsGroupParent) return !!w.group;
            if (role === TaskManager.AbstractTasksModel.WinIdList) return [w.id];
            if (role === TaskManager.AbstractTasksModel.AppName) return w.name;
        }
        function requestClose(row) {
            const w = rows[row];
            requested = requested.concat(w.id);
            if (!w.stays) { rows = rows.filter(r => r.id !== w.id); rowsRemoved(); }
        }
    }
    NotificationCenter { id: notifications; visible: false }
    Component { id: factory; SessionMenu {
        id: testMenu
        systemBridge: backend; sessionMode: true
        closeController: SessionCloseController {
            sessionMode: testMenu.sessionMode; systemBridge: backend
            taskSource: tasks; notificationCenter: notifications
        }
    } }
    Component { id: barFactory; TopBar { width: 600 } }
    TestCase {
        name: "SessionMenu"; when: windowShown
        function init() { tasks.rows = []; tasks.requested = []; notifications.clearAll(); backend.operation = ""; backend.canSuspend = true; backend.canHibernate = true; }
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
        function test_allWindowsClose_data() {
            return [{tag: "logout", action: "logout"}, {tag: "reboot", action: "reboot"}, {tag: "powerOff", action: "powerOff"}];
        }
        function test_allWindowsClose(data) {
            const menu = createTemporaryObject(factory, fixture);
            compare(menu.closeController.timeout, 10000);
            tasks.rows = [{id: 1, name: "Kate"}, {id: 2, name: "Dolphin"},
                {id: 3, launcher: true}, {id: 4, group: true}];
            menu.dispatch(data.action);
            tryCompare(backend, "operation", data.action);
            compare(tasks.requested, [1, 2]);
            verify(!menu.closingApps);
        }
        function test_refusalAndForce_data() { return test_allWindowsClose_data(); }
        function test_refusalAndForce(data) {
            const menu = createTemporaryObject(factory, fixture);
            menu.closeController.timeout = 70;
            tasks.rows = [{id: 1, name: "Kate", stays: true}, {id: 2, name: "Dolphin"}];
            menu.open();
            const height = menu.height;
            const width = menu.width;
            const row = menu.entries.findIndex(e => e.action === data.action);
            menu.activate(row); menu.activate(row);
            backend.canHibernate = false; backend.canSuspend = false;
            verify(menu.closingApps); verify(menu.visible);
            compare(menu.entries[row].label, "Cerrando apps…");
            compare(menu.confirmingIndex, -1); compare(menu.height, height); compare(menu.width, width);
            tryCompare(menu, "closingApps", false);
            compare(menu.height, height);
            compare(backend.operation, "");
            compare(notifications.localEntries.length, 1);
            const entry = notifications.localEntries[0];
            const verb = data.action === "logout" ? "cerrar sesión" : data.action === "reboot" ? "reiniciar" : "apagar";
            compare(entry.title, "No se pudo " + verb + ": Kate tiene cambios sin guardar");
            compare(entry.actionLabels, ["Forzar"]);
            verify(notifications.popups.some(p => p.entry.id === entry.id));
            notifications.dispatch(entry.id, "force");
            compare(backend.operation, data.action);
            notifications.dispatch(entry.id, "force"); // consumed exactly once
            verify(!menu.closingApps);
        }
        function test_escapeCancels() {
            const menu = createTemporaryObject(factory, fixture);
            menu.closeController.timeout = 70;
            tasks.rows = [{id: 1, name: "Kate", stays: true}];
            menu.open(); menu.activate(6); menu.activate(6);
            verify(menu.closingApps);
            keyClick(Qt.Key_Escape);
            tryCompare(menu, "visible", false); verify(!menu.closingApps);
            tasks.rows = []; tasks.rowsRemoved(); wait(100);
            compare(backend.operation, ""); compare(notifications.localEntries.length, 0);
        }
        function test_ringCancels() {
            const owner = createTemporaryObject(factory, fixture);
            owner.closeController.timeout = 70;
            const bar = createTemporaryObject(barFactory, fixture, {closeController: owner.closeController, sessionMode: true});
            const ring = findChild(bar, "sessionRing");
            mouseClick(ring); tryVerify(() => bar.menu !== null && bar.menu.visible);
            tasks.rows = [{id: 1, name: "Kate", stays: true}];
            const row = bar.menu.entries.findIndex(e => e.action === "logout");
            bar.menu.activate(row); bar.menu.activate(row);
            verify(owner.closingApps);
            mouseClick(ring);
            tryCompare(bar, "menuOpen", false);
            verify(!owner.closingApps);
            wait(100); compare(backend.operation, ""); compare(notifications.localEntries.length, 0);
        }
        function test_oldForceCannotExecuteAfterNewAttempt() {
            const menu = createTemporaryObject(factory, fixture);
            menu.closeController.timeout = 30;
            tasks.rows = [{id: 1, name: "Kate", stays: true}];
            menu.dispatch("reboot"); tryCompare(menu, "closingApps", false);
            const id = notifications.localEntries[0].id;
            menu.dispatch("logout");
            notifications.dispatch(id, "force");
            compare(backend.operation, ""); verify(menu.closingApps);
            menu.closeController.cancel();
        }
        function test_delayedCloseObserved() {
            const menu = createTemporaryObject(factory, fixture);
            tasks.rows = [{id: 1, name: "Kate", stays: true}];
            menu.dispatch("logout"); wait(20); compare(backend.operation, "");
            tasks.rows = []; tasks.rowsRemoved();
            tryCompare(backend, "operation", "logout");
        }
        function test_lockAndSuspendDoNotCloseWindows() {
            const menu = createTemporaryObject(factory, fixture);
            tasks.rows = [{id: 1, name: "Kate"}];
            for (const action of ["lockScreen", "suspend", "hibernate"]) {
                menu.dispatch(action); compare(backend.operation, action);
                verify(!menu.closingApps); compare(tasks.requested.length, 0);
            }
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
