pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import "../Ui/Focus.js" as Focus
import QtQuick.Controls as Controls
import QtQuick.Effects
import QtCore
import "DockLogic.js" as DockLogic
import "ApplicationActions.js" as ApplicationActions
import Qt.labs.folderlistmodel
import org.kde.taskmanager as TaskManager
import Singlr.Ui
Rectangle {
    id: dock
    function focusFirst() { Focus.advance(dock, dock, true); }
    Keys.onTabPressed: Focus.advance(dock, Window.window.activeFocusItem, true)
    Keys.onBacktabPressed: Focus.advance(dock, Window.window.activeFocusItem, false)
    Keys.onLeftPressed: Focus.advance(dock, Window.window.activeFocusItem, false)
    Keys.onRightPressed: Focus.advance(dock, Window.window.activeFocusItem, true)
    readonly property var dockMenu: dockMenuLoader.item
    property bool sessionMode: false
    property string dockMode: DockSettings.mode
    property int dockHeight: DockSettings.height
    property bool autoHide: DockSettings.autoHide
    property real screenWidth: 2048
    readonly property bool fixed: dockMode === "fixed"
    readonly property int bottomMargin: fixed ? 0 : 4
    readonly property int exclusionZone: autoHide ? 0 : height + bottomMargin
    readonly property int iconSize: Math.round(height * 2 / 3)
    readonly property real sizeFactor: height / 48
    readonly property int horizontalPadding: Math.round(8 * sizeFactor)
    readonly property bool overflowing: contents.width > width - 2 * horizontalPadding
    function scrollBy(distance) {
        viewport.contentX = Math.max(0, Math.min(viewport.contentWidth - viewport.width, viewport.contentX + distance));
        hideTooltip();
    }
    function ensureVisible(item) {
        if (!item || !overflowing) return;
        const point = item.mapToItem(viewport.contentItem, 0, 0);
        if (point.x < viewport.contentX) viewport.contentX = point.x;
        else if (point.x + item.width > viewport.contentX + viewport.width)
            viewport.contentX = point.x + item.width - viewport.width;
    }
    function fitViewport() {
        scrollBy(0);
        const focused = dock.Window.window ? dock.Window.window.activeFocusItem : null;
        if (focused && Focus.belongsTo(focused, contents)) ensureVisible(focused);
    }
    property bool keyboardHeld: false
    property bool launcherHeld: false
    property bool edgeHovered: false
    property bool dragging: false
    property bool fileDragActive: false
    readonly property bool pointerInside: hover.hovered
    readonly property bool filesHovered: fileHover.containsDrag || fileDragActive
    readonly property bool heldOpen: pointerInside || filesHovered || dragging || menuOpen || keyboardHeld || launcherHeld || edgeHovered
    property bool revealed: false
    readonly property bool shown: !autoHide || heldOpen || revealed
    function reveal() { revealed = true; if (autoHide && !heldOpen) hideDelay.restart(); }
    onHeldOpenChanged: { if (heldOpen) { revealed = true; hideDelay.stop(); } else if (autoHide) hideDelay.restart(); }
    onAutoHideChanged: { revealed = heldOpen; hideDelay.stop(); }
    Timer { id: hideDelay; interval: 450; onTriggered: if (dock.autoHide && !dock.heldOpen) { dock.revealed = false; dock.hideTooltip(); } }
    // Keep the reveal grace period while crossing the floating dock's 4 px gap.
    onShownChanged: if (!shown) hideTooltip()
    HoverHandler { id: hover }
    DropArea { id: fileHover; anchors.fill: parent; onEntered: event => { event.accepted = event.hasUrls; } }

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
    // writableLocation() already returns a file: URL; prefixing it produced
    // "file://file:///…" and pins were never stored.
    property url settingsLocation: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/singlr/dock.json"
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
        const url = String(task.LauncherUrlWithoutIcon || task.LauncherUrl || "");
        const actions = ApplicationActions.entries(systemBridge, url);
        if (task.IsNewInstanceable && !ApplicationActions.hasNewWindow(actions))
            actions.push({label: "Nueva ventana", icon: "plus", shortcut: "⏎", action: "new", enabled: true});
        if (actions.length) actions[0].separator = contextWindows.length > 0;
        const entries = contextWindows.map(w => ({label: w.title, id: w.id, action: "window", active: w.active, enabled: true})).concat(actions);
        if (url) entries.push({label: task.IsLauncher || task.HasLauncher ? "Quitar del dock" : "Fijar en el dock",
            icon: "push-pin", action: "pin", separator: actions.length > 0, enabled: true});
        if (task.IsClosable && contextWindows.length > 0)
            entries.push({label: "Salir", icon: "x", action: "close", separator: entries.length > 0, enabled: true});
        menuEntries = entries;
        contextRow = row;
        Qt.callLater(() => dockMenu.contentItem.forceActiveFocus());
    }
    function runMenu(index) {
        const entry = menuEntries[index];
        if (!entry || !entry.enabled) return;
        if (entry.action === "window") { activateWindow(contextRow, contextTask, entry.id); closeMenu(); }
        else if (entry.action === "application") {
            systemBridge.launchApplicationAction(entry.url, entry.name);
            closeMenu();
        }
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
        if (position.x < viewport.x || position.x >= viewport.x + viewport.width) return false;
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
        if (contextRow < 0 || !contextTask || !contextTask.IsNewInstanceable) return;
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
    width: fixed ? screenWidth : Math.min(Math.max(1, screenWidth - 16), contents.width + 2 * horizontalPadding); height: dockHeight; radius: fixed ? 0 : 14
    color: Theme.dockSurface; border.color: fixed ? "transparent" : Theme.surfaceBorder
    Rectangle { width: parent.width; height: 1; color: Theme.surfaceBorder; visible: dock.fixed }
    RectangularShadow { anchors.fill: parent; z: -1; radius: 14; blur: 24; offset: Qt.vector2d(0, 8); color: Theme.shadow; visible: !dock.fixed && GraphicsInfo.api !== GraphicsInfo.Software }
    Tool {
        id: previous; objectName: "dockScrollPrevious"
        x: dock.horizontalPadding; anchors.verticalCenter: parent.verticalCenter
        visible: dock.overflowing; enabled: viewport.contentX > 0
        icon: "caret-left"; description: "Aplicaciones anteriores"
        onClicked: dock.scrollBy(-Math.max(dock.iconSize, viewport.width * 0.75))
    }
    Tool {
        id: next; objectName: "dockScrollNext"
        x: dock.width - dock.horizontalPadding - width; anchors.verticalCenter: parent.verticalCenter
        visible: dock.overflowing; enabled: viewport.contentX < viewport.contentWidth - viewport.width
        icon: "caret-right"; description: "Más aplicaciones"
        onClicked: dock.scrollBy(Math.max(dock.iconSize, viewport.width * 0.75))
    }
    Flickable {
        id: viewport; objectName: "dockViewport"
        x: dock.horizontalPadding + (dock.overflowing ? previous.width : 0)
        width: Math.max(1, dock.width - 2 * x); height: dock.height
        contentWidth: Math.max(width, contents.width); contentHeight: height
        clip: true; interactive: false; boundsBehavior: Flickable.StopAtBounds
        // Preserve the app's drag grab for reordering. Wheel/touchpad and explicit
        // buttons scroll; keyboard focus brings each entry into the viewport.
        onWidthChanged: Qt.callLater(dock.fitViewport)
        onContentWidthChanged: Qt.callLater(dock.fitViewport)
        WheelHandler {
            enabled: dock.overflowing; target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const pixels = event.pixelDelta.x || event.pixelDelta.y;
                const angle = event.angleDelta.x || event.angleDelta.y;
                dock.scrollBy(pixels ? -pixels : -angle / 120 * dock.iconSize * 2);
                event.accepted = true;
            }
        }
        Row { id: contents; x: dock.overflowing ? 0 : Math.round((viewport.width - width) / 2); height: dock.height; spacing: Math.round(6 * dock.sizeFactor)
            Repeater {
                id: pinned
                model: dock.taskSource
                delegate: TaskEntry {}
            }
            Rectangle { visible: pinned.count > 0; width: 1; height: Math.round(20 * dock.sizeFactor); anchors.verticalCenter: parent.verticalCenter; color: Theme.border }
            DockItem { id: appsButton; dockHeight: dock.height; sessionMode: dock.sessionMode; onActiveFocusChanged: if (activeFocus) dock.ensureVisible(appsButton); onTooltipRequested: (text, center) => dock.showTooltip(text, center); task: ({AppName: "Todas las aplicaciones", singlrGrid: true, decoration: ""}); onActivated: dock.applicationsRequested() }
            Tool { id: overviewButton; objectName: "overviewButton"; visible: dock.overviewAvailable; width: dock.iconSize; height: dock.height; icon: "cards-three"; iconSize: Math.round(20 * dock.sizeFactor); description: "Multitarea"; onActiveFocusChanged: if (activeFocus) dock.ensureVisible(overviewButton); onClicked: { dock.reveal(); dock.systemBridge.invokeShortcut("kwin", "Singlr Overview"); } }
        }
    }
    component TaskEntry: Item {
        id: entry
        required property var model
        required property int index
        readonly property bool pinnedTask: !!model && (!!model.IsLauncher || !!model.HasLauncher)
        readonly property string activeName: model && model.IsActive ? String(model.AppName || model.display || "Escritorio") : ""
        visible: !!model; width: dock.iconSize; height: dock.height
        DockItem {
            dockHeight: dock.height
            objectName: "dockTask" + entry.index
            sessionMode: dock.sessionMode; task: entry.model
            dockOwner: dock
            onActiveFocusChanged: if (activeFocus) dock.ensureVisible(this)
            onFileDragChanged: inside => dock.fileDragActive = inside
            onReorderDragChanged: active => dock.dragging = active
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
