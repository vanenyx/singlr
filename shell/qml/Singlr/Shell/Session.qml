pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQml.Models
import org.kde.layershell as LayerShell
import Singlr.Ui
import Singlr.System
// transientParent: null es imprescindible: si no, Qt ata cada Window a la ventana del
// Item contenedor (inexistente) y KWin nunca recibe la superficie layer-shell.
// LayerShell.Window.scope usa los nombres que KWin traduce a tipo de ventana (desktop, dock,
// notification, on-screen-display, tooltip, utility). Con nombres propios KWin las trata como
// ventanas normales: aparecen en la multitarea y en Alt+Tab.
Item {
    id: session
    Component.onCompleted: { WorkspaceBridge.enable(); ClipboardPasteBridge.enable(); }
    Connections {
        target: WorkspaceBridge
        function onOverviewChanged(open) { session.overviewOpen = open; }
        function onSearchRequested(text, screenName) {
            const screen = session.screens.find(s => s.name === screenName) || session.effectiveDockScreen;
            session.openLauncher(false, screen);
            session.launcher.query = text;
        }
    }
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
        Qt.callLater(placeDock);
        closeMenus();
        if (launcher) launcher.close();
        launcherOpen = false;
        launcherScreen = effectiveDockScreen;
        controlScreen = effectiveDockScreen;
        historyScreen = effectiveDockScreen;
        clipboardScreen = effectiveDockScreen;
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
    // qmllint disable unqualified
    property var systemBridge: typeof SinglrSystem !== "undefined" ? SinglrSystem : null
    // qmllint enable unqualified
    function reportSessionCancellation(action) {
        const verb = action === "logout" ? "Cerrar sesión" : action === "reboot" ? "Reiniciar" : "Apagar";
        notifications.localEntries = notifications.localEntries.concat([{
            id: notifications.localId--, local: true, app: "Singlr", icon: "dialog-warning",
            title: verb + ": cancelado por una aplicación", body: "", time: new Date(), timeout: 5000,
            critical: false, expired: false, dismissed: false, suppressed: false, defaultAction: false,
            actionNames: [], actionLabels: []
        }]);
    }
    Connections {
        target: session.systemBridge
        function onSessionActionCancelled(action: string) { session.reportSessionCancellation(action); }
    }
    ClipboardBackend { id: clipboardBackend; objectName: "clipboardBackend" }
    property bool clipboardOpen: false
    onClipboardOpenChanged: if (!clipboardOpen) ClipboardPasteBridge.cancelIfIdle()
    Connections {
        target: ClipboardPasteBridge
        function onFailed(message) { notifications.notifyLocal(message); }
    }
    readonly property var clipboardPanel: clipboardContent.item
    property var clipboardScreen: effectiveDockScreen
    function toggleClipboard() {
        const wasOpen = clipboardOpen;
        if (!wasOpen) ClipboardPasteBridge.captureTarget();
        closeMenus(); if (launcher) launcher.close(); launcherOpen = false;
        clipboardScreen = effectiveDockScreen;
        clipboardOpen = !wasOpen;
        if (clipboardOpen) { clipboardPanel.open(); clipboardFocus.restart(); }
    }
    Timer { id: clipboardFocus; interval: 0; onTriggered: if (session.clipboardOpen) session.clipboardPanel.focusInput() }
    DeferredLoader {
        id: clipboardContent; objectName: "clipboardLoader"; opened: session.clipboardOpen
        Component.onCompleted: setSource(Qt.resolvedUrl("ClipboardPanel.qml"), {history: clipboardBackend.history, pasteBridge: ClipboardPasteBridge})
        onLoaded: {
            const panel = item as Item;
            panel.parent = Qt.binding(() => clipboardSurface.item ? (clipboardSurface.item as Window).contentItem : session);
            panel.visible = Qt.binding(() => session.clipboardOpen);
        }
    }
    Connections { target: clipboardContent.item; function onClosed() { session.clipboardOpen = false; } }
    Loader {
        id: clipboardSurface; objectName: "clipboardSurface"; active: session.clipboardOpen
        onLoaded: (item as Window).requestActivate()
        sourceComponent: Component {
            Window {
                screen: session.clipboardScreen
                transientParent: null; visible: true; width: 760; height: 542; color: "transparent"
                property bool singlrBlur: Theme.translucent
                property real singlrBlurRadius: 12
                LayerShell.Window.layer: LayerShell.Window.LayerOverlay
                LayerShell.Window.anchors: LayerShell.Window.AnchorNone
                LayerShell.Window.exclusionZone: 0
                LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
                LayerShell.Window.activateOnShow: true
                LayerShell.Window.scope: "utility"
                onActiveChanged: if (!active && visible) session.clipboardOpen = false
            }
        }
    }
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
            panel.dockController = dock;
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
    function closePanels() { closeMenus(); if (launcher) launcher.close(); launcherOpen = false; }
    function closeDockMenu() { dock.closeMenu(); }
    function closeBarMenus() {
        for (let i = 0; i < screenSurfaces.count; ++i) {
            const surface = screenSurfaces.objectAt(i) as ScreenSurfaces;
            if (surface) surface.closeMenus();
        }
    }
    function closeMenus() {
        dockKeyboard = false;
        session.clipboardOpen = false;
        closeBarMenus();
        dock.closeMenu();
        notifications.historyOpen = false;
        session.controlOpen = false;
    }
    // Invocado desde C++ (tecla Meta, Alt+Espacio) a través de D-Bus.
    function showApplications() { openLauncher(true); }
    property bool overviewOpen: false
    property bool dockKeyboard: false
    function focusDock() {
        closeMenus(); if (launcher) launcher.close(); launcherOpen = false;
        dockKeyboard = true;
        Qt.callLater(() => { if (session.dockKeyboard) { dockWindow.requestActivate(); dock.focusFirst(); } });
    }
    function showSessionMenu() {
        closeMenus();
        if (launcher) launcher.close(); launcherOpen = false;
        const surface = screenSurfaces.objectAt(0) as ScreenSurfaces;
        if (surface) surface.showSessionMenu();
    }
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
    Timer { id: controlFocus; interval: 0; onTriggered: if (session.controlPanel && session.controlOpen) session.controlPanel.focusFirst() }
    Loader {
        id: osdSurface; objectName: "osdSurface"; active: osd.surfaceVisible
        sourceComponent: Component {
            Window {
                screen: session.effectiveDockScreen
                id: osdWindow
                transientParent: null; visible: true; width: 240; height: 44; color: "transparent"
                property bool singlrBlur: Theme.translucent
                property real singlrBlurRadius: 12
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
                property bool singlrBlur: Theme.translucent
                property real singlrBlurRadius: 12
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
    // The dock lives for the whole session, unlike the per-screen surfaces. A
    // layer surface stays on the output it was created for and closes with it
    // (resume, unplug), so re-create it on the dock screen whenever outputs change.
    function placeDock() {
        // qmllint disable unqualified
        if (!effectiveDockScreen || typeof SinglrSystem === "undefined" || !SinglrSystem.placeOnScreen) return;
        SinglrSystem.placeOnScreen(dockWindow, effectiveDockScreen.name);
        // qmllint enable unqualified
        dock.reveal();
        if (edgeSurface.item && systemBridge && systemBridge.placeOnScreen) systemBridge.placeOnScreen(edgeSurface.item, effectiveDockScreen.name);
    }
    Window {
        screen: session.effectiveDockScreen
        id: dockWindow; objectName: "dockWindow"; transientParent: null; visible: dock.shown; width: dock.width; height: dock.height; property bool singlrBlur: Theme.translucent; property real singlrBlurRadius: dock.radius; color: "transparent"
        LayerShell.Window.layer: LayerShell.Window.LayerTop  // Top: el dock queda por encima de las ventanas, como en macOS.
        LayerShell.Window.anchors: dock.fixed ? LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight : LayerShell.Window.AnchorBottom
        LayerShell.Window.margins.bottom: dock.bottomMargin
        LayerShell.Window.exclusionZone: dock.exclusionZone
        onActiveChanged: if (!active) session.dockKeyboard = false
        LayerShell.Window.keyboardInteractivity: session.dockKeyboard ? LayerShell.Window.KeyboardInteractivityOnDemand : LayerShell.Window.KeyboardInteractivityNone  // None: un clic en el dock o la barra no debe quitar la actividad a la app de delante
        LayerShell.Window.scope: "dock"
        Dock { Keys.onEscapePressed: session.dockKeyboard = false; id: dock; objectName: "sessionDock"; sessionMode: true; screenWidth: dockWindow.screen ? dockWindow.screen.width : 1; keyboardHeld: session.dockKeyboard; launcherHeld: session.launcherOpen || session.overviewOpen; menuHost: dockMenuSurface.item ? (dockMenuSurface.item as Window).contentItem : null; onLauncherRequested: session.openLauncher(); onApplicationsRequested: session.showApplications() }
        Shortcut { sequences: ["Meta+Space", "Alt+Space"]; onActivated: session.openLauncher() }
    }
    // A minimal native edge target: no polling, pointer warps or KWin script.
    // Full-width target also accepts file drags before a destination is known.
    Loader {
        id: edgeSurface; objectName: "dockEdgeSurface"; active: dock.autoHide
        sourceComponent: Component {
            Window {
                screen: session.effectiveDockScreen
                transientParent: null; visible: true; color: "transparent"
                width: screen ? screen.width : 1; height: 2
                LayerShell.Window.layer: LayerShell.Window.LayerOverlay
                LayerShell.Window.anchors: LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
                LayerShell.Window.exclusionZone: 0
                LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
                LayerShell.Window.scope: "dock"
                HoverHandler {
                    onHoveredChanged: {
                        dock.edgeHovered = hovered;
                        if (hovered) dock.reveal();
                    }
                }
                DropArea {
                    anchors.fill: parent
                    onEntered: event => { event.accepted = event.hasUrls; if (event.hasUrls) { dock.edgeHovered = true; dock.reveal(); } }
                    onExited: dock.edgeHovered = false
                    onDropped: dock.edgeHovered = false
                }
                onVisibleChanged: if (!visible) dock.edgeHovered = false
                Component.onDestruction: dock.edgeHovered = false
            }
        }
    }
    Loader {
        id: notificationSurface; objectName: "notificationSurface"; active: !session.notificationRemapping && (notifications.historyOpen || notifications.popups.length > 0)
        sourceComponent: Component {
            Window {
                transientParent: null; visible: true
                screen: session.notificationCenter.historyOpen ? session.historyScreen : session.effectiveDockScreen
                width: 360; height: Math.max(1, notifications.height); color: "transparent"
                property bool singlrBlur: Theme.translucent
                property real singlrBlurRadius: 10
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
                property bool singlrBlur: Theme.translucent
                property real singlrBlurRadius: 8
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
                property bool singlrBlur: Theme.translucent
                property real singlrBlurRadius: 8
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
                Rectangle { anchors.fill: parent; radius: 8; color: Theme.surface; border.color: Theme.surfaceBorder }
                UiText { id: tooltipLabel; anchors.centerIn: parent; text: dock.tooltipText; font.pixelSize: 12 }
            }
        }
    }
    Loader {
        id: launcherSurface; objectName: "launcherSurface"; active: session.launcherOpen
        sourceComponent: Component {
            Window {
                screen: session.launcherScreen
                property bool singlrBlur: Theme.translucent
                property real singlrBlurRadius: 12
                property rect singlrBlurRect: session.launcher ? Qt.rect(session.launcher.x, session.launcher.y, session.launcher.width, session.launcher.height) : Qt.rect(0,0,0,0)
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
