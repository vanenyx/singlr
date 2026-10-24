import QtQuick
import org.kde.taskmanager as TaskManager
import org.kde.milou as Milou

// External client on the private display/bus. No layer-shell surface is created.
// Raíz Item: con una Window invisible como raíz, qml6 no llega a ejecutar los timers en la sesión.
Item {
    id: root
    property bool attempted: false
    property bool launched: false
    property bool found: false
    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
    }
    Milou.ResultsModel {
        id: results
        limit: 10
    }
    // KRunner bloquea el hilo si recibe la consulta antes de que arranque el bucle de eventos.
    Timer { interval: 300; running: true; onTriggered: results.queryString = "dolphin" }
    Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: {
            if (!root.attempted && !results.querying && results.rowCount() > 0) {
                for (let row = 0; row < results.rowCount(); ++row) {
                    const idx = results.index(row, 0)
                    const label = String(results.data(idx, Qt.DisplayRole))
                    console.log("T204_MILOU_RESULT", row, label)
                    if (label.toLowerCase().includes("dolphin")) {
                        root.attempted = true
                        root.launched = results.run(idx)
                        console.log("T204_MILOU_LAUNCH", root.launched)
                        break
                    }
                }
            }
            for (let row = 0; row < tasks.count; ++row) {
                const idx = tasks.index(row, 0)
                const appId = String(tasks.data(idx, TaskManager.AbstractTasksModel.AppId))
                const isWindow = tasks.data(idx, TaskManager.AbstractTasksModel.IsWindow)
                const mapped = tasks.data(idx, TaskManager.AbstractTasksModel.IsMapped)
                if (root.launched && !root.found && isWindow && mapped && appId.toLowerCase().includes("dolphin")) {
                    root.found = true
                    console.log("T204_TASKS_PASS", appId, "IsWindow=" + isWindow, "IsMapped=" + mapped)
                }
            }
        }
    }
    Timer {
        interval: 45000
        running: true
        onTriggered: {
            if (!root.found)
                console.error("T204_PROBE_FAIL: Dolphin no aparece mapeado en TasksModel")
        }
    }
}
