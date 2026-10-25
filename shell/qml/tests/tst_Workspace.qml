pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Singlr.Ui
import Singlr.Shell
import Singlr.System
import "../../../session/kwin/tabbox/singlr/contents/ui" as Switcher

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
    ListModel { id: emptyResults }
    Component { id: sessionFactory; Session {} }
    ListModel {
        id: clients
        ListElement { caption: "Singlr — proyecto"; icon: "folder"; windowId: "1" }
        ListElement { caption: "Notas de trabajo"; icon: "text-editor"; windowId: "2" }
        ListElement { caption: "Documentación"; icon: "web-browser"; windowId: "3" }
        ListElement { caption: "Terminal"; icon: "utilities-terminal"; windowId: "4" }
        ListElement { caption: "Calendario"; icon: "office-calendar"; windowId: "5" }
    }
    Component {
        id: switcherFactory
        Switcher.SwitcherView {
            windowModel: clients
            onSelectionRequested: index => selectedIndex = index
            screenGeometry: Qt.rect(0, 0, fixture.width, fixture.height)
            thumbnailComponent: Component {
                Rectangle {
                    color: Theme.panel; border.color: Theme.border; radius: 6
                    Column {
                        anchors.fill: parent; anchors.margins: 12; spacing: 8
                        Repeater {
                            model: 5
                            Rectangle { required property int index; width: 70 + index * 15; height: 4; radius: 2; color: Theme.focusBorder }
                        }
                    }
                }
            }
        }
    }
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
        function test_searchPreservesTextAndOutputFallback() {
            const session = createTemporaryObject(sessionFactory, fixture);
            session.openLauncher();
            session.launcher.modelOverride = emptyResults;
            session.launcher.close();
            WorkspaceBridge.search("cálculo 2+2", "unplugged-output");
            verify(session.launcherOpen);
            compare(session.launcher.query, "cálculo 2+2");
            compare(session.launcherScreen, session.effectiveDockScreen);
            session.launcher.close();
        }
        function test_switcherKeyboardClickGeometryAndCapture() {
            desktops.desktopIds = ["first", "second"];
            const view = createTemporaryObject(switcherFactory, fixture);
            view.x = (fixture.width - view.width) / 2;
            view.y = (fixture.height - view.height) / 2;
            const grid = findChild(view, "switcherGrid");
            verify(grid); compare(grid.count, 5);
            grid.forceActiveFocus();
            keyClick(Qt.Key_Right); compare(view.selectedIndex, 1);
            keyClick(Qt.Key_Left); compare(view.selectedIndex, 0);
            keyClick(Qt.Key_Down); verify(view.selectedIndex > 0);
            view.selectedIndex = 4; compare(grid.currentIndex, 4);
            const width = view.width, height = view.height;
            clients.append({caption: "Otra ventana", icon: "folder", windowId: "6"});
            compare(view.width, width); compare(view.height, height);
            clients.remove(5);
            const spy = createTemporaryQmlObject('import QtTest; SignalSpy {}', fixture);
            spy.target = view; spy.signalName = "activated";
            const cell = grid.itemAtIndex(0); verify(cell);
            mouseClick(cell); compare(spy.count, 1); compare(spy.signalArguments[0][0], 0);
            let captured = false;
            verify(fixture.grabToImage(result => {
                captured = result.saveToFile("/tmp/t246-switcher-" + (Theme.dark ? "dark" : "light") + ".png");
            }));
            tryVerify(() => captured);
        }
    }
}
