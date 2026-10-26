pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Singlr.Ui

Item {
    id: fixture
    width: 640; height: 480
    Component { id: factory; Wallpaper {} }
    TestCase {
        name: "WallpaperResources"
        when: windowShown
        function test_optionalEffectAndStillFallback() {
            const wallpaper = createTemporaryObject(factory, fixture, {width: 640, height: 360});
            const loader = findChild(wallpaper, "singularityLoader");
            verify(loader); compare(loader.active, false); compare(loader.item, null);
            wallpaper.source = "singlr:singularity";
            compare(loader.active, false); // Thumbnail/static consumers never start a renderer.
            const still = findChild(wallpaper, "singularityStill");
            tryCompare(still, "status", Image.Ready);
            wallpaper.liveAllowed = true;
            // The software suite must retain a useful still and no native timer.
            compare(wallpaper.liveEffect, false); compare(loader.item, null);
            wallpaper.source = "singlr:linear";
            compare(still.source.toString(), ""); compare(loader.item, null);
        }
        function test_outputSizeIndependentOfWindowConfigure() {
            const wallpaper = createTemporaryObject(factory, fixture, {
                pixelSize: Qt.size(2048, 1280), width: 1, height: 1,
                source: "singlr:graphite"
            });
            const image = findChild(wallpaper, "wallpaperImage");
            verify(image); compare(image.cache, false);
            compare(image.sourceSize, Qt.size(2048, 1280));
            wallpaper.width = 640; wallpaper.height = 480;
            compare(image.sourceSize, Qt.size(2048, 1280));
            wallpaper.pixelSize = Qt.size(3840, 2160);
            compare(image.sourceSize, Qt.size(3840, 2160));
            compare(image.source.toString(), "");
            compare(wallpaper.imageFailed, false);
        }
        function test_waitForValidGeometryAndReleaseSource() {
            const wallpaper = createTemporaryObject(factory, fixture, {
                pixelSize: Qt.size(0, 0), source: "file:///nonexistent-t239.png"
            });
            const image = findChild(wallpaper, "wallpaperImage");
            compare(image.source.toString(), "");
            wallpaper.pixelSize = Qt.size(640, 480);
            tryCompare(wallpaper, "imageFailed", true);
            wallpaper.source = "singlr:light";
            compare(image.source.toString(), "");
            compare(wallpaper.imageFailed, false);
        }
    }
}
