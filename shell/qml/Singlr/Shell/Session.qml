pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell
import Singlr.Ui
// transientParent: null es imprescindible: si no, Qt ata cada Window a la ventana del
// Item contenedor (inexistente) y KWin nunca recibe la superficie layer-shell.
Item {
    id: session
    function openLauncher() { overlay.visible = true; launcher.open(); overlay.requestActivate(); }
    Window {
        transientParent: null; visible: true; color: Theme.background
        LayerShell.Window.layer: LayerShell.Window.LayerBackground
        LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
        LayerShell.Window.exclusionZone: -1
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
        LayerShell.Window.scope: "singlr-background"
        Background { anchors.fill: parent }
    }
    Window {
        transientParent: null; visible: true; height: bar.menuOpen ? 90 : 38; color: "transparent"
        LayerShell.Window.layer: LayerShell.Window.LayerTop
        LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
        LayerShell.Window.exclusionZone: 38
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
        LayerShell.Window.scope: "singlr-topbar"
        TopBar { id: bar; width: parent.width; height: 38; onLauncherRequested: session.openLauncher() }
        Shortcut { sequences: ["Meta+Space", "Alt+Space"]; onActivated: session.openLauncher() }
    }
    Window {
        transientParent: null; visible: true; width: dock.width; height: 78; color: "transparent"
        LayerShell.Window.layer: LayerShell.Window.LayerBottom
        LayerShell.Window.anchors: LayerShell.Window.AnchorBottom
        LayerShell.Window.exclusionZone: 0
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
        LayerShell.Window.scope: "singlr-dock"
        Dock { id: dock; onLauncherRequested: session.openLauncher() }
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
            id: launcher; x: (parent.width-width)/2; y: Math.min(286,(parent.height-height)/2)
            onClosed: overlay.visible = false
        }
    }
}
