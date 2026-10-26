pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Singlr.Shell

Item {
    id: fixture
    width: 1280; height: 800
    Component { id: factory; Session {} }
    TestCase {
        name: "Screens"; when: windowShown
        function test_dockStateAcrossEmptyInventory_data() {
            return [
                {tag: "floating-visible", mode: "floating", autoHide: false},
                {tag: "fixed-visible", mode: "fixed", autoHide: false},
                {tag: "floating-autohide", mode: "floating", autoHide: true},
                {tag: "fixed-autohide", mode: "fixed", autoHide: true}
            ];
        }
        function test_dockStateAcrossEmptyInventory(data) {
            const session = createTemporaryObject(factory, fixture);
            const screen = session.screens[0];
            const dock = findChild(session, "sessionDock");
            const window = findChild(session, "dockWindow");
            dock.dockMode = data.mode;
            dock.autoHide = data.autoHide;
            dock.keyboardHeld = true;
            dock.reveal();
            session.screens = [];
            wait(0); // Flush queued placement while no screen exists.
            session.screens = [screen];
            wait(0);
            compare(dock.dockMode, data.mode);
            compare(dock.autoHide, data.autoHide);
            compare(dock.shown, true);
            compare(window.visible, true);
            if (data.autoHide) {
                // QtTest delivers pointer events to the chosen native window;
                // moving in the fixture cannot send Leave to this separate one.
                mouseMove(window.contentItem, -100, -100);
                tryCompare(dock, "pointerInside", false);
                dock.keyboardHeld = false;
                tryCompare(dock, "shown", false);
                session.screens = [];
                wait(0);
                session.screens = [screen];
                wait(0);
                compare(dock.shown, false);
                compare(window.visible, false);
                verify(findChild(session, "dockEdgeSurface").item.visible);
                dock.reveal();
                compare(window.visible, true);
            }
        }
        function test_inventoryLifecycleAndLazySurfaces() {
            const session = createTemporaryObject(factory, fixture);
            const inventory = findChild(session, "screenSurfaces");
            const screen = session.screens[0];
            // Qt offscreen exposes one real QScreen. Repeat it to simulate inventory
            // changes without claiming compositor routing to two physical outputs.
            session.screens = [screen, screen];
            compare(inventory.count, 2);
            for (let i = 0; i < inventory.count; ++i) {
                const surfaces = inventory.objectAt(i);
                compare(surfaces.outputScreen, screen);
                const background = findChild(surfaces, "backgroundSurface");
                verify(background.item);
                const wallpaper = findChild(background.item, "wallpaperImage");
                verify(wallpaper);
                compare(wallpaper.sourceSize, Qt.size(Math.ceil(screen.width * screen.devicePixelRatio), Math.ceil(screen.height * screen.devicePixelRatio)));
                compare(findChild(surfaces, "barMenuSurface").active, false);
                compare(findChild(surfaces, "trayMenuSurface").active, false);
                const bar = findChild(surfaces, "screenTopBar");
                bar.menuOpen = true;
                verify(findChild(surfaces, "barMenuSurface").item);
                compare(findChild(surfaces, "barMenuSurface").item.screen.name, screen.name);
                surfaces.closeMenus();
            }
            session.openLauncher(false, screen); compare(session.overlay.screen.name, screen.name);
            session.toggleControlCenterOnScreen(screen); tryVerify(() => session.controlWindow !== null);
            compare(session.controlWindow.screen.name, screen.name);
            session.toggleNotificationsOnScreen(screen); compare(session.notificationsWindow.screen.name, screen.name);
            session.screens = [screen]; compare(inventory.count, 1);
            verify(!session.launcherOpen); verify(!session.controlOpen); verify(!session.notificationCenter.historyOpen);
            compare(inventory.objectAt(1), null);
            session.screens = []; compare(inventory.count, 0);
            session.screens = [screen]; compare(inventory.count, 1); compare(session.effectiveDockScreen, screen);
        }
    }
}
