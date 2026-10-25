pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Singlr.Shell

Item {
    id: fixture
    width: 800; height: 600
    ListModel { id: items }
    QtObject {
        id: backend
        property var items: fixture.trayItems
        property string action: ""
        property int calls: 0
        property var nodes: []
        signal menuChanged(string service)
        function menu(service, path) { ++calls; return nodes; }
        function activate(service, path, x, y) { action = "activate:" + path; }
        function secondaryActivate(service, path, x, y) { action = "secondary:" + path; }
        function scroll(service, path, delta, orientation) { action = orientation + ":" + delta; }
        function activateMenuItem(service, path, id) { action = "menu:" + id; }
    }
    QtObject {
        id: asyncBackend
        property var items: fixture.trayItems
        property int calls: 0
        signal menuChanged(string service)
        signal menuReady(string service, string menuPath, var items)
        signal menuFailed(string service, string menuPath, string error)
        function requestMenu(service, path) { ++calls; }
    }
    property var trayItems: items
    Component { id: factory; SystemTray { backend: backend } }
    TestCase {
        name: "SystemTray"; when: windowShown
        function init() {
            items.clear(); backend.action = ""; backend.calls = 0;
            backend.nodes = [{id: 1, label: "Hidden", visible: false},
                {id: 2, label: "Unavailable", enabled: false},
                {id: 3, type: "separator"},
                {id: 4, label: "Options", children: [{id: 5, label: "Checked", toggleType: "checkmark", toggleState: 1}]}];
            for (let i = 0; i < 7; ++i) items.append({service: ":1." + i, path: "/Item" + i,
                menuPath: "/Menu", title: "App " + i, toolTipTitle: "Tip " + i,
                iconName: "application-x-executable", iconSource: "", status: "Active", itemIsMenu: false});
        }
        function test_iconsOverflowAndActions() {
            const tray = createTemporaryObject(factory, fixture); verify(tray);
            compare(tray.itemCount, 7); compare(tray.width, 184);
            verify(findChild(tray, "trayIcon5").visible); verify(!findChild(tray, "trayIcon6").visible);
            const icon = findChild(tray, "trayIcon0");
            mouseClick(icon, 8, 14); compare(backend.action, "activate:/Item0");
            mouseClick(icon, 8, 14, Qt.MiddleButton); compare(backend.action, "secondary:/Item0");
            mouseWheel(icon, 8, 14, 0, 120); compare(backend.action, "vertical:120");
            tray.overflow(tray); compare(tray.entries.length, 1); compare(tray.entries[0].label, "Tip 6");
            tray.run(tray.entries[0]); compare(backend.action, "activate:/Item6"); verify(!tray.opened);
            items.setProperty(6, "itemIsMenu", true); tray.overflow(tray);
            tray.run(tray.entries[0]); tryCompare(backend, "calls", 1);
            compare(tray.selected.path, "/Item6"); tray.close();
            tray.backend = null; compare(tray.width, 0); verify(!tray.visible);
        }
        function test_deferredMenuNavigationInvalidationAndRemoval() {
            const tray = createTemporaryObject(factory, fixture);
            mouseClick(findChild(tray, "trayIcon0"), 8, 14, Qt.RightButton);
            verify(tray.opened); compare(backend.calls, 0); compare(tray.entries[0].label, "…");
            tryCompare(backend, "calls", 1); compare(tray.entries.length, 3);
            const popup = findChild(tray, "trayMenu"); compare(popup.height, 344);
            popup.activate(0); compare(backend.action, ""); verify(tray.opened);
            popup.activate(1); compare(backend.action, "");
            popup.activate(2); verify(tray.opened); compare(tray.entries[0].label, "Atrás");
            compare(tray.entries[1].toggleState, 1); compare(popup.height, 344);
            popup.activate(0); compare(tray.entries.length, 3);
            popup.activate(2); popup.activate(1); compare(backend.action, "menu:5"); verify(!tray.opened);
            tray.openMenu(items.get(0), tray, 0); tryCompare(backend, "calls", 2);
            backend.nodes = []; backend.menuChanged(":1.0"); tryCompare(backend, "calls", 3);
            compare(tray.entries[0].label, "Sin opciones"); compare(popup.height, 344);
            items.remove(0); verify(!tray.opened);
        }
        function test_asyncLoadingLateRepliesAndErrors() {
            asyncBackend.calls = 0;
            const tray = createTemporaryObject(factory, fixture, {backend: asyncBackend});
            tray.openMenu(items.get(0), tray, 0);
            tryCompare(asyncBackend, "calls", 1);
            compare(tray.entries[0].label, "…"); verify(tray.entries[0].enabled === false);
            asyncBackend.menuReady(":1.0", "/Other", backend.nodes);
            compare(tray.entries[0].label, "…");
            tray.openMenu(items.get(1), tray, 0);
            tryCompare(asyncBackend, "calls", 2);
            asyncBackend.menuReady(":1.0", "/Menu", backend.nodes);
            compare(tray.entries[0].label, "…");
            asyncBackend.menuFailed(":1.0", "/Menu", "old failure");
            compare(tray.entries[0].label, "…");
            asyncBackend.menuReady(":1.1", "/Menu", backend.nodes);
            compare(tray.entries.length, 3);
            asyncBackend.menuFailed(":1.1", "/Menu", "failure");
            compare(tray.entries[0].label, "No se pudo cargar el menú");
            verify(tray.entries[0].enabled === false);
            tray.close();
            asyncBackend.menuReady(":1.1", "/Menu", backend.nodes);
            verify(!tray.opened);
        }
        function test_closeCancelsDeferredQuery() {
            const tray = createTemporaryObject(factory, fixture);
            tray.openMenu(items.get(0), tray, 0); tray.close(); wait(100); compare(backend.calls, 0);
        }
    }
}
