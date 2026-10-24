pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Effects
import Qt.labs.folderlistmodel
import org.kde.taskmanager as TaskManager
import Singlr.Ui
Rectangle {
    id: dock
    property bool sessionMode: false
    signal launcherRequested()
    signal applicationsRequested()
    property int contextRow: -1
    readonly property bool menuOpen: contextRow >= 0
    property var contextTask: null
    property var modelOverride: null
    readonly property var taskSource: modelOverride || tasks
    property alias tasksModel: tasks
    readonly property var candidates: ["org.kde.dolphin.desktop", "org.kde.konsole.desktop", "firefox.desktop", "org.kde.kate.desktop", "systemsettings.desktop"]
    function refreshPins() {
        let found = [];
        for (let i=0; i<applications.count; ++i) found.push(applications.get(i, "fileName"));
        tasks.launcherList = candidates.filter(n => found.indexOf(n) >= 0).map(n => "applications:" + n);
    }
    function openContext(row, task) { contextTask = task; contextRow = row; forceActiveFocus(); }
    function newInstance() {
        if (contextRow < 0 || !contextTask || !(contextTask.IsLauncher || contextTask.IsNewInstanceable)) return;
        taskSource.requestNewInstance(taskSource.index(contextRow, 0)); contextRow = -1;
    }
    function closeTask() {
        if (contextRow < 0 || !contextTask || !contextTask.IsClosable) return;
        taskSource.requestClose(taskSource.index(contextRow, 0)); contextRow = -1;
    }
    Connections {
        target: dock.taskSource
        ignoreUnknownSignals: true
        function onModelReset() { dock.contextRow = -1; }
        function onRowsRemoved() { dock.contextRow = -1; }
        function onLayoutChanged() { dock.contextRow = -1; }
    }
    function activate(row, task) {
        contextRow = -1;
        const idx = taskSource.index(row, 0);
        if (task.IsLauncher) taskSource.requestNewInstance(idx);
        else if (task.IsActive && task.IsMinimizable) taskSource.requestToggleMinimized(idx);
        else taskSource.requestActivate(idx);
    }
    FolderListModel {
        id: applications; folder: "file:///usr/share/applications"; showDirs: false
        nameFilters: dock.candidates
        onStatusChanged: if (status === FolderListModel.Ready) dock.refreshPins()
        onCountChanged: dock.refreshPins()
    }
    TaskManager.TasksModel { id: tasks; groupMode: TaskManager.TasksModel.GroupDisabled; sortMode: TaskManager.TasksModel.SortManual; launchInPlace: true; hideActivatedLaunchers: true; onCountChanged: dock.contextRow = -1 }
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
    color: Qt.rgba(22/255,23/255,24/255,0.55); border.color: "#14ffffff"
    RectangularShadow { anchors.fill: parent; z: -1; radius: 14; blur: 24; offset: Qt.vector2d(0, 8); color: "#59000000"; visible: GraphicsInfo.api !== GraphicsInfo.Software }
    Rectangle { x: 14; y: 1; width: parent.width-28; height: 1; color: "#0affffff" }
    Row { id: contents; x: 8; height: 48; spacing: 6
        Repeater {
            id: pinned
            model: dock.taskSource
            delegate: TaskEntry {}
        }
        Rectangle { visible: unpinned.width > 0 && dock.pinnedCount > 0; width: 1; height: 20; y: 14; color: "#14ffffff" }
        Row {
            id: unpinned; height: 48; spacing: 6
            Repeater {
                model: dock.taskSource
                delegate: DockItem {
                    sessionMode: dock.sessionMode
                    required property var model
                    required property int index
                    visible: !!model && !model.IsLauncher && !model.HasLauncher
                    task: model
                    onActivated: dock.activate(index, model)
                    onContextRequested: dock.openContext(index, model)
                }
            }
        }
        Rectangle { visible: pinned.count > 0; width: 1; height: 20; y: 14; color: "#14ffffff" }
        DockItem { sessionMode: dock.sessionMode; task: ({AppName: "Todas las aplicaciones", singlrGrid: true, decoration: ""}); onActivated: dock.applicationsRequested() }
    }
    component TaskEntry: Item {
        id: entry
        required property var model
        required property int index
        readonly property bool pinnedTask: !!model && (!!model.IsLauncher || !!model.HasLauncher)
        readonly property string activeName: model && model.IsActive ? String(model.AppName || model.display || "Escritorio") : ""
        visible: pinnedTask; width: 32; height: 48
        DockItem {
            sessionMode: dock.sessionMode; task: entry.model
            onActivated: dock.activate(entry.index, entry.model)
            onContextRequested: dock.openContext(entry.index, entry.model)
        }
    }
    Keys.onEscapePressed: contextRow = -1
    Controls.Popup {
        visible: dock.menuOpen; x: 0; y: -height-8; width: 224; height: 116; padding: 4; focus: true
        popupType: dock.sessionMode ? Controls.Popup.Window : Controls.Popup.Item
        onClosed: dock.contextRow = -1
        background: Rectangle { radius: 8; color: Theme.raised; border.color: Theme.border }
        contentItem: Column {
            Tool { width: parent.width; height: 36; label: "Abrir nueva ventana"; enabled: !!dock.contextTask && (!!dock.contextTask.IsLauncher || !!dock.contextTask.IsNewInstanceable)
                onClicked: dock.newInstance() }
            Tool { width: parent.width; height: 36; label: "Cerrar"; enabled: !!dock.contextTask && !!dock.contextTask.IsClosable
                onClicked: dock.closeTask() }
            Tool { width: parent.width; height: 36; label: "Cancelar"; onClicked: dock.contextRow = -1 }
        }
    }
}
