pragma ComponentBehavior: Bound
import QtQuick
import org.kde.notificationmanager as NM
Item {
    id: backend
    property var entries: []
    readonly property bool serverValid: NM.Server.valid
    readonly property string ownerName: NM.Server.currentOwner.name
    readonly property bool inhibited: NM.Server.inhibited
    function setInhibited(value) { NM.Server.inhibited = value; }
    function locate(id) {
        for (let row = 0; row < notifications.count; ++row) {
            const idx = notifications.index(row, 0);
            if (notifications.data(idx, NM.Notifications.IdRole) === id) return idx;
        }
        return null;
    }
    function dispatch(id, action) {
        const idx = locate(id);
        if (idx === null) return;
        notifications.window = backend.Window.window;
        if (action === "expire") notifications.expire(idx);
        else if (action === "close") notifications.close(idx);
        else if (action === "default") notifications.invokeDefaultAction(idx, NM.Notifications.Close);
        else notifications.invokeAction(idx, action, NM.Notifications.Close);
    }
    function markRead() { notifications.lastRead = new Date(); }
    function refresh() {
        const result = [];
        for (let row = 0; row < notifications.count; ++row) {
            const idx = notifications.index(row, 0);
            const get = role => notifications.data(idx, role);
            if (!get(NM.Notifications.ExpiredRole)) notifications.stopTimeout(idx);
            result.push({id: get(NM.Notifications.IdRole), app: get(NM.Notifications.ApplicationNameRole) || "Notificación",
                icon: get(NM.Notifications.ApplicationIconNameRole) || get(NM.Notifications.IconNameRole) || "dialog-information",
                title: get(NM.Notifications.SummaryRole) || "", body: get(NM.Notifications.BodyRole) || "",
                time: get(NM.Notifications.UpdatedRole) || get(NM.Notifications.CreatedRole),
                timeout: get(NM.Notifications.TimeoutRole), critical: get(NM.Notifications.UrgencyRole) === NM.Notifications.CriticalUrgency,
                expired: get(NM.Notifications.ExpiredRole), dismissed: get(NM.Notifications.DismissedRole),
                suppressed: get(NM.Notifications.WasAddedDuringInhibitionRole),
                defaultAction: get(NM.Notifications.HasDefaultActionRole),
                actionNames: get(NM.Notifications.ActionNamesRole), actionLabels: get(NM.Notifications.ActionLabelsRole)});
        }
        entries = result;
    }
    NM.Notifications {
        id: notifications
        showExpired: true; showDismissed: false; showJobs: false; showAddedDuringInhibition: true
        groupMode: NM.Notifications.GroupDisabled
        onRowsInserted: refreshTimer.restart()
        onRowsRemoved: refreshTimer.restart()
        onDataChanged: refreshTimer.restart()
        onModelReset: refreshTimer.restart()
    }
    Timer { id: refreshTimer; interval: 0; onTriggered: backend.refresh() }
    onServerValidChanged: console.log("NOTIFICATIONS_SERVER valid=" + serverValid + " owner=" + ownerName)
    Component.onCompleted: { refresh(); console.log("NOTIFICATIONS_SERVER valid=" + serverValid + " owner=" + ownerName); }
}
