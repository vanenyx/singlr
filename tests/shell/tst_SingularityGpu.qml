pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import QtCore
import Singlr.Ui
Item {
    id: fixture
    width: 1000; height: 640
    Settings { id: kde; location: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/kdeglobals"; category: "KDE" }
    Component { id: factory; Wallpaper {} }
    TestCase {
        name: "SingularityGpuLifecycle"; when: windowShown
        function cleanup() { Appearance.wallpaperAnimated = true; Appearance.wallpaperReactive = true; Appearance.save("wallpaperMotionOverride", false); }
        function test_loadAnimateAndRelease() {
            compare(Motion.enabled, Number(kde.value("AnimationDurationFactor", 1)) > 0);
            const wall = createTemporaryObject(factory, fixture, {width: 1000, height: 640, liveAllowed: true});
            const loader = findChild(wall, "singularityLoader");
            compare(loader.item, null);
            wall.source = "singlr:singularity";
            if (!Motion.enabled) {
                compare(loader.active, false);
                tryCompare(findChild(wall, "singularityStill"), "status", Image.Ready);
                Appearance.save("wallpaperMotionOverride", true);
                compare(Motion.enabled, false);
                kde.sync(); compare(Number(kde.value("AnimationDurationFactor")), 0);
            }
            tryCompare(loader, "status", Loader.Ready);
            verify(loader.item); tryCompare(loader.item, "animating", true);
            wait(100); verify(loader.item.elapsed > 0);
            mouseMove(wall, 850, 100); wait(50);
            verify(loader.item.pointer.x > .8);
            Appearance.wallpaperAnimated = false;
            compare(loader.active, false); compare(loader.item, null);
            tryCompare(findChild(wall, "singularityStill"), "status", Image.Ready);
            Appearance.wallpaperAnimated = true;
            tryCompare(loader, "status", Loader.Ready);
            wall.visible = false;
            compare(loader.item, null);
            wall.visible = true;
            tryCompare(loader, "status", Loader.Ready);
            if (!Motion.enabled) {
                Appearance.wallpaperMotionOverride = false;
                compare(loader.item, null);
                Appearance.wallpaperMotionOverride = true;
                tryCompare(loader, "status", Loader.Ready);
            }
            wall.source = "singlr:graphite";
            compare(loader.item, null); compare(loader.active, false);
        }
    }
}
