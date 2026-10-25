import QtQuick
import QtTest
import Singlr.Shell

Item {
    id: fixture
    Component { id: factory; Session {} }
    ListModel {
        id: tasks
        property int lastRow: -1
        function index(row, column) { return row; }
        function requestNewInstance(row) { lastRow = row; }
    }
    TestCase {
        name: "SessionInput"
        when: windowShown
        property var session
        function init() {
            session = createTemporaryObject(factory, fixture);
            verify(session !== null);
        }
        function cleanup() { session.closeMenus(); }
        function test_applicationsAlwaysOpensAndResetsSearch() {
            const launcher = findChild(session, "sessionLauncher");
            verify(launcher);
            session.showApplications();
            verify(launcher.visible); verify(launcher.applicationsMode); compare(launcher.query, "");
            launcher.query = "terminal";
            session.showApplications();
            verify(launcher.visible); verify(launcher.applicationsMode); compare(launcher.query, "");
            session.toggleLauncher(); verify(!launcher.visible);
        }
        function test_exclusivePanelToggles() {
            const control = findChild(session, "controlCenterWindow");
            const launcher = findChild(session, "sessionLauncher");
            session.toggleNotifications(); verify(session.notificationCenter.historyOpen);
            session.toggleNotifications(); verify(!session.notificationCenter.historyOpen);
            session.showApplications(); session.toggleNotifications();
            verify(session.notificationCenter.historyOpen); verify(!launcher.visible);
            session.toggleControlCenter(); verify(control.visible); verify(!session.notificationCenter.historyOpen);
            session.toggleControlCenter(); verify(!control.visible);
            session.toggleControlCenter(); session.showApplications();
            verify(!control.visible); verify(launcher.applicationsMode); verify(launcher.visible);
        }
        function test_numberedEntryDelegatesToDock() {
            const dock = findChild(session, "sessionDock");
            verify(dock);
            tasks.clear(); tasks.lastRow = -1;
            dock.modelOverride = tasks;
            tasks.append({AppName:"Pinned", IsLauncher:true, HasLauncher:true});
            tryVerify(() => dock.width > 0);
            verify(session.activateDockEntry(1)); compare(tasks.lastRow, 0);
            verify(!session.activateDockEntry(2)); verify(!session.activateDockEntry(10));
            dock.modelOverride = null;
        }
    }
}
