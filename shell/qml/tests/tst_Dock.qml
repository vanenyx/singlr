import QtQuick
import QtTest
import org.kde.taskmanager as TaskManager
import Singlr.Shell

Item {
    id: fixture
    width: 600; height: 600
    ListModel {
        id: doubleModel
        property var launcherList: []
        function requestAddLauncher(url) { launcherList = launcherList.concat([url]); }
        function requestRemoveLauncher(url) { launcherList = launcherList.filter(u => u !== url); }
        function syncLaunchers() { calls.push("sync"); }
        function requestOpenUrls(idx, urls) { calls.push("files:" + idx.row + ":" + urls.join(",")); }
        property var children: []
        property var calls: []
        property bool delayActive: false
        property int clock: 100
        property string activatedId: ""
        function index(row, column) { return {row: row, child: -1}; }
        function makeModelIndex(row, child) { return {row: row, child: child}; }
        function rowCount(parent) { return children.length; }
        function data(index, role) {
            const w = children[index.child];
            if (role === TaskManager.AbstractTasksModel.WinIdList) return [w.id];
            if (role === TaskManager.AbstractTasksModel.IsActive) return w.active;
            if (role === TaskManager.AbstractTasksModel.IsMinimized) return w.minimized;
            if (role === TaskManager.AbstractTasksModel.LastActivated) return w.time || 0;
            if (role === Qt.DisplayRole) return w.title || w.id;
            return undefined;
        }
        function requestActivate(index) {
            const chosen = children[index.child < 0 ? 0 : index.child];
            calls.push("activate:" + chosen.id);
            activatedId = chosen.id;
            if (!delayActive) for (const child of children) child.active = child.id === chosen.id;
            chosen.time = ++clock;
            chosen.minimized = false;
            // Reproduce the real regression: the activated child becomes row zero.
            children = [chosen].concat(children.filter(w => w.id !== chosen.id));
            if (!delayActive) setProperty(0, "IsActive", true);
        }
        function requestToggleMinimized(index) {
            calls.push(children[index.child].id);
            children[index.child].minimized = !children[index.child].minimized;
        }
        function requestNewInstance(index) { calls.push("new"); }
        function requestClose(index) {
            const id = children[index.child < 0 ? 0 : index.child].id;
            calls.push("close:" + id);
            children = children.filter(w => w.id !== id);
        }
    }
    QtObject {
        id: bridge
        property var actions: []
        property var launched: []
        function applicationActions(url) { return actions; }
        function launchApplicationAction(url, name) { launched = [url, name]; return true; }
        property bool overviewAvailable: false
        property string invoked: ""
        function acceptsUrls(url, urls) { return url === "applications:browser.desktop" && urls.every(u => u.endsWith(".txt")); }
        function invokeShortcut(component, action) { invoked = component + ":" + action; }
    }
    Dock { id: dock; x: 40; y: 500; modelOverride: doubleModel }
    DockItem { id: focusTile; x: 20; y: 400; task: ({AppName: "Terminal", IsLauncher: true}) }
    Component { id: persistentDock; Dock { visible: false; sessionMode: true } }
    TestCase {
        name: "DockBehaviour"; when: windowShown
        function task() { return doubleModel.get(0); }
        function init() {
            dock.systemBridge = bridge; bridge.actions = []; bridge.launched = [];
            dock.closeMenu(); dock.hideTooltip(); dock.requestedWindows = ({}); dock.launching = ({});
            doubleModel.delayActive = false; doubleModel.clear(); doubleModel.calls = []; doubleModel.launcherList = []; doubleModel.activatedId = "";
            doubleModel.children = [
                {id:"40", active:false, minimized:false, time:4},
                {id:"20", active:true, minimized:false, time:8},
                {id:"10", active:false, minimized:false, time:1},
                {id:"30", active:false, minimized:false, time:3}
            ];
            doubleModel.append({AppName:"Browser", AppId:"browser", IsGroupParent:true,
                IsActive:true, IsLauncher:false, HasLauncher:false, IsClosable:true, IsNewInstanceable:true,
                LauncherUrlWithoutIcon:"applications:browser.desktop", decoration:""});
        }
        function cleanup() { dock.closeMenu(); dock.hideTooltip(); }
        function test_overviewBridge() {
            dock.systemBridge = bridge;
            const button = findChild(dock, "overviewButton");
            verify(!button.visible);
            bridge.overviewAvailable = true; verify(button.visible);
            button.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Return); compare(bridge.invoked, "kwin:Singlr Overview");
            bridge.overviewAvailable = false; verify(!button.visible);
            dock.systemBridge = null; verify(!button.visible);
        }
        function test_numberedEntrySharesCycle() {
            doubleModel.delayActive = true;
            for (let i = 0; i < 5; ++i) verify(dock.activateEntry(1));
            compare(doubleModel.calls, ["activate:30", "activate:40", "activate:10", "activate:20", "activate:30"]);
        }
        function test_numberedPresentationOrderAndBounds() {
            doubleModel.append({AppName:"Pinned", AppId:"pinned", IsLauncher:true, HasLauncher:true});
            // Shortcuts follow the common manual order of running and pinned apps.
            verify(dock.activateEntry(1)); compare(doubleModel.calls, ["activate:30"]);
            verify(dock.activateEntry(2)); compare(doubleModel.calls, ["activate:30", "new"]);
            for (const n of [0, -1, 3, 9, 10, 1.5, NaN, "1"]) verify(!dock.activateEntry(n));
            compare(doubleModel.calls, ["activate:30", "new"]);
        }
        function test_fileDropUsesAppAndRejectsMixedTypes() {
            dock.systemBridge = bridge;
            verify(dock.acceptsFiles(task(), ["file:///tmp/a.txt"]));
            verify(dock.openFiles(0, task(), ["file:///tmp/a.txt", "file:///tmp/b.txt"]));
            compare(doubleModel.calls, ["files:0:file:///tmp/a.txt,file:///tmp/b.txt"]);
            verify(!dock.openFiles(0, task(), ["file:///tmp/a.txt", "file:///tmp/b.png"]));
            compare(doubleModel.calls.length, 1);
        }
        function test_pinUsesInjectedTasksModel() {
            dock.setPinned("applications:browser.desktop", true);
            verify(dock.isPinned("applications:browser.desktop"));
            compare(dock.pinUrls, ["applications:browser.desktop"]);
            dock.openContext(0, {LauncherUrlWithoutIcon:"applications:browser.desktop", HasLauncher:true});
            dock.togglePin(); compare(doubleModel.launcherList, []);
        }
        function test_pointerReorderAndOutsideNeverRemoves() {
            const panel = createTemporaryObject(persistentDock, fixture, {visible:true, x:100, y:300,
                settingsLocation:"file:///tmp/singlr-t242-drag-" + Date.now() + ".ini"}) as Dock;
            tryCompare(panel, "pinsLoaded", true);
            panel.tasksModel.launcherList = ["applications:org.kde.dolphin.desktop", "applications:systemsettings.desktop"];
            panel.persistPins();
            tryVerify(() => findChild(panel, "dockTask1") !== null);
            tryVerify(() => panel.width > 90);
            waitForRendering(panel);
            const first = findChild(panel, "dockTask0");
            mousePress(first, 16, 20, Qt.LeftButton);
            mouseMove(first, 28, 20, 30);
            mouseMove(panel, 62, 20, 30);
            mouseRelease(panel, 62, 20, Qt.LeftButton);
            tryCompare(panel.tasksModel, "launcherList", ["applications:systemsettings.desktop", "applications:org.kde.dolphin.desktop"]);
            const moved = findChild(panel, "dockTask0");
            mousePress(moved, 16, 20, Qt.LeftButton);
            mouseMove(moved, 16, -70, 30);
            mouseRelease(moved, 16, -70, Qt.LeftButton);
            compare(Array.from(panel.tasksModel.launcherList, String), ["applications:systemsettings.desktop", "applications:org.kde.dolphin.desktop"]);
        }
        function test_nativeManualOrderPersists() {
            const path = "file:///tmp/singlr-t242-order-" + Date.now() + ".ini";
            const first = persistentDock.createObject(fixture, {settingsLocation:path}) as Dock;
            tryCompare(first, "pinsLoaded", true);
            first.tasksModel.launcherList = ["applications:org.kde.dolphin.desktop", "applications:systemsettings.desktop"];
            first.persistPins();
            tryVerify(() => first.width > 90, 1000, "dock width=" + first.width + " launchers=" + first.tasksModel.launcherList);
            verify(first.moveEntry(0, 1));
            compare(Array.from(first.tasksModel.launcherList, String), ["applications:systemsettings.desktop", "applications:org.kde.dolphin.desktop"]);
            const order = first.appOrder.slice();
            first.destroy(); wait(1);
            const second = persistentDock.createObject(null, {settingsLocation:path}) as Dock;
            tryCompare(second, "pinsLoaded", true);
            compare(second.appOrder, order);
            compare(Array.from(second.tasksModel.launcherList, String), order);
            second.destroy();
        }
        function test_fourWindowsReorderEveryActivation() {
            const size = [dock.width, dock.height, dock.visible];
            for (let i = 0; i < 3; ++i) {
                doubleModel.calls = [];
                for (let click = 0; click < 4; ++click) verify(dock.cycleApp("browser"));
                compare(doubleModel.calls, ["activate:30", "activate:40", "activate:10", "activate:20"]);
                compare(doubleModel.activatedId, "20");
                compare([dock.width, dock.height, dock.visible], size);
            }
            verify(!dock.cycleApp("missing"));
        }
        function test_inactiveUsesMostRecent() {
            doubleModel.setProperty(0,"IsActive",false);
            doubleModel.children.forEach(w => w.active = false);
            dock.cycleApp("browser"); compare(doubleModel.activatedId,"20");
            compare(doubleModel.calls, ["activate:20"]);
        }
        function test_inactiveWithoutDatesUsesFirstChild() {
            doubleModel.setProperty(0,"IsActive",false);
            doubleModel.children.forEach(w => { w.active = false; w.time = 0; });
            dock.cycleApp("browser");
            compare(doubleModel.calls, ["activate:40"]);
        }
        function test_allMinimizedRestoreOnlyRecent() {
            doubleModel.setProperty(0,"IsActive",false);
            doubleModel.children.forEach(w => { w.active = false; w.minimized = true; });
            dock.cycleApp("browser"); compare(doubleModel.activatedId,"20");
            compare(doubleModel.calls, ["activate:20"]);
            compare(doubleModel.children.filter(w => w.minimized).length,3);
        }
        function test_recentMinimizedWindowIsRestored() {
            doubleModel.setProperty(0,"IsActive",false);
            doubleModel.children.find(w => w.id === "20").minimized = true;
            doubleModel.children.forEach(w => w.active = false);
            dock.activate(0, task());
            compare(doubleModel.calls, ["activate:20"]);
            verify(!doubleModel.children.find(w => w.id === "20").minimized);
        }
        function test_singleActiveNeverMinimizes() {
            doubleModel.children = [{id:"20",active:true,minimized:false,time:8}];
            const single = {AppName:"Browser", IsGroupParent:false, IsActive:true, IsMinimizable:true, WinIdList:["20"]};
            dock.activate(0,single); dock.activate(0,single);
            compare(doubleModel.calls,[]);
            verify(!doubleModel.children[0].minimized);
            dock.cycleApp("browser"); compare(doubleModel.calls,[]);
        }
        function test_rapidClicksWithDelayedActiveAndReordering() {
            doubleModel.delayActive = true;
            for (let i = 0; i < 8; ++i) dock.cycleApp("browser");
            compare(doubleModel.calls, ["activate:30", "activate:40", "activate:10", "activate:20",
                                        "activate:30", "activate:40", "activate:10", "activate:20"]);
        }
        function test_rapidClicksFromInactiveApp() {
            doubleModel.delayActive = true;
            doubleModel.setProperty(0,"IsActive",false);
            doubleModel.children.forEach(w => w.active = false);
            for (let i = 0; i < 3; ++i) dock.cycleApp("browser");
            compare(doubleModel.calls, ["activate:20", "activate:30", "activate:40"]);
        }
        function test_acknowledgementThenExternalActivation() {
            doubleModel.delayActive = true;
            dock.cycleApp("browser"); // Requests 30 while IsActive still says 20.
            doubleModel.children.forEach(w => w.active = w.id === "30");
            dock.reconcileRequests();
            doubleModel.children.forEach(w => w.active = w.id === "10");
            dock.cycleApp("browser");
            compare(doubleModel.calls,["activate:30","activate:20"]);
        }
        function test_removedPendingWindowAndGroupBecomesSingle() {
            doubleModel.delayActive = true;
            dock.cycleApp("browser");
            doubleModel.children = doubleModel.children.filter(w => w.id !== "30");
            dock.cycleApp("browser");
            compare(doubleModel.calls,["activate:30","activate:40"]);
            doubleModel.children = [{id:"20",active:true,minimized:false,time:8}];
            dock.cycleApp("browser");
            compare(doubleModel.calls,["activate:30","activate:40"]);
        }
        function test_waylandUuidLexicalOrder() {
            doubleModel.delayActive = true;
            doubleModel.children = [
                {id:"{e0000000-0000-0000-0000-000000000001}",active:false},
                {id:"{a0000000-0000-0000-0000-000000000001}",active:true},
                {id:"{c0000000-0000-0000-0000-000000000001}",active:false}
            ];
            for (let i = 0; i < 3; ++i) dock.cycleApp("browser");
            compare(doubleModel.calls,["activate:{c0000000-0000-0000-0000-000000000001}",
                                       "activate:{e0000000-0000-0000-0000-000000000001}",
                                       "activate:{a0000000-0000-0000-0000-000000000001}"]);
        }
        function test_desktopActionsWithoutNewInstanceCapability() {
            bridge.actions = [{name:"new-window", text:"Nueva ventana", iconName:"window-new"},
                              {name:"new-private-window", text:"Incógnito", iconName:""}];
            doubleModel.setProperty(0, "IsNewInstanceable", false);
            dock.openContext(0, task());
            compare(dock.menuEntries.filter(e => e.action === "application").length, 2);
            verify(!dock.menuEntries.some(e => e.action === "new"));
            compare(dock.menuEntries[4].iconName, "window-new");
            verify(dock.menuEntries[4].separator); verify(dock.menuEntries[6].separator);
            dock.runMenu(5);
            compare(bridge.launched, ["applications:browser.desktop", "new-private-window"]);
            compare(doubleModel.calls, []); verify(!dock.menuOpen);
        }
        function test_genericNewWindowFallback() {
            bridge.actions = [{name:"new-window", text:"Nouvelle fenêtre", iconName:""}];
            dock.openContext(0, task());
            verify(!dock.menuEntries.some(e => e.action === "new"));
            bridge.actions = [{name:"preferences", text:"Preferencias", iconName:""}];
            dock.openContext(0, task());
            dock.runMenu(dock.menuEntries.findIndex(e => e.action === "new"));
            compare(doubleModel.calls, ["new"]);
            doubleModel.setProperty(0, "IsNewInstanceable", false);
            doubleModel.setProperty(0, "IsLauncher", true);
            dock.openContext(0, task());
            verify(!dock.menuEntries.some(e => e.action === "new"));
            verify(dock.menuEntries.every(e => e.enabled));
            verify(!dock.menuEntries.some(e => e.action === "close"));
        }
        function test_quitClosesAllWindows() {
            dock.openContext(0,task());
            compare(dock.menuEntries.map(e => e.label).slice(-3),["Nueva ventana","Fijar en el dock","Salir"]);
            verify(dock.menuEntries[4].separator); verify(dock.menuEntries[6].separator);
            verify(dock.menuEntries.find(e => e.id === "20").active);
            dock.runMenu(6);
            compare(doubleModel.calls,["close:10","close:20","close:30","close:40"]);
            verify(!dock.menuOpen);
        }
        function test_menuKeyboardAndWindowSelection() {
            dock.openContext(0, task());
            compare(dock.contextWindows.length,4); compare(dock.menuEntries.length,7);
            compare(dock.menuHeight,231);
            wait(1); keyClick(Qt.Key_Down); compare(dock.menuIndex,1);
            keyClick(Qt.Key_Return); compare(doubleModel.activatedId,"20"); verify(!dock.menuOpen);
            dock.openContext(0, task()); wait(1); keyClick(Qt.Key_Escape); verify(!dock.menuOpen);
        }
        function test_launchTimeoutAndWindowArrival() {
            doubleModel.setProperty(0,"IsLauncher",true);
            dock.activate(0, task()); compare(doubleModel.calls[0],"new");
            verify(Object.keys(dock.launching).length === 1);
            dock.launching = ({"applications:browser.desktop":Date.now()-10001});
            tryVerify(() => Object.keys(dock.launching).length === 0,1000);
            dock.activate(0, task()); doubleModel.setProperty(0,"IsLauncher",false);
            tryVerify(() => Object.keys(dock.launching).length === 0,1000);
        }
        function test_tooltipDelayWarmAndDismiss() {
            dock.tooltipWarm = false;
            dock.showTooltip("Browser",50); compare(dock.tooltipText, "");
            wait(200); compare(dock.tooltipText, "");
            tryCompare(dock,"tooltipText","Browser",600);
            dock.showTooltip("",0); dock.showTooltip("Terminal",90);
            compare(dock.tooltipText,"Terminal");
            dock.openContext(0,task()); compare(dock.tooltipText, "");
            dock.showTooltip("Browser",50); compare(dock.tooltipText, "");
        }
        function test_pinsPersistAndRemoveWithoutKdeConfiguration() {
            const path = "file:///tmp/singlr-t208-pins-" + Date.now() + ".json";
            const first = persistentDock.createObject(fixture, {settingsLocation:path}) as Dock;
            verify(first !== null); tryCompare(first,"pinsLoaded",true);
            const app = {AppName:"Archivos", LauncherUrlWithoutIcon:"applications:org.kde.dolphin.desktop", IsLauncher:false, HasLauncher:false};
            first.openContext(0,app); first.togglePin();
            const saved = Array.from(first.tasksModel.launcherList, String);
            verify(saved.indexOf(app.LauncherUrlWithoutIcon) >= 0);
            first.destroy(); wait(1);
            const second = persistentDock.createObject(null, {settingsLocation:path}) as Dock;
            tryCompare(second,"pinsLoaded",true);
            compare(Array.from(second.tasksModel.launcherList, String),saved);
            app.HasLauncher = true;
            second.openContext(0,app); second.togglePin();
            verify(Array.from(second.tasksModel.launcherList, String).indexOf(app.LauncherUrlWithoutIcon) < 0);
            second.destroy(); wait(1);
            const third = persistentDock.createObject(null, {settingsLocation:path}) as Dock;
            tryCompare(third,"pinsLoaded",true);
            verify(Array.from(third.tasksModel.launcherList, String).indexOf(app.LauncherUrlWithoutIcon) < 0);
            third.destroy();
        }
        SignalSpy { id: middleSpy; target: focusTile; signalName: "newInstanceRequested" }
        SignalSpy { id: activateSpy; target: focusTile; signalName: "activated" }
        function test_pointerMiddleAndWheel() {
            middleSpy.clear(); activateSpy.clear();
            mouseClick(focusTile,16,20,Qt.MiddleButton); compare(middleSpy.count,1);
            focusTile.task = ({AppName:"Browser", IsGroupParent:true, WinIdList:["a","b","c","d"]});
            mouseWheel(focusTile,16,20,0,120);
            mouseWheel(focusTile,16,20,0,-120);
            compare(activateSpy.count,0); compare(middleSpy.count,1);
            focusTile.task = ({AppName:"Terminal", IsLauncher:true});
        }
        function test_focusOnlyFromTab() {
            focusTile.forceActiveFocus(Qt.TabFocusReason); verify(focusTile.keyboardFocus);
            mouseClick(focusTile,16,20); verify(!focusTile.keyboardFocus);
        }
    }
}
