pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQml.Models
import org.kde.layershell as LayerShell
import Singlr.Ui
// transientParent: null es imprescindible: si no, Qt ata cada Window a la ventana del
// Item contenedor (inexistente) y KWin nunca recibe la superficie layer-shell.
// LayerShell.Window.scope usa los nombres que KWin traduce a tipo de ventana (desktop, dock,
// notification, on-screen-display, tooltip, utility). Con nombres propios KWin las trata como
// ventanas normales: aparecen en la multitarea y en Alt+Tab.
Item {
    id: session
    // First entry is Qt's primary screen; dockScreen remains an overridable policy.
    property var screens: Qt.application.screens
    property var dockScreen: screens.length ? screens[0] : null
    readonly property var effectiveDockScreen: screens.indexOf(dockScreen) >= 0 ? dockScreen : (screens.length ? screens[0] : null)
    property var launcherScreen: effectiveDockScreen
    property var controlScreen: effectiveDockScreen
    property var historyScreen: effectiveDockScreen
    property bool notificationRemapping: false
    readonly property bool barMenuOpen: {
        let opened = false;
        for (let i = 0; i < screenSurfaces.count; ++i) {
            const surface = screenSurfaces.objectAt(i) as ScreenSurfaces;
            if (surface && surface.menuOpen) opened = true;
        }
        return opened;
    }
    onScreensChanged: {
        closeMenus();
        if (launcher) launcher.close();
        launcherOpen = false;
        launcherScreen = effectiveDockScreen;
        controlScreen = effectiveDockScreen;
        historyScreen = effectiveDockScreen;
    }
    Instantiator {
        id: screenSurfaces
        objectName: "screenSurfaces"
        model: session.screens
        delegate: ScreenSurfaces {
            required property var modelData
            outputScreen: modelData
            controller: session
            activeAppName: dock.activeAppName
        }
    }
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
        onHistoryOpenChanged: {
            // Recreate layer-shell routing both when opening history and returning to toasts.
            session.notificationRemapping = true;
            session.notificationRemapping = false;
            if (historyOpen) Qt.callLater(function() { if (notifications.historyOpen && session.notificationsWindow) session.notificationsWindow.requestActivate(); });
        }
    }
    function reloadSettings() { Theme.reloadSettings(); }
    function closeDockMenu() { dock.closeMenu(); }
    function closeBarMenus() {
        for (let i = 0; i < screenSurfaces.count; ++i) {
            const surface = screenSurfaces.objectAt(i) as ScreenSurfaces;
            if (surface) surface.closeMenus();
        }
    }
    function closeMenus() {
        closeBarMenus();
        dock.closeMenu();
        notifications.historyOpen = false;
        session.controlOpen = false;
    }
    // Invocado desde C++ (tecla Meta, Alt+Espacio) a través de D-Bus.
    function showApplications() { openLauncher(true); }
    function activateDockEntry(n) { return dock.activateEntry(n); }
    function toggleNotifications() { toggleNotificationsOnScreen(effectiveDockScreen); }
    function toggleNotificationsOnScreen(targetScreen) {
        const wasOpen = notifications.historyOpen && historyScreen === targetScreen;
        historyScreen = targetScreen;
        closeMenus(); if (launcher) launcher.close(); session.launcherOpen = false;
        if (!wasOpen) notifications.toggle();
    }
    function toggleLauncher() { if (session.launcherOpen) launcher.close(); else openLauncher(false); }
    function openLauncher(apps = false, targetScreen = effectiveDockScreen) { closeMenus(); if (launcherScreen !== targetScreen) session.launcherOpen = false; launcherScreen = targetScreen; session.launcherOpen = true; launcher.open(apps); overlay.requestActivate(); focusTimer.restart(); }
    Timer { id: focusTimer; interval: 0; onTriggered: if (session.launcher && session.launcherOpen) session.launcher.focusInput() }
    function globalAction(component, name) { systemControls.globalAction(component, name); }
    function osdRequest(method, args) { osd.request(method, args); }
    function toggleControlCenter() { toggleControlCenterOnScreen(effectiveDockScreen); }
    function toggleControlCenterOnScreen(targetScreen) {
        if (session.controlOpen && controlScreen === targetScreen) { session.controlOpen = false; return; }
        closeMenus(); if (launcher) launcher.close(); session.launcherOpen = false;
        controlScreen = targetScreen;
        session.controlOpen = true;
    }
    SystemControls { id: systemControls; onFeedback: (icon, percent, text) => osd.show(icon, percent, text) }
    Timer { id: controlFocus; interval: 0; onTriggered: if (session.controlPanel && session.controlOpen) session.controlPanel.forceActiveFocus() }
    Loader {
        id: osdSurface; objectName: "osdSurface"; active: osd.surfaceVisible
        sourceComponent: Component {
            Window {
                screen: session.effectiveDockScreen
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
                screen: session.controlScreen
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
    Window {
        screen: session.effectiveDockScreen
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
        id: notificationSurface; objectName: "notificationSurface"; active: !session.notificationRemapping && (notifications.historyOpen || notifications.popups.length > 0)
        sourceComponent: Component {
            Window {
                transientParent: null; visible: true
                screen: session.notificationCenter.historyOpen ? session.historyScreen : session.effectiveDockScreen
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
                screen: session.effectiveDockScreen
                id: dockMenuWindow
                transientParent: null; visible: true; width: 240; height: dock.menuHeight; color: "transparent"
                LayerShell.Window.layer: LayerShell.Window.LayerTop
                LayerShell.Window.anchors: LayerShell.Window.AnchorBottom
                LayerShell.Window.margins.bottom: dockWindow.height + 18
                LayerShell.Window.exclusionZone: 0
                LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
                LayerShell.Window.scope: "utility"
                LayerShell.Window.activateOnShow: true
                onVisibleChanged: if (visible) { session.closeBarMenus(); requestActivate(); }
                onActiveChanged: if (!active && visible) dock.closeMenu()
            }
        }
    }
    Loader {
        id: tooltipSurface; objectName: "tooltipSurface"; active: !!dock.tooltipText && !dock.menuOpen && !session.barMenuOpen && !session.launcherOpen
        sourceComponent: Component {
            Window {
                screen: session.effectiveDockScreen
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
        id: launcherSurface; objectName: "launcherSurface"; active: session.launcherOpen
        sourceComponent: Component {
            Window {
                screen: session.launcherScreen
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
