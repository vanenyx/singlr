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
    function closeMenus() { bar.closeMenu(); dock.closeMenu(); notifications.historyOpen = false; controlWindow.visible = false; }
    // Invocado desde C++ (tecla Meta, Alt+Espacio) a través de D-Bus.
    function toggleLauncher() { if (overlay.visible) launcher.close(); else openLauncher(false); }
    function openLauncher(apps = false) { closeMenus(); overlay.visible = true; launcher.open(apps); overlay.requestActivate(); focusTimer.restart(); }
    Timer { id: focusTimer; interval: 0; onTriggered: launcher.focusInput() }
    function globalAction(component, name) { systemControls.globalAction(component, name); }
    function osdRequest(method, args) { osd.request(method, args); }
    function toggleControlCenter() {
        if (controlWindow.visible) { controlWindow.visible = false; return; }
        closeMenus(); launcher.close(); overlay.visible = false;
        controlWindow.visible = true;
        controlWindow.requestActivate();
        controlFocus.restart();
    }
    SystemControls { id: systemControls; onFeedback: (icon, percent, text) => osd.show(icon, percent, text) }
    Timer { id: controlFocus; interval: 0; onTriggered: controlPanel.forceActiveFocus() }
    Window {
        id: osdWindow
        transientParent: null; visible: osd.surfaceVisible; width: 240; height: 44; color: "transparent"
        property bool singlrBlur: true
        property int singlrBlurRadius: 12
        flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowTransparentForInput
        LayerShell.Window.layer: LayerShell.Window.LayerOverlay
        LayerShell.Window.anchors: LayerShell.Window.AnchorBottom
        LayerShell.Window.margins.bottom: dockWindow.height + 30
        LayerShell.Window.exclusionZone: 0
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
        LayerShell.Window.scope: "on-screen-display"
        OnScreenDisplay { id: osd; anchors.fill: parent }
    }
    Window {
        id: controlWindow
        transientParent: null; visible: false; width: 340
        height: Math.min(screen.height - 64, controlPanel.implicitHeight); color: "transparent"
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
        onActiveChanged: if (!active && visible) visible = false
        ControlCenter { id: controlPanel; anchors.fill: parent; audio: systemControls; opened: controlWindow.visible; notifications: session.notificationCenter; onClosed: controlWindow.visible = false
            onOpenRequested: {
                if (!controlWindow.visible) session.toggleControlCenter();
                controlFocus.stop();
                controlWindow.requestActivate();
            }
        }
    }
    // --no-background: sobre una sesión Plasma real se conserva el fondo del usuario.
    readonly property bool showBackground: Qt.application.arguments.indexOf("--no-background") < 0
    Window {
        transientParent: null; visible: session.showBackground; color: Theme.background
        LayerShell.Window.layer: LayerShell.Window.LayerBackground
        LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
        LayerShell.Window.exclusionZone: -1
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
        LayerShell.Window.scope: "desktop"
        Background { anchors.fill: parent; TapHandler { onTapped: session.closeMenus() } }
    }
    Window {
        transientParent: null; visible: true; height: 28; property bool singlrBlur: true; property int singlrBlurRadius: 0; color: "transparent"
        LayerShell.Window.layer: LayerShell.Window.LayerTop
        LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
        LayerShell.Window.exclusionZone: 28
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
        LayerShell.Window.scope: "dock"
        TopBar { id: bar; notificationsUnread: notifications.unread; onControlCenterRequested: session.toggleControlCenter(); onNotificationsRequested: { controlWindow.visible = false; bar.closeMenu(); dock.closeMenu(); notifications.toggle(); } sessionMode: true; menuHost: barMenuHost; trayMenuHost: traySurfaceHost; width: parent.width; height: 28; activeAppName: dock.activeAppName; onLauncherRequested: session.openLauncher(); onApplicationsRequested: session.openLauncher(true) }
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
        Dock { id: dock; sessionMode: true; menuHost: dockMenuHost; onLauncherRequested: session.openLauncher(); onApplicationsRequested: session.openLauncher(true) }
        Shortcut { sequences: ["Meta+Space", "Alt+Space"]; onActivated: session.openLauncher() }
    }
    Window {
        id: notificationsWindow
        transientParent: null; visible: notifications.historyOpen || notifications.popups.length > 0
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
        NotificationCenter {
            id: notifications; live: true; sessionMode: true
            onHistoryOpenChanged: if (historyOpen) Qt.callLater(function() { if (notifications.historyOpen) notificationsWindow.requestActivate(); })
        }
    }
    // Tight, independent layer surfaces: never enlarge the dock's input region.
    Window {
        id: dockMenuWindow
        transientParent: null; visible: dock.menuOpen; width: 240; height: dock.menuHeight; color: "transparent"
        LayerShell.Window.layer: LayerShell.Window.LayerTop
        LayerShell.Window.anchors: LayerShell.Window.AnchorBottom
        LayerShell.Window.margins.bottom: dockWindow.height + 18
        LayerShell.Window.exclusionZone: 0
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
        LayerShell.Window.scope: "utility"
        LayerShell.Window.activateOnShow: true
        onVisibleChanged: if (visible) { bar.closeMenu(); requestActivate(); }
        onActiveChanged: if (!active && visible) dock.closeMenu()
        Item { id: dockMenuHost; anchors.fill: parent }
    }
    Window {
        id: tooltipWindow
        transientParent: null; visible: !!dock.tooltipText && !dock.menuOpen && !bar.menuOpen && !bar.tray.opened && !overlay.visible
        width: Math.ceil(tooltipLabel.implicitWidth) + 16; height: Math.ceil(tooltipLabel.implicitHeight) + 16
        color: "transparent"; flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowTransparentForInput
        LayerShell.Window.layer: LayerShell.Window.LayerTop
        LayerShell.Window.anchors: LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft
        LayerShell.Window.margins.bottom: dockWindow.height + 18
        LayerShell.Window.margins.left: Math.round(Math.max(0, Math.min(screen.width - width, (screen.width - dock.width) / 2 + dock.tooltipCenter - width / 2)))
        LayerShell.Window.exclusionZone: 0
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
        LayerShell.Window.scope: "tooltip"
        Rectangle { anchors.fill: parent; radius: 8; color: "#ef191a1b"; border.color: Theme.border }
        UiText { id: tooltipLabel; anchors.centerIn: parent; text: dock.tooltipText; font.pixelSize: 12 }
    }
    Window {
        id: barMenuWindow
        transientParent: null; visible: bar.menuOpen; width: 220; height: 80; color: "transparent"
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
        Item { id: barMenuHost; anchors.fill: parent }
    }
    Window {
        id: trayMenuWindow
        transientParent: null; visible: bar.tray.opened
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
        Item { id: traySurfaceHost; anchors.fill: parent }
    }
    Window {
        transientParent: null; visible: !!bar.tray.tooltipText && !bar.tray.opened
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
    Window {
        id: overlay; transientParent: null; visible: false; color: "transparent"
        LayerShell.Window.layer: LayerShell.Window.LayerOverlay
        LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
        LayerShell.Window.exclusionZone: -1
        LayerShell.Window.keyboardInteractivity: visible ? LayerShell.Window.KeyboardInteractivityExclusive : LayerShell.Window.KeyboardInteractivityNone
        LayerShell.Window.scope: "utility"
        MouseArea { anchors.fill: parent; onClicked: launcher.close() }
        Launcher {
            id: launcher; visible: false; sessionMode: true; x: (parent.width-width)/2; y: Math.min(286,(parent.height-height)/2)
            onClosed: overlay.visible = false
        }
    }
}
