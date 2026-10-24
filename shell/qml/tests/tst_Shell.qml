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
    TestCase {
        name: "ShellInteraction"; when: windowShown
        SignalSpy { id: closedSpy; target: search; signalName: "closed" }
        SignalSpy { id: activatedSpy; target: tile; signalName: "activated" }
        function init() { search.open(); fakeResults.lastRow = -1; fakeResults.lastAction = -1; fakeResults.succeed = true; closedSpy.clear(); }
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
        function test_dockRoles() {
            verify(!tile.running);
            tile.task = ({AppName:"Terminal", IsWindow:true, IsActive:true, decoration:"utilities-terminal"}); verify(tile.running);
            tile.task = ({AppName:"Grupo", IsGroupParent:true, IsActive:false, decoration:"utilities-terminal"}); verify(tile.running);
            activatedSpy.clear(); tile.forceActiveFocus(); keyClick(Qt.Key_Return); compare(activatedSpy.count,1);
        }
    }
}
