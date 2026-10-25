pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtCore
import QtTest
import org.kde.layershell as LayerShell
import Singlr.Ui
import Singlr.Shell
Item {
    id: fixture
    width: 1280; height: 800
    Settings {
        id: options
        location: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/t254.ini"
        property string capturePrefix: ""
    }
    Rectangle { anchors.fill: parent; color: Theme.background }
    TopBar { width: parent.width; now: new Date(2026, 9, 25, 12, 0); activeAppName: "Archivos" }
    ListModel {
        id: apps
        ListElement { AppName: "Archivos"; IsWindow: true; IsActive: true; decoration: "system-file-manager" }
        ListElement { AppName: "Terminal"; IsWindow: false; IsLauncher: true; decoration: "utilities-terminal" }
        ListElement { AppName: "Navegador"; IsWindow: false; IsLauncher: true; decoration: "firefox" }
    }
    Dock { id: dock; anchors.bottom: parent.bottom; anchors.bottomMargin: bottomMargin; anchors.horizontalCenter: parent.horizontalCenter; screenWidth: fixture.width; modelOverride: apps }
    Component { id: sessionFactory; Session {} }
    TestCase {
        name: "DockSettings"; when: windowShown
        function init() {
            dock.dockMode = "floating"; dock.dockHeight = 48; dock.autoHide = false;
            dock.keyboardHeld = false; dock.launcherHeld = false; dock.edgeHovered = false; dock.dragging = false; dock.fileDragActive = false;
            dock.closeMenu(); dock.revealed = false;
        }
        function cleanup() { DockSettings.setMode("floating"); DockSettings.setHeight(48); DockSettings.setAutoHide(false); }
        function test_geometry_data() {
            const rows = [];
            for (const mode of ["floating", "fixed"]) for (const height of [40,48,56,64,72])
                rows.push({tag: mode + height, mode:mode, height:height});
            return rows;
        }
        function test_geometry(data) {
            dock.dockMode = data.mode; dock.dockHeight = data.height;
            compare(dock.height, data.height);
            compare(dock.bottomMargin, data.mode === "fixed" ? 0 : 4);
            compare(dock.radius, data.mode === "fixed" ? 0 : 14);
            if (data.mode === "fixed") compare(dock.width, fixture.width); else verify(dock.width < fixture.width);
            const tile = findChild(dock, "dockTask0");
            compare(tile.height, data.height); compare(tile.iconSize, Math.round(data.height * 2 / 3));
            compare(tile.width, tile.iconSize);
            compare(dock.exclusionZone, data.height + dock.bottomMargin);
            dock.autoHide = true; compare(dock.exclusionZone, 0);
        }
        function test_visibilityHoldsAndGrace() {
            dock.autoHide = true;
            verify(!dock.shown);
            dock.reveal(); verify(dock.shown);
            dock.keyboardHeld = true; wait(500); verify(dock.shown);
            dock.keyboardHeld = false; verify(dock.shown); tryCompare(dock, "shown", false, 1000);
            for (const hold of ["launcherHeld", "edgeHovered", "dragging", "fileDragActive"]) {
                dock[hold] = true; verify(dock.shown); wait(500); verify(dock.shown);
                dock[hold] = false; tryCompare(dock, "shown", false, 1000);
            }
            dock.contextRow = 0; verify(dock.shown); wait(500); verify(dock.shown);
            dock.closeMenu(); tryCompare(dock, "shown", false, 1000);
            dock.autoHide = false; verify(dock.shown);
        }
        function test_pointerHold() {
            dock.autoHide = true; dock.reveal();
            mouseMove(dock, 10, 10); tryCompare(dock, "pointerInside", true);
            wait(500); verify(dock.shown);
            mouseMove(fixture, 10, 80); tryCompare(dock, "pointerInside", false);
            tryCompare(dock, "shown", false, 1000);
        }
        function test_sessionLiveBindings() {
            const session = createTemporaryObject(sessionFactory, fixture);
            const panel = findChild(session, "sessionDock");
            const surface = findChild(session, "dockWindow");
            const edge = findChild(session, "dockEdgeSurface");
            for (const mode of ["floating", "fixed"]) for (const height of [40,72]) {
                DockSettings.setMode(mode); DockSettings.setHeight(height);
                compare(panel.dockMode, mode); compare(surface.height, height);
                compare(surface.LayerShell.Window.exclusionZone, height + panel.bottomMargin);
                compare(surface.LayerShell.Window.margins.bottom, panel.bottomMargin);
                if (mode === "fixed") compare(surface.width, surface.screen.width);
                DockSettings.setAutoHide(true); verify(edge.active); verify(edge.item);
                compare(edge.item.height, 2); compare(edge.item.screen.name, session.effectiveDockScreen.name);
                compare(surface.LayerShell.Window.exclusionZone, 0);
                session.focusDock(); verify(surface.visible); verify(panel.keyboardHeld);
                session.dockKeyboard = false;
                session.overviewOpen = true; verify(surface.visible);
                session.overviewOpen = false;
                DockSettings.setAutoHide(false); verify(!edge.active); verify(surface.visible);
            }
        }
        function test_capture() {
            if (!options.capturePrefix) skip("SINGLR_CAPTURE_T254=1 tools/test-qml.sh [--light]");
            for (const mode of ["floating", "fixed"]) for (const height of [40,72]) {
                dock.dockMode = mode; dock.dockHeight = height; waitForRendering(dock);
                let done = false;
                verify(fixture.grabToImage(result => { verify(result.saveToFile(options.capturePrefix + "-" + mode + "-" + height + ".png")); done = true; }));
                tryVerify(() => done);
            }
        }
    }
}
