pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell
import Singlr.Ui
// transientParent: null es imprescindible: si no, Qt ata cada Window a la ventana del
// Item contenedor (inexistente) y KWin nunca recibe la superficie layer-shell.
// LayerShell.Window.scope usa los nombres que KWin traduce a tipo de ventana (desktop, dock,
// notification, on-screen-display, tooltip, utility). Con nombres propios KWin las trata como
// ventanas normales: aparecen en la multitarea y en Alt+Tab.
Item {
    id: session
    readonly property var notificationCenter: notifications
    property bool launcherOpen: false
    property bool controlOpen: false
    property bool controlMapped: false
    onControlOpenChanged: {
        if (!controlOpen) controlMapped = false;
        // Let the initial page settle its existing implicitHeight before mapping.
        else Qt.callLater(() => { if (session.controlOpen) session.controlMapped = true; });
    }
    readonly property var launcher: launcherContent.item
    readonly property var controlPanel: controlContent.item
    readonly property Window overlay: launcherSurface.item as Window
    readonly property Window controlWindow: controlSurface.item as Window
    readonly property Window notificationsWindow: notificationSurface.item as Window
    // URLs defer panel imports as well as instances. Cached Items are reparented
    // out of their native Window when it is released; QObject ownership stays with Loader.
    DeferredLoader {
        id: launcherContent; objectName: "launcherLoader"; opened: session.launcherOpen
        source: Qt.resolvedUrl("Launcher.qml")
        onLoaded: {
            const panel = item as Item;
            panel.objectName = "sessionLauncher";
            panel.sessionMode = true;
            panel.parent = Qt.binding(() => session.overlay ? session.overlay.contentItem : session);
            panel.visible = Qt.binding(() => session.launcherOpen);
            panel.x = Qt.binding(() => (panel.parent.width - panel.width) / 2);
            panel.y = Qt.binding(() => Math.min(286, (panel.parent.height - panel.height) / 2));
        }
    }
    DeferredLoader {
        id: controlContent; objectName: "controlLoader"; opened: session.controlOpen
        Component.onCompleted: setSource(Qt.resolvedUrl("ControlCenter.qml"), {
            audio: systemControls,
            notifications: session.notificationCenter,
            opened: Qt.binding(() => session.controlOpen)
        })
        onLoaded: {
            const panel = item as Item;
            panel.parent = Qt.binding(() => session.controlWindow ? session.controlWindow.contentItem : session);
            panel.visible = Qt.binding(() => session.controlMapped);
            panel.width = 340;
            panel.height = Qt.binding(() => session.controlWindow ? session.controlWindow.height : 560);
        }
    }
    Connections {
        target: launcherContent.item
        function onClosed() { session.launcherOpen = false; }
    }
    Connections {
        target: controlContent.item
        function onClosed() { session.controlOpen = false; }
        function onOpenRequested() {
            if (!session.controlOpen) session.toggleControlCenter();
            controlFocus.stop();
            if (session.controlWindow) session.controlWindow.requestActivate();
        }
    }
    OnScreenDisplay {
        id: osd; width: 240; height: 44
        parent: osdSurface.item ? (osdSurface.item as Window).contentItem : session
        visible: surfaceVisible
    }
    NotificationCenter {
        id: notifications; parent: notificationSurface.item ? (notificationSurface.item as Window).contentItem : session; live: true; sessionMode: true
        onHistoryOpenChanged: if (historyOpen) Qt.callLater(function() { if (notifications.historyOpen) if (session.notificationsWindow) session.notificationsWindow.requestActivate(); })
    }
    function reloadSettings() { Theme.reloadSettings(); }
    function closeMenus() { bar.closeMenu(); dock.closeMenu(); notifications.historyOpen = false; session.controlOpen = false; }
    // Invocado desde C++ (tecla Meta, Alt+Espacio) a través de D-Bus.
    function showApplications() { openLauncher(true); }
    function activateDockEntry(n) { return dock.activateEntry(n); }
    function toggleNotifications() {
        const wasOpen = notifications.historyOpen;
        closeMenus(); if (launcher) launcher.close(); session.launcherOpen = false;
        if (!wasOpen) notifications.toggle();
    }
    function toggleLauncher() { if (session.launcherOpen) launcher.close(); else openLauncher(false); }
    function openLauncher(apps = false) { closeMenus(); session.launcherOpen = true; launcher.open(apps); overlay.requestActivate(); focusTimer.restart(); }
    Timer { id: focusTimer; interval: 0; onTriggered: if (session.launcher && session.launcherOpen) session.launcher.focusInput() }
    function globalAction(component, name) { systemControls.globalAction(component, name); }
    function osdRequest(method, args) { osd.request(method, args); }
    function toggleControlCenter() {
        if (session.controlOpen) { session.controlOpen = false; return; }
        closeMenus(); if (launcher) launcher.close(); session.launcherOpen = false;
        session.controlOpen = true;
    }
    SystemControls { id: systemControls; onFeedback: (icon, percent, text) => osd.show(icon, percent, text) }
    Timer { id: controlFocus; interval: 0; onTriggered: if (session.controlPanel && session.controlOpen) session.controlPanel.forceActiveFocus() }
    Loader {
        id: osdSurface; objectName: "osdSurface"; active: osd.surfaceVisible
        sourceComponent: Component {
            Window {
                id: osdWindow
                transientParent: null; visible: true; width: 240; height: 44; color: "transparent"
                property bool singlrBlur: true
                property int singlrBlurRadius: 12
                flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowTransparentForInput
                LayerShell.Window.layer: LayerShell.Window.LayerOverlay
                LayerShell.Window.anchors: LayerShell.Window.AnchorBottom
                LayerShell.Window.margins.bottom: dockWindow.height + 30
                LayerShell.Window.exclusionZone: 0
                LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
                LayerShell.Window.scope: "on-screen-display"

            }
        }
    }
    Loader {
        id: controlSurface; objectName: "controlSurface"; active: session.controlMapped
        onLoaded: { (item as Window).requestActivate(); controlFocus.restart(); }
        sourceComponent: Component {
            Window {
                objectName: "controlCenterWindow"
                transientParent: null; visible: true; width: 340
                height: Math.min(screen.height - 64, session.controlPanel ? session.controlPanel.implicitHeight : 560); color: "transparent"
                property bool singlrBlur: true
                property int singlrBlurRadius: 12
                LayerShell.Window.layer: LayerShell.Window.LayerOverlay
                LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorRight
                LayerShell.Window.margins.top: 8
                LayerShell.Window.margins.right: 16
                LayerShell.Window.exclusionZone: 0
                LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
                LayerShell.Window.activateOnShow: true
                LayerShell.Window.scope: "utility"
                onActiveChanged: if (!active && visible) session.controlOpen = false

            }
        }
    }
    // --no-background: sobre una sesión Plasma real se conserva el fondo del usuario.
    readonly property bool showBackground: Qt.application.arguments.indexOf("--no-background") < 0
    Loader {
        id: backgroundSurface; objectName: "backgroundSurface"; active: session.showBackground
        sourceComponent: Component {
            Window {
                transientParent: null; visible: true; color: Theme.background
                LayerShell.Window.layer: LayerShell.Window.LayerBackground
                LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
                LayerShell.Window.exclusionZone: -1
                LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
                LayerShell.Window.scope: "desktop"
                Background { anchors.fill: parent; TapHandler { onTapped: session.closeMenus() } }
            }
        }
    }
    Window {
        transientParent: null; visible: true; height: 28; property bool singlrBlur: true; property int singlrBlurRadius: 0; color: "transparent"
        LayerShell.Window.layer: LayerShell.Window.LayerTop
        LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
        LayerShell.Window.exclusionZone: 28
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
        LayerShell.Window.scope: "dock"
        TopBar { id: bar; notificationsUnread: notifications.unread; onControlCenterRequested: session.toggleControlCenter(); onNotificationsRequested: session.toggleNotifications(); sessionMode: true; menuHost: barMenuSurface.item ? (barMenuSurface.item as Window).contentItem : null; trayMenuHost: trayMenuSurface.item ? (trayMenuSurface.item as Window).contentItem : null; width: parent.width; height: 28; activeAppName: dock.activeAppName; onLauncherRequested: session.openLauncher(); onApplicationsRequested: session.showApplications() }
        Shortcut { sequences: ["Meta+Space", "Alt+Space"]; onActivated: session.openLauncher() }
    }
    Window {
        id: dockWindow; transientParent: null; visible: true; width: dock.width; height: dock.height; property bool singlrBlur: true; property int singlrBlurRadius: 14; color: "transparent"
        LayerShell.Window.layer: LayerShell.Window.LayerTop  // Top: el dock queda por encima de las ventanas, como en macOS.
        LayerShell.Window.anchors: LayerShell.Window.AnchorBottom
        LayerShell.Window.margins.bottom: 10
        LayerShell.Window.exclusionZone: 58
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone  // None: un clic en el dock o la barra no debe quitar la actividad a la app de delante
        LayerShell.Window.scope: "dock"
        Dock { id: dock; objectName: "sessionDock"; sessionMode: true; menuHost: dockMenuSurface.item ? (dockMenuSurface.item as Window).contentItem : null; onLauncherRequested: session.openLauncher(); onApplicationsRequested: session.showApplications() }
        Shortcut { sequences: ["Meta+Space", "Alt+Space"]; onActivated: session.openLauncher() }
    }
    Loader {
        id: notificationSurface; objectName: "notificationSurface"; active: notifications.historyOpen || notifications.popups.length > 0
        sourceComponent: Component {
            Window {
                transientParent: null; visible: true
                width: 360; height: Math.max(1, notifications.height); color: "transparent"
                property bool singlrBlur: true
                property int singlrBlurRadius: 10
                LayerShell.Window.layer: LayerShell.Window.LayerOverlay
                LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorRight
                LayerShell.Window.margins.top: 12
                LayerShell.Window.margins.right: 16
                LayerShell.Window.exclusionZone: 0
                LayerShell.Window.keyboardInteractivity: notifications.historyOpen ? LayerShell.Window.KeyboardInteractivityOnDemand : LayerShell.Window.KeyboardInteractivityNone
                LayerShell.Window.scope: "notification"

            }
        }
    }
    // Tight, independent layer surfaces: never enlarge the dock's input region.
    Loader {
        id: dockMenuSurface; objectName: "dockMenuSurface"; active: dock.menuOpen
        sourceComponent: Component {
            Window {
                id: dockMenuWindow
                transientParent: null; visible: true; width: 240; height: dock.menuHeight; color: "transparent"
                LayerShell.Window.layer: LayerShell.Window.LayerTop
                LayerShell.Window.anchors: LayerShell.Window.AnchorBottom
                LayerShell.Window.margins.bottom: dockWindow.height + 18
                LayerShell.Window.exclusionZone: 0
                LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
                LayerShell.Window.scope: "utility"
                LayerShell.Window.activateOnShow: true
                onVisibleChanged: if (visible) { bar.closeMenu(); requestActivate(); }
                onActiveChanged: if (!active && visible) dock.closeMenu()
            }
        }
    }
    Loader {
        id: tooltipSurface; objectName: "tooltipSurface"; active: !!dock.tooltipText && !dock.menuOpen && !bar.menuOpen && !bar.tray.opened && !session.launcherOpen
        sourceComponent: Component {
            Window {
                id: tooltipWindow
                transientParent: null; visible: true
                width: Math.ceil(tooltipLabel.implicitWidth) + 16; height: Math.ceil(tooltipLabel.implicitHeight) + 16
                color: "transparent"; flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowTransparentForInput
                LayerShell.Window.layer: LayerShell.Window.LayerTop
                LayerShell.Window.anchors: LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft
                LayerShell.Window.margins.bottom: dockWindow.height + 18
                LayerShell.Window.margins.left: Math.round(Math.max(0, Math.min(screen.width - width, (screen.width - dock.width) / 2 + dock.tooltipCenter - width / 2)))
                LayerShell.Window.exclusionZone: 0
                LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
                LayerShell.Window.scope: "tooltip"
                Rectangle { anchors.fill: parent; radius: 8; color: Theme.surface; border.color: Theme.border }
                UiText { id: tooltipLabel; anchors.centerIn: parent; text: dock.tooltipText; font.pixelSize: 12 }
            }
        }
    }
    Loader {
        id: barMenuSurface; objectName: "barMenuSurface"; active: bar.menuOpen
        sourceComponent: Component {
            Window {
                id: barMenuWindow
                transientParent: null; visible: true; width: 220; height: 116; color: "transparent"
                LayerShell.Window.layer: LayerShell.Window.LayerTop
                LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorLeft
                // KWin already positions this surface below the topbar's exclusive zone.
                LayerShell.Window.margins.top: 4
                LayerShell.Window.margins.left: 16
                LayerShell.Window.exclusionZone: 0
                LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
                LayerShell.Window.scope: "utility"
                LayerShell.Window.activateOnShow: true
                onVisibleChanged: if (visible) { dock.closeMenu(); requestActivate(); }
                onActiveChanged: if (!active && visible) bar.closeMenu()
            }
        }
    }
    Loader {
        id: trayMenuSurface; objectName: "trayMenuSurface"; active: bar.tray.opened
        sourceComponent: Component {
            Window {
                id: trayMenuWindow
                transientParent: null; visible: true
                width: 240; height: bar.tray.menuHeight; color: "transparent"
                LayerShell.Window.layer: LayerShell.Window.LayerTop
                LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorLeft
                LayerShell.Window.margins.top: 4
                LayerShell.Window.margins.left: Math.round(Math.max(4, Math.min(screen.width - width - 4, bar.tray.menuX)))
                LayerShell.Window.exclusionZone: 0
                LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
                LayerShell.Window.scope: "utility"
                LayerShell.Window.activateOnShow: true
                onVisibleChanged: if (visible) { dock.closeMenu(); requestActivate(); }
                onActiveChanged: if (!active && visible) bar.tray.close()
            }
        }
    }
    Loader {
        id: trayTooltipSurface; objectName: "trayTooltipSurface"; active: !!bar.tray.tooltipText && !bar.tray.opened
        sourceComponent: Component {
            Window {
                transientParent: null; visible: true
                width: Math.ceil(trayTooltip.implicitWidth) + 16; height: 30; color: "transparent"
                flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowTransparentForInput
                LayerShell.Window.layer: LayerShell.Window.LayerTop
                LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorLeft
                LayerShell.Window.margins.top: 4
                LayerShell.Window.margins.left: Math.round(Math.max(4, Math.min(screen.width - width - 4, bar.tray.tooltipX - width / 2)))
                LayerShell.Window.exclusionZone: 0
                LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
                LayerShell.Window.scope: "tooltip"
                Rectangle { anchors.fill: parent; radius: 8; color: Theme.raised; border.color: Theme.border }
                UiText { id: trayTooltip; anchors.centerIn: parent; text: bar.tray.tooltipText; font.pixelSize: 12 }
            }
        }
    }
    Loader {
        id: launcherSurface; objectName: "launcherSurface"; active: session.launcherOpen
        sourceComponent: Component {
            Window {
                objectName: "launcherWindow"; transientParent: null; visible: true; color: "transparent"
                LayerShell.Window.layer: LayerShell.Window.LayerOverlay
                LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
                LayerShell.Window.exclusionZone: -1
                LayerShell.Window.keyboardInteractivity: visible ? LayerShell.Window.KeyboardInteractivityExclusive : LayerShell.Window.KeyboardInteractivityNone
                LayerShell.Window.scope: "utility"
                MouseArea { anchors.fill: parent; onClicked: if (session.launcher) session.launcher.close() }

            }
        }
    }
}
