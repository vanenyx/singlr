import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell
import org.kde.taskmanager as TaskManager
import org.kde.milou as Milou

Window {
    id: root
    width: 1600
    height: 170
    visible: true
    color: "#182333"
    title: "Singlr T202 integration probe"
    property int resultCount: 0
    property bool launched: false
    property bool found: false
    property bool frameLogged: false
    property string taskSummary: "Esperando ventanas…"

    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    LayerShell.Window.scope: "singlr-t202-probe"
    LayerShell.Window.exclusionZone: 170
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone

    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
    }
    Milou.ResultsModel {
        id: results
        singleRunner: "krunner_services"
        queryString: "konsole"
        limit: 10
    }

    onFrameSwapped: {
        if (!frameLogged) {
            frameLogged = true
            console.log("SINGLR_PROBE_FRAME layer-shell panel rendered")
        }
    }
    Column {
        x: 24
        y: 18
        spacing: 10
        Text { color: "white"; font.pixelSize: 24; text: "Singlr · T202 · layer-shell / Milou / TasksModel" }
        Text { color: "#c9ddff"; font.pixelSize: 18; text: "Milou: konsole · resultados: " + root.resultCount + " · lanzamiento: " + root.launched }
        Text { color: "#c9ddff"; font.pixelSize: 18; text: root.taskSummary }
        Text { color: root.found ? "#88ffbb" : "#ffdb99"; font.pixelSize: 18; text: root.found ? "PASS: Konsole es una ventana real en TasksModel" : "Esperando Konsole en esta sesión…" }
    }
    Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: {
            root.resultCount = results.rowCount()
            if (!root.launched && !results.querying && results.rowCount() > 0) {
                for (let row = 0; row < results.rowCount(); ++row) {
                    const idx = results.index(row, 0)
                    const label = String(results.data(idx, Qt.DisplayRole))
                    console.log("SINGLR_PROBE_RESULT", row, label)
                    if (label.toLowerCase().includes("konsole")) {
                        root.launched = results.run(idx)
                        console.log("SINGLR_PROBE_LAUNCH", root.launched)
                        break
                    }
                }
            }
            const names = []
            for (let row = 0; row < tasks.count; ++row) {
                const idx = tasks.index(row, 0)
                const appId = String(tasks.data(idx, TaskManager.AbstractTasksModel.AppId))
                const label = String(tasks.data(idx, Qt.DisplayRole))
                const isWindow = tasks.data(idx, TaskManager.AbstractTasksModel.IsWindow)
                const mapped = tasks.data(idx, TaskManager.AbstractTasksModel.IsMapped)
                names.push(appId + ": " + label)
                if (root.launched && !root.found && isWindow && mapped && appId.toLowerCase().includes("konsole")) {
                    root.found = true
                    console.log("SINGLR_PROBE_PASS", appId, label, "IsWindow=" + isWindow, "IsMapped=" + mapped)
                }
            }
            root.taskSummary = "TasksModel (" + tasks.count + "): " + names.join(" | ")
        }
    }
    Timer {
        interval: 30000
        running: true
        onTriggered: {
            if (!root.found) {
                console.error("SINGLR_PROBE_FAIL: sin Konsole mapeada; resultados=" + results.rowCount() + " tareas=" + tasks.count)
                Qt.exit(1)
            }
        }
    }
}
