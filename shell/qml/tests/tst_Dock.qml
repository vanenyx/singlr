import QtQuick
import QtTest
import org.kde.taskmanager as TaskManager
import Singlr.Shell

Item {
    width: 600; height: 600
    ListModel {
        id: doubleModel
        property var children: []
        property var calls: []
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
            for (const child of children) child.active = child.id === chosen.id;
            chosen.time = ++clock;
            chosen.minimized = false;
            // Reproduce the real regression: the activated child becomes row zero.
            children = [chosen].concat(children.filter(w => w.id !== chosen.id));
            setProperty(0, "IsActive", true);
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
    Dock { id: dock; x: 40; y: 500; modelOverride: doubleModel }
    DockItem { id: focusTile; x: 20; y: 400; task: ({AppName: "Terminal", IsLauncher: true}) }
    Component { id: persistentDock; Dock { visible: false; sessionMode: true } }
    TestCase {
        name: "DockBehaviour"; when: windowShown
        function task() { return doubleModel.get(0); }
        function init() {
            dock.closeMenu(); dock.hideTooltip(); dock.activationHistory = ({}); dock.observedActive = ""; dock.launching = ({});
            doubleModel.clear(); doubleModel.calls = []; doubleModel.activatedId = "";
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
        function test_fourWindowsReorderEveryActivation() {
            const size = [dock.width, dock.height, dock.visible];
            for (let i = 0; i < 3; ++i) {
                doubleModel.calls = [];
                dock.activate(0, task());
                compare(doubleModel.calls, ["activate:10", "activate:30", "activate:40", "activate:20"]);
                compare(doubleModel.activatedId, "20");
                compare([dock.width, dock.height, dock.visible], size);
            }
        }
        function test_inactiveUsesMostRecent() {
            doubleModel.setProperty(0,"IsActive",false);
            doubleModel.children.forEach(w => w.active = false);
            dock.activationHistory = ({"applications:browser.desktop|10":999});
            dock.activate(0, task()); compare(doubleModel.activatedId,"20");
            compare(doubleModel.calls, ["activate:10", "activate:30", "activate:40", "activate:20"]);
        }
        function test_allMinimizedRestoreOnlyRecent() {
            doubleModel.setProperty(0,"IsActive",false);
            doubleModel.children.forEach(w => { w.active = false; w.minimized = true; });
            dock.activate(0, task()); compare(doubleModel.activatedId,"20");
            compare(doubleModel.calls, ["activate:20"]);
            compare(doubleModel.children.filter(w => w.minimized).length,3);
        }
        function test_mixedLeavesMinimizedAlone() {
            doubleModel.children.find(w => w.id === "20").minimized = true;
            doubleModel.children.forEach(w => w.active = false);
            dock.activate(0, task());
            compare(doubleModel.calls, ["activate:10", "activate:30", "activate:40"]);
            verify(doubleModel.children.find(w => w.id === "20").minimized);
        }
        function test_singleActiveNeverMinimizes() {
            doubleModel.children = [{id:"20",active:true,minimized:false,time:8}];
            const single = {AppName:"Browser", IsGroupParent:false, IsActive:true, IsMinimizable:true, WinIdList:["20"]};
            dock.activate(0,single); dock.activate(0,single);
            compare(doubleModel.calls,["activate:20","activate:20"]);
            verify(!doubleModel.children[0].minimized);
        }
        function test_externalActivationFallbackAndRemovedWindow() {
            doubleModel.children.forEach(w => w.time = 0);
            dock.rememberActive();
            doubleModel.children.forEach(w => w.active = w.id === "10");
            dock.rememberActive();
            doubleModel.children.forEach(w => w.active = false);
            doubleModel.setProperty(0,"IsActive",false);
            dock.activate(0,task()); compare(doubleModel.activatedId,"10");
            doubleModel.children = doubleModel.children.filter(w => w.id !== "10");
            doubleModel.children.forEach(w => { w.active = false; w.time = 0; });
            dock.activate(0,task()); compare(doubleModel.activatedId,"20");
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
            compare(dock.menuHeight,236);
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
            const first = persistentDock.createObject(null, {settingsLocation:path}) as Dock;
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
