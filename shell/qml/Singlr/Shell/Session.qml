pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell
import Singlr.Ui
// transientParent: null es imprescindible: si no, Qt ata cada Window a la ventana del
// Item contenedor (inexistente) y KWin nunca recibe la superficie layer-shell.
Item {
    id: session
    function closeMenus() { bar.closeMenu(); dock.closeMenu(); }
    // Invocado desde C++ (tecla Meta, Alt+Espacio) a través de D-Bus.
    function toggleLauncher() { if (overlay.visible) launcher.close(); else openLauncher(false); }
    function openLauncher(apps = false) { closeMenus(); overlay.visible = true; launcher.open(apps); overlay.requestActivate(); focusTimer.restart(); }
    Timer { id: focusTimer; interval: 0; onTriggered: launcher.focusInput() }
    // --no-background: sobre una sesión Plasma real se conserva el fondo del usuario.
    readonly property bool showBackground: Qt.application.arguments.indexOf("--no-background") < 0
    Window {
        transientParent: null; visible: session.showBackground; color: Theme.background
        LayerShell.Window.layer: LayerShell.Window.LayerBackground
        LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
        LayerShell.Window.exclusionZone: -1
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
        LayerShell.Window.scope: "singlr-background"
        Background { anchors.fill: parent; TapHandler { onTapped: session.closeMenus() } }
    }
    Window {
        transientParent: null; visible: true; height: 28; property bool singlrBlur: true; property int singlrBlurRadius: 0; color: "transparent"
        LayerShell.Window.layer: LayerShell.Window.LayerTop
        LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
        LayerShell.Window.exclusionZone: 28
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
        LayerShell.Window.scope: "singlr-topbar"
        TopBar { id: bar; sessionMode: true; menuHost: barMenuHost; width: parent.width; height: 28; activeAppName: dock.activeAppName; onLauncherRequested: session.openLauncher(); onApplicationsRequested: session.openLauncher(true) }
        Shortcut { sequences: ["Meta+Space", "Alt+Space"]; onActivated: session.openLauncher() }
    }
    Window {
        id: dockWindow; transientParent: null; visible: true; width: dock.width; height: dock.height; property bool singlrBlur: true; property int singlrBlurRadius: 14; color: "transparent"
        LayerShell.Window.layer: LayerShell.Window.LayerTop  // Top: el dock queda por encima de las ventanas, como en macOS.
        LayerShell.Window.anchors: LayerShell.Window.AnchorBottom
        LayerShell.Window.margins.bottom: 10
        LayerShell.Window.exclusionZone: 58
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone  // None: un clic en el dock o la barra no debe quitar la actividad a la app de delante
        LayerShell.Window.scope: "singlr-dock"
        Dock { id: dock; sessionMode: true; menuHost: dockMenuHost; onLauncherRequested: session.openLauncher(); onApplicationsRequested: session.openLauncher(true) }
        Shortcut { sequences: ["Meta+Space", "Alt+Space"]; onActivated: session.openLauncher() }
    }
    // Tight, independent layer surfaces: never enlarge the dock's input region.
    Window {
        id: dockMenuWindow
        transientParent: null; visible: dock.menuOpen; width: 260; height: dock.menuHeight; color: "transparent"
        LayerShell.Window.layer: LayerShell.Window.LayerTop
        LayerShell.Window.anchors: LayerShell.Window.AnchorBottom
        LayerShell.Window.margins.bottom: dockWindow.height + 18
        LayerShell.Window.exclusionZone: 0
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
        LayerShell.Window.scope: "singlr-dock-menu"
        LayerShell.Window.activateOnShow: true
        onVisibleChanged: if (visible) { bar.closeMenu(); requestActivate(); }
        onActiveChanged: if (!active && visible) dock.closeMenu()
        Item { id: dockMenuHost; anchors.fill: parent }
    }
    Window {
        id: tooltipWindow
        transientParent: null; visible: !!dock.tooltipText && !dock.menuOpen && !bar.menuOpen && !overlay.visible
        width: Math.ceil(tooltipLabel.implicitWidth) + 16; height: Math.ceil(tooltipLabel.implicitHeight) + 16
        color: "transparent"; flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowTransparentForInput
        LayerShell.Window.layer: LayerShell.Window.LayerTop
        LayerShell.Window.anchors: LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft
        LayerShell.Window.margins.bottom: dockWindow.height + 18
        LayerShell.Window.margins.left: Math.round(Math.max(0, Math.min(screen.width - width, (screen.width - dock.width) / 2 + dock.tooltipCenter - width / 2)))
        LayerShell.Window.exclusionZone: 0
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
        LayerShell.Window.scope: "singlr-dock-tooltip"
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
        LayerShell.Window.scope: "singlr-topbar-menu"
        LayerShell.Window.activateOnShow: true
        onVisibleChanged: if (visible) { dock.closeMenu(); requestActivate(); }
        onActiveChanged: if (!active && visible) bar.closeMenu()
        Item { id: barMenuHost; anchors.fill: parent }
    }
    Window {
        id: overlay; transientParent: null; visible: false; color: "transparent"
        LayerShell.Window.layer: LayerShell.Window.LayerOverlay
        LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
        LayerShell.Window.exclusionZone: -1
        LayerShell.Window.keyboardInteractivity: visible ? LayerShell.Window.KeyboardInteractivityExclusive : LayerShell.Window.KeyboardInteractivityNone
        LayerShell.Window.scope: "singlr-launcher"
        MouseArea { anchors.fill: parent; onClicked: launcher.close() }
        Launcher {
            id: launcher; visible: false; sessionMode: true; x: (parent.width-width)/2; y: Math.min(286,(parent.height-height)/2)
            onClosed: overlay.visible = false
        }
    }
}
