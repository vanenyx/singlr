pragma ComponentBehavior: Bound
import QtQuick
import Qt.labs.folderlistmodel
import org.kde.taskmanager as TaskManager
import Singlr.Ui
Rectangle {
    id: dock
    signal launcherRequested()
    property alias tasksModel: tasks
    readonly property var candidates: ["org.kde.dolphin.desktop", "org.kde.konsole.desktop", "firefox.desktop", "org.kde.kate.desktop", "systemsettings.desktop"]
    function refreshPins() {
        let found = [];
        for (let i=0; i<applications.count; ++i) found.push(applications.get(i, "fileName"));
        tasks.launcherList = candidates.filter(n => found.indexOf(n) >= 0).map(n => "applications:" + n);
    }
    function activate(row, isLauncher) {
        const idx = tasks.index(row, 0);
        if (isLauncher) tasks.requestNewInstance(idx);
        else tasks.requestActivate(idx);
    }
    FolderListModel {
        id: applications; folder: "file:///usr/share/applications"; showDirs: false
        nameFilters: dock.candidates
        onStatusChanged: if (status === FolderListModel.Ready) dock.refreshPins()
        onCountChanged: dock.refreshPins()
    }
    TaskManager.TasksModel { id: tasks; groupMode: TaskManager.TasksModel.GroupApplications; launchInPlace: true }
    width: contents.width+20; height: 48; radius: 10
    color: Theme.panel; border.color: Theme.border
    Row { id: contents; x: 10; y: 7; spacing: 6
        Tool { icon: "magnifying-glass"; description: "Buscar · Meta Espacio"; width: 34; height: 34; onClicked: dock.launcherRequested() }
        Rectangle { width: 1; height: 18; y: 8; color: Theme.border }
        Repeater {
            model: tasks
            delegate: DockItem {
                required property var model
                required property int index
                task: model
                onActivated: dock.activate(index, !!model.IsLauncher)
            }
        }
    }
}
