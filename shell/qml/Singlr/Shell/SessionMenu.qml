pragma ComponentBehavior: Bound
import QtQuick
import Singlr.Ui
import org.kde.plasma.private.kicker as Kicker

ContextMenu {
    id: menu
    property bool sessionMode: false
    property var closeController: localClose
    readonly property bool closingApps: !!closeController && closeController.waiting
    SessionCloseController { id: localClose; sessionMode: menu.sessionMode && menu.closeController === localClose; systemBridge: menu.systemBridge }
    Connections {
        target: menu.closeController
        function onWaitingChanged() {
            if (menu.closingApps) menu.confirmingIndex = -1;
            menu.entries = menu.waitingEntries(menu.entries);
        }
        function onCompleted() { menu.close(); }
        function onBlocked() { menu.close(); }
    }
    onClosed: if (closingApps) closeController.cancel()
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
            {label: "Ajustes de Singlr…", icon: "gear", action: "settings"},
            {label: "Bloquear", icon: "lock-simple", shortcut: "Meta+L", action: "lockScreen"}
        ];
        if (systemBridge && typeof systemBridge.canSuspend !== "undefined" && systemBridge.canSuspend)
            actions.push({label: "Suspender", icon: "moon", action: "suspend"});
        if (systemBridge && typeof systemBridge.canHibernate !== "undefined" && systemBridge.canHibernate)
            actions.push({label: "Hibernar", icon: "moon", action: "hibernate"});
        actions.push({label: "Reiniciar…", icon: "power", action: "reboot", destructive: true, confirmation: "¿Reiniciar? Pulsa de nuevo"});
        actions.push({label: "Apagar…", icon: "power", action: "powerOff", destructive: true, confirmation: "¿Apagar? Pulsa de nuevo"});
        actions.push({label: "Cerrar sesión…", icon: "arrow-right", action: "logout", destructive: true, confirmation: "¿Cerrar sesión? Pulsa de nuevo"});
        for (const entry of actions) {
            entry.idleLabel = entry.label;
            if (["logout", "reboot", "powerOff"].indexOf(entry.action) >= 0) entry.keepOpen = true;
        }
        return waitingEntries(actions);
    }
    function waitingEntries(actions) {
        // Preserve the open menu's capability snapshot and geometry (P-011).
        return actions.map(entry => Object.assign({}, entry, {
            enabled: !closingApps,
            label: closingApps && entry.action === closeController.pendingAction ? "Cerrando apps…" : entry.idleLabel
        }));
    }
    function dispatch(action) {
        actionRequested(action);
        if (["logout", "reboot", "powerOff"].indexOf(action) >= 0) { closeController.start(action); return; }
        if (!sessionMode) { console.log("SESSION_ACTION windowed: " + action); return; }
        if (action === "settings") { if (settings.count > 0) settings.trigger(0, "", null); return; }
        if (systemBridge && typeof systemBridge[action] === "function") systemBridge[action]();
        else console.log("SESSION_ACTION unavailable: " + action);
    }
    onTriggered: entry => dispatch(entry.action)
}
