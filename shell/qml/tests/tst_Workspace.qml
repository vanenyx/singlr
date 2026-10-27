pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Singlr.Ui
import Singlr.Shell
import Singlr.System

Item {
    id: fixture
    width: 1120; height: 680
    Rectangle { anchors.fill: parent; color: Theme.wallpaperDefault }
    TopBar { anchors.top: parent.top; width: parent.width; activeAppName: "Singlr Workspace" }
    WorkspaceIndicator { x: 210; y: 3; backend: desktops }
    QtObject {
        id: desktops
        property var desktopIds: ["first"]
        property var desktopNames: ["Código", "Lectura"]
        property var currentDesktop: "first"
        function currentDesktopByScreenName(name) { return name === "secondary" ? "second" : currentDesktop; }
    }
    Component { id: indicatorFactory; WorkspaceIndicator { backend: desktops } }
    TestCase {
        name: "Workspace"; when: windowShown
        function init() { desktops.desktopIds = ["first"]; desktops.currentDesktop = "first"; }
        function test_indicatorCountSelectionAndScreen() {
            const indicator = createTemporaryObject(indicatorFactory, fixture);
            verify(!indicator.visible);
            desktops.desktopIds = ["first", "second"];
            verify(indicator.visible); compare(indicator.width, 72);
            compare(indicator.currentDesktop, "first");
            indicator.screenName = "secondary";
            compare(indicator.currentDesktop, "second");
            desktops.desktopIds = [];
            verify(!indicator.visible);
        }
    }
}
