pragma ComponentBehavior: Bound
import QtQuick
import org.kde.taskmanager as TaskManager

// One coordinator per session, shared by all output menus. No native actions in previews.
Item {
    id: coordinator
    property bool sessionMode: false
    // qmllint disable unqualified
    property var systemBridge: typeof SinglrSystem !== "undefined" ? SinglrSystem : null
    // qmllint enable unqualified
    property var notificationCenter: null
    property var taskSource: nativeTasks.item
    property int timeout: 10000
    property string pendingAction: ""
    readonly property bool waiting: pendingAction !== ""
    property int generation: 0
    signal blocked(string action, string appName)
    signal completed(string action)

    Loader {
        id: nativeTasks
        active: coordinator.sessionMode && coordinator.taskSource === item
        sourceComponent: Component {
            TaskManager.TasksModel {
                groupMode: TaskManager.TasksModel.GroupDisabled
                filterByVirtualDesktop: false; filterByScreen: false; filterByActivity: false
                filterHidden: false
            }
        }
    }
    function windows() {
        const result = [];
        if (!taskSource) return result;
        for (let row = 0; row < taskSource.count; ++row) {
            const idx = taskSource.index(row, 0);
            const read = role => taskSource.data(idx, role);
            if (!read(TaskManager.AbstractTasksModel.IsWindow) || read(TaskManager.AbstractTasksModel.IsGroupParent)
                || read(TaskManager.AbstractTasksModel.IsLauncher)) continue;
            result.push({id: JSON.stringify(read(TaskManager.AbstractTasksModel.WinIdList)),
                name: String(read(TaskManager.AbstractTasksModel.AppName) || "Una aplicación")});
        }
        return result;
    }
    function execute(action) {
        if (!sessionMode) { console.log("SESSION_ACTION windowed: " + action); completed(action); return; }
        if (systemBridge && typeof systemBridge[action] === "function") systemBridge[action]();
        else console.log("SESSION_ACTION unavailable: " + action);
        completed(action);
    }
    function cancel() { pendingAction = ""; deadline.stop(); observation.stop(); ++generation; }
    function start(action) {
        if (["logout", "reboot", "powerOff"].indexOf(action) < 0) return;
        cancel();
        if (!sessionMode) { execute(action); return; }
        // Fail closed if the model has not loaded. Never treat an absent model as no windows.
        if (!taskSource) { reportBlocked(action, "Una aplicación"); return; }
        pendingAction = action;
        const targets = windows();
        deadline.start();
        // Resolve every index immediately before use: a close can synchronously remove/reorder rows.
        for (const target of targets) {
            if (!waiting) break;
            for (let row = 0; row < taskSource.count; ++row) {
                const idx = taskSource.index(row, 0);
                if (JSON.stringify(taskSource.data(idx, TaskManager.AbstractTasksModel.WinIdList)) === target.id) {
                    taskSource.requestClose(idx);
                    break;
                }
            }
        }
        observation.restart();
    }
    function check() {
        if (!waiting || !taskSource || windows().length) return;
        const action = pendingAction;
        cancel();
        execute(action);
    }
    function reportBlocked(action, name) {
        blocked(action, name);
        if (!notificationCenter) return;
        const token = generation;
        const verb = action === "logout" ? "cerrar sesión" : action === "reboot" ? "reiniciar" : "apagar";
        notificationCenter.notifyLocal("No se pudo " + verb + ": " + name + " tiene cambios sin guardar", () => {
            if (token !== coordinator.generation) return;
            coordinator.cancel();
            coordinator.execute(action);
        });
    }
    Timer { id: observation; interval: 0; onTriggered: coordinator.check() }
    Timer {
        id: deadline; interval: coordinator.timeout
        onTriggered: {
            coordinator.check();
            if (!coordinator.waiting) return;
            const action = coordinator.pendingAction;
            const remaining = coordinator.windows();
            coordinator.cancel();
            coordinator.reportBlocked(action, remaining.length ? remaining[0].name : "Una aplicación");
        }
    }
    Connections {
        target: coordinator.taskSource
        ignoreUnknownSignals: true
        function onRowsRemoved() { if (coordinator.waiting) observation.restart(); }
        function onRowsInserted() { if (coordinator.waiting) observation.restart(); }
        function onDataChanged() { if (coordinator.waiting) observation.restart(); }
        function onModelReset() { if (coordinator.waiting) observation.restart(); }
        function onCountChanged() { if (coordinator.waiting) observation.restart(); }
    }
}
