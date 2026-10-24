import QtQuick
import QtTest
import Singlr.Shell
Item {
    width: 1000; height: 700
    ListModel {
        id: fakeResults
        property bool querying: false
        property int lastRow: -1
        property int lastAction: -1
        property bool succeed: true
        function index(row, column) { return row; }
        function run(row) { lastRow = row; return succeed; }
        function runAction(row, action) { lastRow = row; lastAction = action; return succeed; }
        ListElement { display: "Primero"; subtext: "Aplicación"; decoration: "utilities-terminal"; actions: [ListElement { text: "Abrir"; iconSource: "document-open" }, ListElement { text: "Otra acción"; iconSource: "document-open" }] }
        ListElement { display: "Segundo"; subtext: "Archivo"; decoration: "text-plain"; actions: [] }
    }
    Launcher { id: search; visible: false; modelOverride: fakeResults }
    DockItem { id: tile; y: 600; task: ({AppName:"Terminal", IsWindow:false, IsLauncher:true, IsActive:false, decoration:"utilities-terminal"}) }
    ListModel {
        id: fakeTasks
        property string operation: ""
        property int lastRow: -1
        function index(row, column) { return row; }
        function requestActivate(row) { operation = "activate"; lastRow = row; }
        function requestToggleMinimized(row) { operation = "minimize"; lastRow = row; }
        function requestNewInstance(row) { operation = "new"; lastRow = row; }
        function requestClose(row) { operation = "close"; lastRow = row; }
    }
    Dock { id: dock; y: 640; modelOverride: fakeTasks }
    TopBar { id: topbar; activeAppName: dock.activeAppName }
    TestCase {
        name: "ShellInteraction"; when: windowShown
        SignalSpy { id: closedSpy; target: search; signalName: "closed" }
        SignalSpy { id: activatedSpy; target: tile; signalName: "activated" }
        function init() { fakeResults.querying = false; search.open(); fakeResults.lastRow = -1; fakeResults.lastAction = -1; fakeResults.succeed = true; closedSpy.clear(); }
        function cleanup() { search.close(); }
        function test_openClose() {
            verify(search.visible); compare(search.query, "");
            keyClick(Qt.Key_Escape); verify(!search.visible); compare(closedSpy.count,1);
            search.open(); verify(search.visible);
        }
        function test_navigationAndRun() {
            tryCompare(search, "resultCount", 2);
            compare(search.selectedIndex,0); keyClick(Qt.Key_Down); compare(search.selectedIndex,1);
            keyClick(Qt.Key_Down); compare(search.selectedIndex,0); keyClick(Qt.Key_Up); compare(search.selectedIndex,1);
            keyClick(Qt.Key_Return); compare(fakeResults.lastRow,1); verify(!search.visible);
        }
        function test_realActionDispatchContract() {
            tryVerify(() => search.selectedActions.length === 2);
            keyClick(Qt.Key_K, Qt.ControlModifier); verify(search.actionsOpen);
            keyClick(Qt.Key_Down); compare(search.actionIndex,1);
            keyClick(Qt.Key_Return); compare(fakeResults.lastRow,0); compare(fakeResults.lastAction,1); verify(!search.visible);
        }
        function test_escapeActionsFirst() {
            tryVerify(() => search.selectedActions.length === 2);
            keyClick(Qt.Key_K, Qt.ControlModifier); keyClick(Qt.Key_Escape);
            verify(!search.actionsOpen); verify(search.visible);
            keyClick(Qt.Key_Escape); verify(!search.visible);
        }
        function test_noActionsAndFailedRun() {
            search.selectedIndex = 1; search.openActions(); verify(!search.actionsOpen);
            fakeResults.succeed = false; search.run(); verify(search.visible);
        }
        function test_applicationModeAndFocus() {
            search.showApplications(); verify(search.applicationsMode);
            tryCompare(search, "resultCount", 2);
            keyClick(Qt.Key_K, Qt.ControlModifier); verify(!search.actionsOpen);
            search.focusInput(); keyClick(Qt.Key_Down); keyClick(Qt.Key_Return);
            compare(fakeResults.lastRow, 1); verify(!search.visible);
            search.open(); verify(!search.applicationsMode);
            keyClick(Qt.Key_Escape); verify(!search.visible);
        }
        function test_busyAndEmptyMessages() {
            search.query = "missing"; fakeResults.querying = true;
            compare(search.emptyMessage, "Buscando…");
            fakeResults.querying = false; compare(search.emptyMessage, "Sin resultados");
            search.query = ""; compare(search.emptyMessage, "Busca o abre Todas las aplicaciones");
        }
        function test_dockDispatch() {
            dock.activate(2, {IsLauncher: true}); compare(fakeTasks.operation, "new"); compare(fakeTasks.lastRow, 2);
            dock.activate(1, {IsWindow: true, IsActive: false}); compare(fakeTasks.operation, "activate");
            dock.activate(1, {IsWindow: true, IsActive: true, IsMinimizable: true}); compare(fakeTasks.operation, "minimize");
            dock.activate(1, {IsWindow: true, IsActive: true, IsMinimizable: false}); compare(fakeTasks.operation, "activate");
            dock.openContext(3, {IsNewInstanceable: true, IsClosable: true}); verify(dock.menuOpen); compare(dock.height, 48);
            dock.newInstance(); compare(fakeTasks.operation, "new"); compare(fakeTasks.lastRow, 3); verify(!dock.menuOpen);
            dock.openContext(3, {IsClosable: true}); dock.closeTask(); compare(fakeTasks.operation, "close"); verify(!dock.menuOpen);
            dock.openContext(3, {IsLauncher: true}); dock.closeTask(); verify(dock.menuOpen);
            keyClick(Qt.Key_Escape); verify(!dock.menuOpen);
        }
        function test_dockLivePresentation() {
            compare(dock.height, 48); compare(topbar.implicitHeight, 28);
            fakeTasks.append({AppName: "Editor", IsLauncher: false, HasLauncher: false, IsActive: true, IsWindow: true, decoration: "utilities-terminal"});
            fakeTasks.append({AppName: "Archivos", IsLauncher: true, HasLauncher: true, IsActive: false, IsWindow: false, decoration: "system-file-manager"});
            tryCompare(topbar, "activeAppName", "Editor");
            tryCompare(dock, "width", 138);
            fakeTasks.setProperty(0, "IsActive", false);
            fakeTasks.setProperty(1, "IsActive", true);
            tryCompare(topbar, "activeAppName", "Archivos");
            fakeTasks.clear();
            tryCompare(topbar, "activeAppName", "Escritorio");
            compare(dock.height, 48);
        }
        function test_dockRoles() {
            verify(!tile.running);
            tile.task = ({AppName:"Terminal", IsWindow:true, IsActive:true, decoration:"utilities-terminal"}); verify(tile.running);
            tile.task = ({AppName:"Grupo", IsGroupParent:true, IsActive:false, decoration:"utilities-terminal"}); verify(tile.running);
            activatedSpy.clear(); tile.forceActiveFocus(); keyClick(Qt.Key_Return); compare(activatedSpy.count,1);
        }
    }
}
