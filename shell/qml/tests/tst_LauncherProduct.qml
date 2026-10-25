import QtQuick
import QtTest
import org.kde.kquickcontrolsaddons as Addons
import Singlr.Shell
Item {
    width: 900; height: 650
    ListModel {
        id: runner
        property int lastRow: -1
        property int lastAction: -1
        function index(row, column) { return row; }
        function run(row) { lastRow = row; return true; }
        function runAction(row, action) { lastRow = row; lastAction = action; return true; }
    }
    QtObject {
        id: dock
        property var pins: []
        function normalizeLauncher(url) { return url; }
        function isPinned(url) { return pins.indexOf(url) >= 0; }
        function setPinned(url, keep) { pins = keep ? pins.concat([url]) : pins.filter(u => u !== url); }
    }
    QtObject { id: bridge; property var shown: []; function showInFolder(urls) { shown = urls; } }
    Addons.Clipboard { id: clipboard }
    Launcher { id: launcher; modelOverride: runner; dockController: dock; systemBridge: bridge }
    TestCase {
        name: "LauncherProduct"; when: windowShown
        function init() {
            runner.clear(); runner.lastRow = -1; runner.lastAction = -1;
            dock.pins = []; bridge.shown = []; launcher.open();
        }
        function cleanup() { launcher.close(); }
        function append(id, title, category, urls, actions) {
            runner.append({id:id, display:title, category:category, url:urls.length ? urls[0] : "", actions:actions, subtext:"", decoration:""});
        }
        function test_calculationAndConversionCopy_data() {
            return [{tag:"calculator", id:"calculator_2+2", result:"4"},
                    {tag:"conversion", id:"unitconverter_10 km", result:"6.21371 mi"}];
        }
        function test_calculationAndConversionCopy(data) {
            append(data.id, data.result, "Resultado", [], []);
            tryCompare(launcher, "primaryAction", "Copiar");
            keyClick(Qt.Key_Return);
            compare(clipboard.content, data.result); compare(runner.lastRow, -1); verify(!launcher.visible);
        }
        function test_fileOpenAndShowInFolder() {
            append("baloosearch_report", "Informe.pdf", "Archivos", ["file:///tmp/Informe.pdf"], []);
            tryCompare(launcher, "resultCount", 1);
            tryVerify(() => launcher.contextEntries.length === 1);
            keyClick(Qt.Key_K, Qt.ControlModifier);
            verify(launcher.actionsOpen); verify(launcher.actionMenu.opened);
            compare(launcher.actionMenu.entries[0].label, "Mostrar en carpeta");
            keyClick(Qt.Key_Return); compare(bridge.shown, ["file:///tmp/Informe.pdf"]);
            verify(!launcher.visible);
            launcher.open(); launcher.focusInput(); keyClick(Qt.Key_Return); compare(runner.lastRow, 0);
        }
        function test_pinFromApplicationsAndSearch_data() { return [{tag:"apps", apps:true}, {tag:"search", apps:false}]; }
        function test_pinFromApplicationsAndSearch(data) {
            launcher.open(data.apps);
            append("services_editor", "Editor", "Aplicaciones", ["applications:org.kde.kate.desktop"], []);
            tryVerify(() => launcher.contextEntries.length === 1);
            launcher.openActions(); verify(launcher.actionMenu.opened);
            compare(launcher.actionMenu.entries[0].label, "Mantener en el dock");
            launcher.actionMenu.activate(0); compare(dock.pins, ["applications:org.kde.kate.desktop"]);
            launcher.openActions(); compare(launcher.actionMenu.entries[0].label, "Quitar del dock");
            launcher.actionMenu.activate(0); compare(dock.pins, []);
        }
        function test_contextMenuDispatchAndRightClick() {
            append("command", "Comando", "Acciones", [], [{text:"Primera", enabled:true}, {text:"Segunda", enabled:true}]);
            tryVerify(() => launcher.selectedResult !== null);
            mouseClick(launcher.selectedResult, 100, 18, Qt.RightButton);
            tryCompare(launcher.actionMenu, "opened", true);
            keyClick(Qt.Key_Down); keyClick(Qt.Key_Return);
            compare(runner.lastRow, 0); compare(runner.lastAction, 1);
        }
        function test_backgroundResultsKeepGeometry() {
            const geometry = [launcher.x, launcher.y, launcher.width, launcher.height];
            for (let i = 0; i < 30; ++i) append("file" + i, "Archivo " + i, "Archivos", ["file:///tmp/a" + i], []);
            tryCompare(launcher, "resultCount", 30);
            compare([launcher.x, launcher.y, launcher.width, launcher.height], geometry);
            launcher.selectedIndex = 29; keyClick(Qt.Key_Return); compare(runner.lastRow, 29);
        }
    }
}
