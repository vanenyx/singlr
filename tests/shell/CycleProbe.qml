import QtQuick
import org.kde.taskmanager as TaskManager
import Singlr.Shell
Item {
    id: root
    Dock { id: dock; sessionMode: true; visible: false }
    TaskManager.TasksModel { id: watch; groupMode: TaskManager.TasksModel.GroupDisabled }
    function activeTitle() {
        for (let i = 0; i < watch.count; ++i) {
            const idx = watch.index(i, 0);
            if (watch.data(idx, TaskManager.AbstractTasksModel.IsActive)) return String(watch.data(idx, Qt.DisplayRole));
        }
        return "(ninguna)";
    }
    property int step: 0
    Timer {
        interval: 900; repeat: true; running: true
        onTriggered: {
            if (root.step > 0) console.log("CYCLE", root.step, root.activeTitle());
            if (root.step >= 7) { Qt.quit(); return; }
            dock.cycleApp("org.kde.dolphin");
            root.step++;
        }
    }
}
