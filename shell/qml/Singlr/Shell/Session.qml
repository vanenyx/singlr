pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell
import Singlr.Ui
// transientParent: null es imprescindible: si no, Qt ata cada Window a la ventana del
// Item contenedor (inexistente) y KWin nunca recibe la superficie layer-shell.
Item {
    id: session
    function openLauncher(apps = false) { overlay.visible = true; launcher.open(apps); overlay.requestActivate(); focusTimer.restart(); }
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
        Background { anchors.fill: parent }
    }
    Window {
        transientParent: null; visible: true; height: 28; property bool singlrBlur: true; property int singlrBlurRadius: 0; color: "transparent"
        LayerShell.Window.layer: LayerShell.Window.LayerTop
        LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
        LayerShell.Window.exclusionZone: 28
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
        LayerShell.Window.scope: "singlr-topbar"
        TopBar { id: bar; sessionMode: true; width: parent.width; height: 28; activeAppName: dock.activeAppName; onLauncherRequested: session.openLauncher(); onApplicationsRequested: session.openLauncher(true) }
        Shortcut { sequences: ["Meta+Space", "Alt+Space"]; onActivated: session.openLauncher() }
    }
    Window {
        transientParent: null; visible: true; width: dock.width; height: dock.height; property bool singlrBlur: true; property int singlrBlurRadius: 14; color: "transparent"
        LayerShell.Window.layer: LayerShell.Window.LayerBottom
        LayerShell.Window.anchors: LayerShell.Window.AnchorBottom
        LayerShell.Window.margins.bottom: 10
        LayerShell.Window.exclusionZone: 0
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
        LayerShell.Window.scope: "singlr-dock"
        Dock { id: dock; sessionMode: true; onLauncherRequested: session.openLauncher(); onApplicationsRequested: session.openLauncher(true) }
        Shortcut { sequences: ["Meta+Space", "Alt+Space"]; onActivated: session.openLauncher() }
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
