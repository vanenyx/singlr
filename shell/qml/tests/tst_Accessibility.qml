import QtQuick
import QtQuick.Window
import QtCore
import QtTest
import Singlr.Ui
import Singlr.Shell

Item {
    id: fixture
    width: 900; height: 700
    Settings { id: kde; location: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/kdeglobals"; category: "KDE" }
    property int calls: 0
    ListModel {
        id: results
        property int ran: -1
        function index(row, column) { return row; }
        function run(row) { ran = row; return true; }
    }
    ListModel {
        id: clipboardHistory
        property string copied: ""
        function moveToTop(uuid) { copied = uuid; }
    }
    Component { id: launcherFactory; Launcher { modelOverride: results } }
    Component { id: clipboardFactory; ClipboardPanel { history: clipboardHistory } }
    Component { id: toolFactory; Tool { description: "Abrir ajustes"; onClicked: fixture.calls++ } }
    Component { id: rowFactory; ListItem { title: "Documento"; subtitle: "Carpeta"; onClicked: fixture.calls++ } }
    Component { id: toggleFactory; Toggle { Accessible.name: "Wi-Fi"; onToggled: fixture.calls++ } }
    Component { id: controlFactory; ControlRow { text: "Red"; onClicked: fixture.calls++ } }
    Component { id: iconFactory; Icon {} }
    Component { id: menuFactory; ContextMenu { onTriggered: fixture.calls++ } }
    Component { id: dockFactory; Dock {} }
    Component { id: sessionFactory; Session {} }
    TestCase {
        name: "Accessibility"
        when: windowShown
        function init() { fixture.calls = 0; }
        function test_launcherTabArrowsAndEnter() {
            results.clear(); results.ran = -1;
            results.append({display: "Primera", subtext: "Aplicación", decoration: "", category: "Aplicaciones"});
            results.append({display: "Segunda", subtext: "Aplicación", decoration: "", category: "Aplicaciones"});
            const launcher = createTemporaryObject(launcherFactory, fixture);
            launcher.open();
            const input = findChild(launcher, "launcherInput");
            tryCompare(input, "activeFocus", true);
            compare(input.Accessible.role, Accessible.EditableText);
            verify(input.Accessible.name.length > 0);
            keyClick(Qt.Key_Tab);
            const first = launcher.Window.window.activeFocusItem;
            compare(first.Accessible.name, "Primera, Aplicación");
            keyClick(Qt.Key_Down); compare(launcher.selectedIndex, 1);
            compare(launcher.Window.window.activeFocusItem.Accessible.name, "Segunda, Aplicación");
            keyClick(Qt.Key_Enter); compare(results.ran, 1);
        }
        function test_clipboardRowKeyboardAndContext() {
            clipboardHistory.clear(); clipboardHistory.copied = "";
            clipboardHistory.append({uuid: "a", display: "Texto", type: 2, starred: false, decoration: ""});
            const panel = createTemporaryObject(clipboardFactory, fixture);
            panel.open();
            tryCompare(panel, "resultCount", 1);
            const input = findChild(panel, "clipboardSearch");
            tryCompare(input, "activeFocus", true);
            compare(input.Accessible.name, "Buscar en el portapapeles");
            keyClick(Qt.Key_Tab);
            compare(panel.Window.window.activeFocusItem.Accessible.name, "Texto");
            keyClick(Qt.Key_Menu); tryCompare(panel.menu, "visible", true);
            keyClick(Qt.Key_Escape); verify(!panel.menu.visible);
            keyClick(Qt.Key_Enter); compare(clipboardHistory.copied, "a");
        }
        function test_toolKeyboardAndAssistiveAction() {
            const tool = createTemporaryObject(toolFactory, fixture);
            compare(tool.Accessible.name, "Abrir ajustes");
            compare(tool.Accessible.role, Accessible.Button);
            tool.forceActiveFocus(Qt.TabFocusReason);
            verify(tool.keyboardFocus);
            keyClick(Qt.Key_Enter); compare(fixture.calls, 1);
            keyClick(Qt.Key_Space); compare(fixture.calls, 2);
            tool.Accessible.pressAction(); compare(fixture.calls, 3);
        }
        function test_standardControlsEnter() {
            const toggle = createTemporaryObject(toggleFactory, fixture);
            toggle.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Enter); verify(toggle.checked); compare(fixture.calls, 1);
            keyClick(Qt.Key_Return); verify(!toggle.checked); compare(fixture.calls, 2);
            const row = createTemporaryObject(controlFactory, fixture);
            row.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Enter); compare(fixture.calls, 3);
            keyClick(Qt.Key_Space); compare(fixture.calls, 4);
        }
        function test_rowAndDecorativeGlyph() {
            const row = createTemporaryObject(rowFactory, fixture);
            compare(row.Accessible.name, "Documento, Carpeta");
            compare(row.Accessible.role, Accessible.ListItem);
            row.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Space); compare(fixture.calls, 1);
            row.Accessible.pressAction(); compare(fixture.calls, 2);
            const icon = createTemporaryObject(iconFactory, fixture);
            verify(icon.Accessible.ignored);
            icon.Accessible.name = "Conectando";
            verify(!icon.Accessible.ignored);
            compare(icon.Accessible.role, Accessible.Graphic);
        }
        function test_menuFocusSkipsDisabledAndReturns() {
            const anchor = createTemporaryObject(toolFactory, fixture);
            anchor.forceActiveFocus(Qt.TabFocusReason);
            const menu = createTemporaryObject(menuFactory, fixture, {entries: [
                {label: "Abrir"}, {separatorOnly: true}, {label: "No disponible", enabled: false},
                {label: "Eliminar", destructive: true, confirmation: "Confirmar eliminación"}
            ]});
            menu.showAt(anchor, 0, 30);
            const first = findChild(menu.contentItem, "contextAction0");
            const last = findChild(menu.contentItem, "contextAction3");
            tryCompare(first, "activeFocus", true);
            compare(first.Accessible.name, "Abrir");
            compare(first.Accessible.role, Accessible.MenuItem);
            keyClick(Qt.Key_Tab); compare(menu.currentIndex, 3); verify(last.activeFocus);
            keyClick(Qt.Key_Return); compare(fixture.calls, 0);
            compare(last.Accessible.name, "Confirmar eliminación");
            keyClick(Qt.Key_Backtab); compare(menu.currentIndex, 0); verify(first.activeFocus);
            keyClick(Qt.Key_Escape); tryCompare(anchor, "activeFocus", true);
        }
        function test_dockArrowTraversalAndWrap() {
            const dock = createTemporaryObject(dockFactory, fixture);
            const tasks = Qt.createQmlObject('import QtQuick; ListModel {}', fixture);
            tasks.append({AppName: "Primera", IsLauncher: true});
            tasks.append({AppName: "Segunda", IsLauncher: true});
            dock.modelOverride = tasks;
            dock.focusFirst();
            const first = findChild(dock, "dockTask0");
            const second = findChild(dock, "dockTask1");
            tryCompare(first, "activeFocus", true);
            compare(first.Accessible.name, "Primera"); verify(first.keyboardFocus);
            keyClick(Qt.Key_Right); verify(second.activeFocus);
            keyClick(Qt.Key_Left); verify(first.activeFocus);
            keyClick(Qt.Key_Backtab); verify(!first.activeFocus);
            keyClick(Qt.Key_Tab); verify(first.activeFocus);
            dock.modelOverride = null; tasks.destroy();
        }
        function test_controlAndNotificationInitialFocus() {
            const session = createTemporaryObject(sessionFactory, fixture);
            session.toggleControlCenter();
            tryVerify(() => session.controlWindow !== null);
            tryVerify(() => session.controlPanel.Window.window.activeFocusItem !== session.controlPanel);
            const panel = session.controlPanel;
            // focusFirst must land on an actionable descendant, even without native activation offscreen.
            panel.focusFirst();
            const first = panel.Window.window.activeFocusItem;
            verify(first && first.activeFocusOnTab);
            keyClick(Qt.Key_Escape); verify(!session.controlOpen);
            session.toggleNotifications();
            const dnd = findChild(session.notificationCenter, "notificationDnd");
            tryCompare(dnd, "activeFocus", true);
            compare(dnd.Accessible.name, "No molestar");
            keyClick(Qt.Key_Escape); verify(!session.notificationCenter.historyOpen);
        }
        function test_motionUsesPlatformUnits() {
            console.log("T245 motion enabled=" + Motion.enabled + " duration=" + Motion.duration);
            verify(Motion.duration >= 0);
            if (Number(kde.value("AnimationDurationFactor", 1)) === 0) verify(!Motion.enabled);
            else verify(Motion.enabled);
            if (!Motion.enabled) { compare(Motion.duration, 0); compare(Motion.spinnerDuration, 0); }
        }
    }
}
