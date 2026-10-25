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
