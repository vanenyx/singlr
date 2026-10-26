pragma ComponentBehavior: Bound
import QtQuick
import Singlr.Ui
import org.kde.plasma.private.kicker as Kicker

ContextMenu {
    id: menu
    property bool sessionMode: false
    // qmllint disable unqualified
    property var systemBridge: typeof SinglrSystem !== "undefined" ? SinglrSystem : null
    // qmllint enable unqualified
    signal actionRequested(string action)
    width: 292
    headerName: systemBridge && typeof systemBridge.userName !== "undefined" && systemBridge.userName ? systemBridge.userName : "Usuario"
    headerIcon: systemBridge && typeof systemBridge.userIcon !== "undefined" ? systemBridge.userIcon : ""
    Kicker.SimpleFavoritesModel { id: settings; favorites: ["singlr-settings.desktop"] }
    entries: buildEntries()
    onAboutToShow: entries = buildEntries()
    function buildEntries() {
        const actions = [
            {label: "Ajustes de Singlr…", icon: "gear", action: "settings"}
        ];
        if (systemBridge && systemBridge.canLock)
            actions.push({label: "Bloquear", icon: "lock-simple", shortcut: "Meta+L", action: "lockScreen"});
        if (systemBridge && typeof systemBridge.canSuspend !== "undefined" && systemBridge.canSuspend)
            actions.push({label: "Suspender", icon: "moon", action: "suspend"});
        if (systemBridge && typeof systemBridge.canHibernate !== "undefined" && systemBridge.canHibernate)
            actions.push({label: "Hibernar", icon: "moon", action: "hibernate"});
        if (systemBridge && systemBridge.canReboot)
            actions.push({label: "Reiniciar…", icon: "power", action: "reboot"});
        if (systemBridge && systemBridge.canShutdown)
            actions.push({label: "Apagar…", icon: "power", action: "powerOff"});
        if (systemBridge && systemBridge.canLogout)
            actions.push({label: "Cerrar sesión…", icon: "arrow-right", action: "logout"});
        return actions;
    }
    function dispatch(action) {
        actionRequested(action);
        if (!sessionMode) { console.log("SESSION_ACTION windowed: " + action); return; }
        if (action === "settings") { if (settings.count > 0) settings.trigger(0, "", null); return; }
        if (systemBridge && typeof systemBridge[action] === "function") systemBridge[action]();
        else console.log("SESSION_ACTION unavailable: " + action);
    }
    onTriggered: entry => dispatch(entry.action)
}
