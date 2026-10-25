pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell
import Singlr.Ui

// Owned by the screen Instantiator: removing an output releases its windows and menus.
Item {
    id: surfaces
    required property var outputScreen
    required property var controller
    property string activeAppName: "Escritorio"
    readonly property bool menuOpen: bar.menuOpen || bar.tray.opened || bar.keyboard.opened
    function closeMenus() { bar.closeMenu(); }
    function showSessionMenu() { bar.menuOpen = true; }
    // Coloca la superficie en su pantalla (ver SinglrSystem.placeOnScreen).
    function place(window) {
        // qmllint disable unqualified
        if (typeof SinglrSystem !== "undefined" && SinglrSystem.placeOnScreen && outputScreen)
            Qt.callLater(() => SinglrSystem.placeOnScreen(window, outputScreen.name));
        // qmllint enable unqualified
    }
    Loader {
        id: backgroundSurface; objectName: "backgroundSurface"; active: surfaces.controller.showBackground
        sourceComponent: Component {
            Window {
                Component.onCompleted: surfaces.place(this)
                screen: surfaces.outputScreen; transientParent: null; visible: true; color: Theme.background
                LayerShell.Window.layer: LayerShell.Window.LayerBackground
                LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
                LayerShell.Window.exclusionZone: -1
                LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
                LayerShell.Window.scope: "desktop"
                Background {
                    anchors.fill: parent
                    // The screen object goes away before this delegate when an output is removed.
                    pixelSize: surfaces.outputScreen ? Qt.size(Math.ceil(surfaces.outputScreen.width * surfaces.outputScreen.devicePixelRatio),
                                                               Math.ceil(surfaces.outputScreen.height * surfaces.outputScreen.devicePixelRatio))
                                                     : Qt.size(0, 0)
                    TapHandler { onTapped: surfaces.controller.closeMenus() }
                }
            }
        }
    }
    Window {
        Component.onCompleted: surfaces.place(this)
        screen: surfaces.outputScreen; transientParent: null; visible: true; height: 28; property bool singlrBlur: true; property int singlrBlurRadius: 0; color: "transparent"
        LayerShell.Window.layer: LayerShell.Window.LayerTop
        LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
        LayerShell.Window.exclusionZone: 28
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
        LayerShell.Window.scope: "dock"
        TopBar {
            id: bar; objectName: "screenTopBar"
            notificationsUnread: surfaces.controller.notificationCenter.unread
            onControlCenterRequested: surfaces.controller.toggleControlCenterOnScreen(surfaces.outputScreen)
            onNotificationsRequested: surfaces.controller.toggleNotificationsOnScreen(surfaces.outputScreen)
            sessionMode: true
            menuHost: barMenuSurface.item ? (barMenuSurface.item as Window).contentItem : null
            trayMenuHost: trayMenuSurface.item ? (trayMenuSurface.item as Window).contentItem : null
            width: parent.width; height: 28
            activeAppName: surfaces.activeAppName
            onLauncherRequested: surfaces.controller.openLauncher(false, surfaces.outputScreen)
            onApplicationsRequested: surfaces.controller.openLauncher(true, surfaces.outputScreen)
        }
    }
    Loader {
        id: barMenuSurface; objectName: "barMenuSurface"; active: bar.menuOpen
        sourceComponent: Component {
            Window {
                Component.onCompleted: surfaces.place(this)
                id: barMenuWindow
                screen: surfaces.outputScreen; transientParent: null; visible: true; width: bar.menuWidth; height: bar.menuHeight; color: "transparent"
                LayerShell.Window.layer: LayerShell.Window.LayerTop
                LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorLeft
                // KWin already positions this surface below the topbar's exclusive zone.
                LayerShell.Window.margins.top: 4
                LayerShell.Window.margins.left: 16
                LayerShell.Window.exclusionZone: 0
                LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
                LayerShell.Window.scope: "utility"
                LayerShell.Window.activateOnShow: true
                onVisibleChanged: if (visible) { surfaces.controller.closeDockMenu(); requestActivate(); }
                onActiveChanged: if (!active && visible) bar.closeMenu()
            }
        }
    }
    Loader {
        id: trayMenuSurface; objectName: "trayMenuSurface"; active: bar.tray.opened || bar.keyboard.opened
        sourceComponent: Component {
            Window {
                Component.onCompleted: surfaces.place(this)
                id: trayMenuWindow
                screen: surfaces.outputScreen; transientParent: null; visible: true
                width: 240; height: bar.keyboard.opened ? bar.keyboard.menuHeight : bar.tray.menuHeight; color: "transparent"
                LayerShell.Window.layer: LayerShell.Window.LayerTop
                LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorLeft
                LayerShell.Window.margins.top: 4
                LayerShell.Window.margins.left: Math.round(Math.max(4, Math.min(screen.width - width - 4, (bar.keyboard.opened ? bar.keyboard.menuX : bar.tray.menuX))))
                LayerShell.Window.exclusionZone: 0
                LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
                LayerShell.Window.scope: "utility"
                LayerShell.Window.activateOnShow: true
                onVisibleChanged: if (visible) { surfaces.controller.closeDockMenu(); requestActivate(); }
                onActiveChanged: if (!active && visible) { bar.tray.close(); bar.keyboard.close(); }
            }
        }
    }
    Loader {
        id: trayTooltipSurface; objectName: "trayTooltipSurface"; active: !!bar.tray.tooltipText && !bar.tray.opened
        sourceComponent: Component {
            Window {
                Component.onCompleted: surfaces.place(this)
                screen: surfaces.outputScreen; transientParent: null; visible: true
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
}
