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
            verify(!findChild(session, "sessionLauncher"));
            session.showApplications();
            const launcher = session.launcher;
            verify(launcher);
            verify(launcher.visible); verify(launcher.applicationsMode); compare(launcher.query, "");
            launcher.query = "terminal";
            session.showApplications();
            verify(launcher.visible); verify(launcher.applicationsMode); compare(launcher.query, "");
            session.toggleLauncher(); verify(!launcher.visible);
        }
        function test_exclusivePanelToggles() {
            session.toggleNotifications(); verify(session.notificationCenter.historyOpen);
            session.toggleNotifications(); verify(!session.notificationCenter.historyOpen);
            session.showApplications(); const launcher = session.launcher;
            session.toggleNotifications();
            verify(session.notificationCenter.historyOpen); verify(!launcher.visible);
            session.toggleControlCenter(); tryVerify(() => session.controlWindow !== null); verify(session.controlWindow.visible); verify(!session.notificationCenter.historyOpen);
            session.toggleControlCenter(); verify(!session.controlOpen); compare(session.controlWindow, null);
            session.toggleControlCenter(); session.showApplications();
            compare(session.controlWindow, null); verify(launcher.applicationsMode); verify(launcher.visible);
        }
        function test_lazyContentReleasedAndRecreated() {
            const launcherLoader = findChild(session, "launcherLoader");
            const controlLoader = findChild(session, "controlLoader");
            verify(!launcherLoader.active); verify(!controlLoader.active);
            session.showApplications(); verify(launcherLoader.active); verify(session.overlay);
            const launcher = session.launcher;
            session.toggleLauncher(); compare(session.overlay, null);
            verify(launcherLoader.active); // short reopen cache, without a native Window
            wait(100);
            session.showApplications(); compare(session.launcher, launcher);
            session.toggleLauncher();
            tryCompare(launcherLoader, "active", false, 3200); compare(launcherLoader.item, null);
            session.showApplications(); verify(launcherLoader.active); verify(session.launcher);
            session.toggleControlCenter(); verify(controlLoader.active); tryVerify(() => session.controlWindow !== null);
            compare(session.controlWindow.height, Math.min(session.controlWindow.screen.height - 64, session.controlPanel.implicitHeight));
            session.toggleControlCenter(); compare(session.controlWindow, null);
            tryCompare(controlLoader, "active", false, 3200); compare(controlLoader.item, null);
            session.toggleControlCenter(); verify(controlLoader.active); tryVerify(() => session.controlWindow !== null);
            compare(session.controlWindow.height, Math.min(session.controlWindow.screen.height - 64, session.controlPanel.implicitHeight));
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
