pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Effects
import QtCore
import "DockLogic.js" as DockLogic
import Qt.labs.folderlistmodel
import org.kde.taskmanager as TaskManager
import Singlr.Ui
Rectangle {
    id: dock
    readonly property var dockMenu: dockMenuLoader.item
    property bool sessionMode: false
    // Available only when the session bridge confirms the loaded effect.
    // qmllint disable unqualified
    property var systemBridge: typeof SinglrSystem !== "undefined" ? SinglrSystem : null
    // qmllint enable unqualified
    readonly property bool overviewAvailable: !!systemBridge && systemBridge.overviewAvailable === true && typeof systemBridge.invokeShortcut === "function"
    property Item menuHost: null
    property string tooltipText: ""
    property real tooltipCenter: 0
    property string pendingTooltip: ""
    property bool tooltipWarm: false
    function showTooltip(text, center) {
        tooltipDelay.stop(); tooltipReset.stop(); tooltipCenter = center;
        pendingTooltip = menuOpen ? "" : text;
        tooltipText = "";
        if (!pendingTooltip) { tooltipReset.restart(); return; }
        if (tooltipWarm) tooltipText = pendingTooltip;
        else tooltipDelay.restart();
    }
    function hideTooltip() { tooltipDelay.stop(); pendingTooltip = ""; tooltipText = ""; }
    Timer { id: tooltipDelay; interval: 400; onTriggered: { dock.tooltipWarm = true; dock.tooltipText = dock.pendingTooltip; } }
    Timer { id: tooltipReset; interval: 150; onTriggered: dock.tooltipWarm = false }
    signal launcherRequested()
    signal applicationsRequested()
    property int contextRow: -1
    readonly property bool menuOpen: contextRow >= 0
    property var contextTask: null
    property var contextWindows: []
    property var menuEntries: []
    readonly property int menuIndex: dockMenu ? dockMenu.currentIndex : 0
    readonly property int menuHeight: 8 + menuEntries.reduce((sum, entry) => sum + 28 + (entry.separator ? 9 : 0), 0)
    property var modelOverride: null
    readonly property var taskSource: modelOverride || tasks
    property alias tasksModel: tasks
    // Only window identities survive child reordering and delayed IsActive updates.
    property var requestedWindows: ({})
    property var launching: ({})
    readonly property var candidates: ["org.kde.dolphin.desktop", "org.kde.konsole.desktop", "firefox.desktop", "org.kde.kate.desktop", "systemsettings.desktop"]
    property var pinUrls: []
    property var appOrder: []
    property bool restoringOrder: false
    property url settingsLocation: "file://" + StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/singlr/dock.json"
    readonly property var pinStore: pinSettings.item
    readonly property bool pinsLoaded: pinSettings.status === Loader.Ready
    // Settings uses QSettings/INI, even with the requested dock.json filename.
    Loader {
        active: dock.sessionMode && !dock.modelOverride
        sourceComponent: Component {
            Settings {
                location: dock.settingsLocation
                property string pins: ""
                property string order: "[]"
                Component.onCompleted: {
                    try { dock.appOrder = JSON.parse(order); } catch (e) { dock.appOrder = []; }
                    if (pins) {
                        try { dock.pinUrls = JSON.parse(pins); tasks.launcherList = dock.pinUrls; }
                        catch (e) { console.warn("Dock: lista de fijados inválida", e); }
                    } else dock.refreshPins();
                    Qt.callLater(dock.restoreOrder);
                }
            }
        }
        id: pinSettings
    }
    function refreshPins() {
        if (pinStore && pinStore.pins) return;
        let found = [];
        for (let i = 0; i < applications.count; ++i) found.push(applications.get(i, "fileName"));
        pinUrls = candidates.filter(n => found.indexOf(n) >= 0).map(n => "applications:" + n);
        tasks.launcherList = pinUrls;
    }
    function appKey(task) { return String(task?.LauncherUrlWithoutIcon || task?.LauncherUrl || task?.AppId || task?.AppName || "app"); }
    function windows(row, task) {
        const result = [];
        if (task.IsLauncher) return result;
        if (!task.IsGroupParent) {
            return [{id: DockLogic.identity(task.WinIdList), title: String(task.display || task.AppName || "Ventana"),
                active: !!task.IsActive, minimized: !!task.IsMinimized, lastActivated: Number(task.LastActivated) || 0}];
        }
        const parentIndex = taskSource.index(row, 0);
        for (let i = 0; i < taskSource.rowCount(parentIndex); ++i) {
            const idx = taskSource.makeModelIndex(row, i);
            const read = role => taskSource.data(idx, role);
            result.push({id: DockLogic.identity(read(TaskManager.AbstractTasksModel.WinIdList)),
                title: String(read(Qt.DisplayRole) || task.AppName || "Ventana"),
                active: !!read(TaskManager.AbstractTasksModel.IsActive), minimized: !!read(TaskManager.AbstractTasksModel.IsMinimized),
                lastActivated: TaskManager.AbstractTasksModel.LastActivated !== undefined ? Number(read(TaskManager.AbstractTasksModel.LastActivated)) || 0 : 0});
        }
        return result;
    }
    function windowIndex(row, task, id) {
        if (!task.IsGroupParent) return taskSource.index(row, 0);
        const parentIndex = taskSource.index(row, 0);
        for (let i = 0; i < taskSource.rowCount(parentIndex); ++i) {
            const idx = taskSource.makeModelIndex(row, i);
            if (DockLogic.identity(taskSource.data(idx, TaskManager.AbstractTasksModel.WinIdList)) === id) return idx;
        }
        return null;
    }
    function activateWindow(row, task, id) {
        const idx = windowIndex(row, task, id);
        if (idx === null) return;
        requestedWindows[appKey(task)] = id;
        taskSource.requestActivate(idx);
    }
    function closeMenu() { contextRow = -1; }
    function openContext(row, task) {
        hideTooltip(); contextTask = task;
        contextWindows = DockLogic.ordered(windows(row, task));
        menuEntries = contextWindows.map(w => ({label: w.title, id: w.id, action: "window", active: w.active, enabled: true})).concat([
        {label: "Nueva ventana", icon: "plus", shortcut: "⏎", action: "new", separator: contextWindows.length > 0, enabled: !!(task.IsLauncher || task.IsNewInstanceable)},
        {label: task.IsLauncher || task.HasLauncher ? "Quitar del dock" : "Fijar en el dock", icon: "push-pin", action: "pin", enabled: !!(task.LauncherUrlWithoutIcon || task.LauncherUrl)},
        {label: "Salir", icon: "x", action: "close", separator: true, enabled: !!task.IsClosable && contextWindows.length > 0}
        ]);
        contextRow = row;
        Qt.callLater(() => dockMenu.contentItem.forceActiveFocus());
    }
    function runMenu(index) {
        const entry = menuEntries[index];
        if (!entry || !entry.enabled) return;
        if (entry.action === "window") { activateWindow(contextRow, contextTask, entry.id); closeMenu(); }
        else if (entry.action === "new") newInstance();
        else if (entry.action === "close") closeTask();
        else togglePin();
    }
    function persistPins() {
        pinUrls = Array.from(taskSource.launcherList || [], String);
        if (pinStore) { pinStore.pins = JSON.stringify(pinUrls); pinStore.sync(); }
    }
    function normalizeLauncher(url) {
        return systemBridge && typeof systemBridge.launcherUrl === "function" ? String(systemBridge.launcherUrl(url)) : String(url);
    }
    function isPinned(url) { return Array.from(taskSource.launcherList || [], String).indexOf(String(url)) >= 0; }
    function setPinned(url, keep) {
        url = normalizeLauncher(url);
        if (!url) return;
        if (keep) taskSource.requestAddLauncher(url);
        else taskSource.requestRemoveLauncher(url);
        persistPins();
    }
    function togglePin() {
        const url = String(contextTask.LauncherUrlWithoutIcon || contextTask.LauncherUrl || "");
        setPinned(url, !(contextTask.IsLauncher || contextTask.HasLauncher));
        closeMenu();
    }
    function saveOrder() {
        let order = [];
        for (let row = 0; row < pinned.count; ++row) {
            const item = pinned.itemAt(row) as TaskEntry;
            if (item) order.push(appKey(item.model));
        }
        appOrder = order;
        if (pinStore) { pinStore.order = JSON.stringify(order); pinStore.sync(); }
    }
    function moveAt(from, position) {
        if (position.y < 0 || position.y >= height) return false;
        for (let row = 0; row < pinned.count; ++row) {
            const item = pinned.itemAt(row) as TaskEntry;
            if (!item) continue;
            const point = item.mapFromItem(dock, position.x, position.y);
            if (point.x >= 0 && point.x < item.width) return moveEntry(from, row);
        }
        return false;
    }
    function moveEntry(from, to) {
        if (from === to || from < 0 || to < 0 || from >= pinned.count || to >= pinned.count) return false;
        closeMenu(); hideTooltip();
        if (taskSource.move(from, to) === false) return false;
        taskSource.syncLaunchers();
        persistPins(); saveOrder();
        return true;
    }
    function restoreOrder() {
        if (restoringOrder || !appOrder.length || !taskSource.move) return;
        restoringOrder = true;
        let target = 0;
        for (const key of appOrder) {
            for (let row = target; row < pinned.count; ++row) {
                const item = pinned.itemAt(row) as TaskEntry;
                if (item && appKey(item.model) === key) {
                    if (row !== target) taskSource.move(row, target);
                    ++target; break;
                }
            }
        }
        if (taskSource.syncLaunchers) taskSource.syncLaunchers();
        restoringOrder = false;
    }
    function acceptsFiles(task, urls) {
        return !!systemBridge && typeof systemBridge.acceptsUrls === "function"
            && systemBridge.acceptsUrls(String(task.LauncherUrlWithoutIcon || task.LauncherUrl || ""), urls);
    }
    function openFiles(row, task, urls) {
        if (!acceptsFiles(task, urls)) return false;
        taskSource.requestOpenUrls(taskSource.index(row, 0), urls);
        return true;
    }
    function beginLaunch(row, task) {
        const key = appKey(task);
        launching = Object.assign({}, launching, {[key]: Date.now()});
        taskSource.requestNewInstance(taskSource.index(row, 0));
    }
    Timer {
        interval: 200; repeat: true; running: Object.keys(dock.launching).length > 0
        onTriggered: {
            let pending = Object.assign({}, dock.launching);
            for (const key of Object.keys(pending)) {
                let opened = false;
                for (let i = 0; i < pinned.count; ++i) {
                    const item = pinned.itemAt(i) as TaskEntry;
                    if (item && dock.appKey(item.model) === key && !item.model.IsLauncher) opened = true;
                }
                if (opened || Date.now() - pending[key] >= 10000) delete pending[key];
            }
            dock.launching = pending;
        }
    }
    function newInstance() {
        if (contextRow < 0 || !contextTask || !(contextTask.IsLauncher || contextTask.IsNewInstanceable)) return;
        if (contextTask.IsLauncher) beginLaunch(contextRow, contextTask);
        else taskSource.requestNewInstance(taskSource.index(contextRow, 0));
        closeMenu();
    }
    function closeTask() {
        if (contextRow < 0 || !contextTask || !contextTask.IsClosable) return;
        const row = contextRow;
        const task = contextTask;
        const list = DockLogic.ordered(windows(row, task));
        closeMenu();
        // Resolve every identity again: closing a child can reorder the model.
        for (const window of list) {
            const idx = windowIndex(row, task, window.id);
            if (idx !== null) taskSource.requestClose(idx);
        }
    }
    function reconcileRequests() {
        for (let row = 0; row < pinned.count; ++row) {
            const item = pinned.itemAt(row) as TaskEntry;
            if (!item || item.model.IsLauncher) continue;
            const key = appKey(item.model);
            const requested = requestedWindows[key];
            if (!requested) continue;
            const list = windows(row, item.model);
            // Once acknowledged, subsequent external focus changes take precedence.
            if (!list.some(w => w.id === requested) || list.some(w => w.id === requested && w.active))
            delete requestedWindows[key];
        }
    }
    Connections {
        target: dock.taskSource
        ignoreUnknownSignals: true
        function onDataChanged() { dock.reconcileRequests(); }
        function onModelReset() { dock.closeMenu(); dock.requestedWindows = ({}); Qt.callLater(dock.restoreOrder); }
        function onRowsRemoved() { dock.closeMenu(); dock.reconcileRequests(); }
        function onLayoutChanged() { dock.closeMenu(); }
        function onRowsInserted() { Qt.callLater(dock.restoreOrder); }
    }
    // Test entry point: resolve the current app row, then follow the exact click path.
    function cycleApp(appId) {
        for (let row = 0; row < pinned.count; ++row) {
            const item = pinned.itemAt(row) as TaskEntry;
            if (item && (String(item.model.AppId) === appId || appKey(item.model) === appId)) {
                activate(row, item.model);
                return true;
            }
        }
        return false;
    }
    // Shortcuts follow the same manual order as the visible app entries.
    function activateEntry(n) {
        if (!Number.isInteger(n) || n < 1 || n > 9) return false;
        const item = pinned.itemAt(n - 1) as TaskEntry;
        if (item) { activate(n - 1, item.model); return true; }
        return false;
    }
    function activate(row, task) {
        hideTooltip(); closeMenu();
        if (task.IsLauncher) { beginLaunch(row, task); return; }
        const list = windows(row, task);
        if (!list.length) return;
        const key = appKey(task);
        const pending = list.find(w => w.id === requestedWindows[key]);
        if (!pending) delete requestedWindows[key];
        else if (pending.active) delete requestedWindows[key];
        const active = pending || list.find(w => w.active);
        if (active || task.IsActive) {
            if (list.length === 1) return;
            const ordered = DockLogic.ordered(list);
            const position = ordered.findIndex(w => active && w.id === active.id);
            activateWindow(row, task, ordered[(position + 1) % ordered.length].id);
        } else {
            // No dates means the first current child, without inventing recency.
            const recent = list.reduce((best, w) => w.lastActivated > best.lastActivated ? w : best);
            activateWindow(row, task, recent.id);
        }
    }
    FolderListModel {
        id: applications; folder: "file:///usr/share/applications"; showDirs: false
        nameFilters: dock.candidates
        onStatusChanged: if (status === FolderListModel.Ready) dock.refreshPins()
        onCountChanged: dock.refreshPins()
    }
    TaskManager.TasksModel {
        id: tasks; groupMode: TaskManager.TasksModel.GroupApplications; groupInline: false
        sortMode: TaskManager.TasksModel.SortManual; separateLaunchers: false; launchInPlace: true; hideActivatedLaunchers: true
    }
    readonly property string activeAppName: {
        for (let i = 0; i < pinned.count; ++i) {
            const item = pinned.itemAt(i) as TaskEntry;
            if (item && item.activeName) return item.activeName;
        }
        return "Escritorio";
    }
    readonly property int pinnedCount: {
        let count = 0;
        for (let i = 0; i < pinned.count; ++i) {
            const item = pinned.itemAt(i) as TaskEntry;
            if (item && item.pinnedTask) ++count;
        }
        return count;
    }
    width: contents.width+16; height: 48; radius: 14
    color: Theme.dockSurface; border.color: Theme.border
    RectangularShadow { anchors.fill: parent; z: -1; radius: 14; blur: 24; offset: Qt.vector2d(0, 8); color: Theme.shadow; visible: GraphicsInfo.api !== GraphicsInfo.Software }
    Rectangle { x: 14; y: 1; width: parent.width-28; height: 1; color: Theme.sheen }
    Row { id: contents; x: 8; height: 48; spacing: 6
        Repeater {
            id: pinned
            model: dock.taskSource
            delegate: TaskEntry {}
        }
        Rectangle { visible: pinned.count > 0; width: 1; height: 20; y: 14; color: Theme.border }
        DockItem { sessionMode: dock.sessionMode; onTooltipRequested: (text, center) => dock.showTooltip(text, center); task: ({AppName: "Todas las aplicaciones", singlrGrid: true, decoration: ""}); onActivated: dock.applicationsRequested() }
        Tool { objectName: "overviewButton"; visible: dock.overviewAvailable; width: 32; height: 48; icon: "cards-three"; iconSize: 20; description: "Multitarea"; onClicked: dock.systemBridge.invokeShortcut("kwin", "Singlr Overview") }
    }
    component TaskEntry: Item {
        id: entry
        required property var model
        required property int index
        readonly property bool pinnedTask: !!model && (!!model.IsLauncher || !!model.HasLauncher)
        readonly property string activeName: model && model.IsActive ? String(model.AppName || model.display || "Escritorio") : ""
        visible: !!model; width: 32; height: 48
        DockItem {
            objectName: "dockTask" + entry.index
            sessionMode: dock.sessionMode; task: entry.model
            dockOwner: dock
            onReorderFinished: position => dock.moveAt(entry.index, position)
            fileAcceptor: urls => dock.acceptsFiles(entry.model, urls)
            onFilesDropped: urls => dock.openFiles(entry.index, entry.model, urls)
            onTooltipRequested: (text, center) => dock.showTooltip(text, center)
            launching: dock.launching[dock.appKey(entry.model)] !== undefined
            onInteracted: dock.hideTooltip()
            onNewInstanceRequested: {
                if (entry.model.IsLauncher) dock.beginLaunch(entry.index, entry.model);
                else if (entry.model.IsNewInstanceable) dock.taskSource.requestNewInstance(dock.taskSource.index(entry.index, 0));
            }
            onActivated: dock.activate(entry.index, entry.model)
            onContextRequested: dock.openContext(entry.index, entry.model)
        }
    }
    DeferredLoader {
        opened: !dock.sessionMode && !!dock.tooltipText && !dock.menuOpen
        sourceComponent: Component {
            Controls.Popup {
                visible: !dock.sessionMode && !!dock.tooltipText && !dock.menuOpen
                x: dock.tooltipCenter - dock.x - width / 2; y: -height - 8; padding: 8
                popupType: Controls.Popup.Item; closePolicy: Controls.Popup.NoAutoClose
                background: Rectangle { radius: 8; color: Theme.surface; border.color: Theme.border }
                contentItem: UiText { text: dock.tooltipText; font.pixelSize: 12 }
            }
        }
    }
    Keys.onEscapePressed: contextRow = -1
    DeferredLoader {
        id: dockMenuLoader; objectName: "DockMenuLoader"; opened: dock.menuOpen
        sourceComponent: Component {
            ContextMenu {
                id: dockMenu
                parent: dock.menuHost || dock
                visible: dock.menuOpen; x: 0; y: dock.menuHost ? 0 : -height-8
                margins: dock.menuHost ? 0 : 4
                entries: dock.menuEntries
                onClosed: dock.closeMenu()
                onTriggered: entry => dock.runMenu(dockMenu.currentIndex)
            }
        }
    }
}
