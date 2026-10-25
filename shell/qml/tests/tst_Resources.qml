pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Singlr.Shell

Item {
    id: fixture
    width: 800; height: 700
    Component { id: barFactory; TopBar { width: 700 } }
    ListModel { id: noTasks }
    Component { id: dockFactory; Dock { modelOverride: noTasks } }
    Component { id: trayFactory; SystemTray { backend: null; visible: true } }
    Component { id: osdFactory; OnScreenDisplay {} }
    Component { id: notificationFactory; NotificationCenter {} }
    TestCase {
        name: "ResourceLifecycle"
        when: windowShown
        function cycle(owner, loaderName, open, close) {
            const loader = findChild(owner, loaderName);
            verify(loader); verify(!loader.active); compare(loader.item, null);
            loader.releaseDelay = 40;
            open(); verify(loader.active); verify(loader.item);
            close();
            tryCompare(loader, "active", false, 500); compare(loader.item, null);
            open(); verify(loader.active); verify(loader.item);
            close();
        }
        function test_barMenu() {
            const bar = createTemporaryObject(barFactory, fixture);
            cycle(bar, "TopBarMenuLoader", () => bar.menuOpen = true, () => bar.closeMenu());
        }
        function test_dockMenu() {
            const dock = createTemporaryObject(dockFactory, fixture);
            dock.menuEntries = [{label: "Test", enabled: true}];
            cycle(dock, "DockMenuLoader", () => dock.contextRow = 0, () => dock.closeMenu());
        }
        function test_trayMenu() {
            const tray = createTemporaryObject(trayFactory, fixture);
            cycle(tray, "SystemTrayMenuLoader", () => tray.opened = true, () => tray.close());
        }
        function test_osd() {
            const osd = createTemporaryObject(osdFactory, fixture);
            cycle(osd, "osdLoader", () => osd.show("sun", 50), () => osd.showing = false);
        }
        function test_notificationsKeepBackendWithoutViews() {
            const center = createTemporaryObject(notificationFactory, fixture);
            center.popups = [];
            const backend = center.backendObject;
            cycle(center, "notificationHistoryLoader", () => center.historyOpen = true, () => center.historyOpen = false);
            compare(center.backendObject, backend);
            const popupLoader = findChild(center, "notificationPopupLoader");
            popupLoader.releaseDelay = 40;
            tryCompare(popupLoader, "active", false, 500);
            const row = {entry: {id: 55, app: "Test", title: "Test", body: "", time: new Date(), icon: "dialog-information", defaultAction: false, actionNames: [], actionLabels: []}, remaining: -1};
            center.popups = [row]; verify(popupLoader.active);
            center.popups = [];
            tryCompare(popupLoader, "active", false, 500); compare(popupLoader.item, null);
            center.popups = [row]; verify(popupLoader.active);
        }
    }
}
