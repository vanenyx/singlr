pragma ComponentBehavior: Bound
import QtQuick
import Qt.labs.folderlistmodel
import org.kde.taskmanager as TaskManager
import Singlr.Ui
Rectangle {
    id: dock
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
    width: contents.width+20; height: menuOpen ? 150 : 48; radius: 10
    color: Theme.panel; border.color: Theme.border
    Row { id: contents; x: 10; anchors.bottom: parent.bottom; anchors.bottomMargin: 7; spacing: 6
        Tool { icon: "magnifying-glass"; description: "Buscar · Meta Espacio"; width: 34; height: 34; onClicked: dock.launcherRequested() }
        Tool { icon: "squares-four"; description: "Todas las aplicaciones"; width: 34; height: 34; onClicked: dock.applicationsRequested() }
        Rectangle { width: 1; height: 18; y: 8; color: Theme.border }
        Repeater {
            model: dock.taskSource
            delegate: DockItem {
                required property var model
                required property int index
                task: model
                onActivated: dock.activate(index, model)
                onContextRequested: dock.openContext(index, model)
            }
        }
    }
    Keys.onEscapePressed: contextRow = -1
    Rectangle {
        visible: dock.menuOpen; x: 10; y: 8; width: parent.width-20; height: 90; radius: 6
        color: Theme.raised; border.color: Theme.border
        Column { anchors.fill: parent; anchors.margins: 5
            Tool { width: parent.width; label: "Abrir nueva ventana"; enabled: !!dock.contextTask && (!!dock.contextTask.IsLauncher || !!dock.contextTask.IsNewInstanceable)
                onClicked: dock.newInstance() }
            Tool { width: parent.width; label: "Cerrar"; enabled: !!dock.contextTask && !!dock.contextTask.IsClosable
                onClicked: dock.closeTask() }
            Tool { width: parent.width; label: "Cancelar"; onClicked: dock.contextRow = -1 }
        }
    }
}
