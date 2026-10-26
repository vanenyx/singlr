import QtQuick
import QtCore
import QtTest
import org.kde.kitemmodels as ItemModels
import Singlr.Ui
import Singlr.Shell

Item {
    id: fixture
    width: 1280; height: 300
    Rectangle { anchors.fill: parent; color: Theme.background }
    Settings {
        id: options
        location: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/t255.ini"
        property string capturePrefix: ""
    }
    ListModel {
        id: apps
        property int lastActivated: -1
    }
    // TasksModel.move(from,to) differs from ListModel.move(from,to,count).
    ItemModels.KSortFilterProxyModel {
        id: tasks
        sourceModel: apps
        property var launcherList: []
        function syncLaunchers() {}
        function move(from, to) { apps.move(from, to, 1); return true; }
        function requestNewInstance(index) { apps.lastActivated = index.row; }
    }
    Dock { id: dock; y: 100; screenWidth: fixture.width; modelOverride: tasks }
    TestCase {
        name: "DockOverflow"; when: windowShown
        function init() {
            fixture.width = 1280;
            apps.clear(); apps.lastActivated = -1;
            dock.dockMode = "floating"; dock.dockHeight = 72; dock.autoHide = false;
            dock.closeMenu();
        }
        function populate(count) {
            for (let i = 0; i < count; ++i)
                apps.append({AppName: "App " + i, AppId: "app" + i, IsLauncher: true, HasLauncher: true, decoration: "utilities-terminal"});
            wait(20);
        }
        function test_overflow_data() {
            const rows = [];
            for (const mode of ["floating", "fixed"]) for (const height of [40, 72])
                rows.push({tag: mode + height, mode: mode, height: height});
            return rows;
        }
        function test_overflow(data) {
            dock.dockMode = data.mode; dock.dockHeight = data.height;
            populate(60);
            verify(dock.width <= fixture.width); verify(dock.overflowing);
            const viewport = findChild(dock, "dockViewport");
            const next = findChild(dock, "dockScrollNext");
            const previous = findChild(dock, "dockScrollPrevious");
            verify(next.visible && next.enabled); verify(!previous.enabled);
            mouseClick(next, next.width / 2, next.height / 2);
            verify(viewport.contentX > 0); verify(previous.enabled);
            dock.scrollBy(100000);
            compare(viewport.contentX, viewport.contentWidth - viewport.width);
            verify(!next.enabled);
            const last = findChild(dock, "dockTask59");
            last.forceActiveFocus(Qt.TabFocusReason);
            verify(last.activeFocus);
            const point = last.mapToItem(viewport, 0, 0);
            verify(point.x >= 0 && point.x + last.width <= viewport.width + 1);
            dock.focusFirst();
            const first = findChild(dock, "dockTask0");
            first.forceActiveFocus(Qt.TabFocusReason);
            compare(viewport.contentX, 0);
            // Same Meta+number mapping, even when some entries are offscreen.
            verify(dock.activateEntry(9)); compare(apps.lastActivated, 8);
        }
        function test_wheelAndReorderAfterScroll() {
            populate(30);
            const viewport = findChild(dock, "dockViewport");
            mouseWheel(viewport, 100, 20, 0, -120);
            verify(viewport.contentX > 0);
            const target = findChild(dock, "dockTask10");
            dock.ensureVisible(target);
            const point = target.mapToItem(dock, target.width / 2, target.height / 2);
            verify(dock.moveAt(0, point));
            compare(apps.get(10).AppId, "app0");
            verify(!dock.moveAt(0, Qt.point(0, 10)));
        }
        function test_resizeAndRemoveApps() {
            populate(30);
            const viewport = findChild(dock, "dockViewport");
            dock.scrollBy(100000); verify(viewport.contentX > 0);
            apps.remove(2, 28);
            tryCompare(dock, "overflowing", false);
            tryCompare(viewport, "contentX", 0);
            verify(!findChild(dock, "dockScrollNext").visible);
            verify(dock.width < fixture.width);
        }
        function test_resizeKeepsKeyboardTargetVisible() {
            populate(30);
            const viewport = findChild(dock, "dockViewport");
            const last = findChild(dock, "dockTask29");
            last.forceActiveFocus(Qt.TabFocusReason);
            fixture.width = 800;
            tryVerify(() => {
                const point = last.mapToItem(viewport, 0, 0);
                return point.x >= 0 && point.x + last.width <= viewport.width + 1;
            });
            verify(dock.width <= 800);
        }
        function test_capture() {
            if (!options.capturePrefix) skip("SINGLR_CAPTURE_T255=1 tools/test-qml.sh [--light]");
            populate(30);
            for (const mode of ["floating", "fixed"]) {
                dock.dockMode = mode; waitForRendering(dock);
                let done = false;
                verify(fixture.grabToImage(result => {
                    verify(result.saveToFile(options.capturePrefix + "-" + mode + ".png")); done = true;
                }));
                tryVerify(() => done);
            }
        }
    }
}
