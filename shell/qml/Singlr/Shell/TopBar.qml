pragma ComponentBehavior: Bound
import QtQuick
import Singlr.Ui
Rectangle {
    id: bar
    readonly property var menu: menuLoader.item
    readonly property real menuHeight: menu ? menu.entriesHeight : 249
    readonly property real menuWidth: 292
    property bool sessionMode: false
    property var closeController: null
    property Item menuHost: null
    function closeMenu() { menuOpen = false; systemTray.close(); }
    property alias tray: systemTray
    property Item trayMenuHost: null
    property bool notificationsUnread: false
    signal controlCenterRequested()
    signal notificationsRequested()
    signal launcherRequested()
    signal applicationsRequested()
    property string activeAppName: "Escritorio"
    property bool menuOpen: false
    property date now: new Date()
    implicitHeight: 28
    color: Theme.barSurface
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
    Timer {
        id: minuteClock
        interval: 60000 - (Date.now() % 60000)
        running: bar.visible
        onTriggered: { bar.now = new Date(); interval = 60000 - (Date.now() % 60000); restart(); }
    }
    Row { x: 16; height: 28; spacing: 8
        Tool { objectName: "sessionRing"; y: 3; width: 24; height: 22; icon: "circle"; iconSize: 14; description: "Menú Singlr"; onClicked: bar.menuOpen = !bar.menuOpen }
        UiText { height: 28; width: Math.min(360, bar.width-trailing.width-100); text: bar.activeAppName; weight: 590 }
    }
    Row {
        id: trailing; anchors.right: parent.right; anchors.rightMargin: 16; height: 28; spacing: 14
        SystemTray { id: systemTray; menuHost: bar.trayMenuHost; onOpenedChanged: if (opened) bar.menuOpen = false }
        Tool {
            y: 3; width: 24; height: 22; icon: "bell"; iconSize: 15; description: "Notificaciones"
            onClicked: bar.notificationsRequested()
            Rectangle { x: 18; y: 3; width: 4; height: 4; radius: 2; color: Theme.secondary; visible: bar.notificationsUnread }
        }
        Tool { y: 3; width: 24; height: 22; icon: "magnifying-glass"; iconSize: 15; description: "Buscar"; onClicked: bar.launcherRequested() }
        StatusIndicators { anchors.verticalCenter: parent.verticalCenter; onControlCenterRequested: bar.controlCenterRequested() }
        UiText { height: 28; text: bar.now.toLocaleString(Qt.locale("es_ES"), "ddd d MMM  HH:mm"); weight: 510; color: Theme.secondary }
    }
    DeferredLoader {
        onLoaded: if (bar.menuOpen) bar.menu.forceActiveFocus()
        id: menuLoader; objectName: "TopBarMenuLoader"; opened: bar.menuOpen
        sourceComponent: Component {
            SessionMenu {
                id: menu
                sessionMode: bar.sessionMode
                closeController: bar.closeController || localCloseController
                SessionCloseController { id: localCloseController; sessionMode: bar.sessionMode && !bar.closeController }
                visible: bar.menuOpen
                onClosed: bar.menuOpen = false
                onAboutToShow: systemTray.close()
                parent: bar.menuHost || bar
                x: bar.menuHost ? 0 : 16
                y: bar.menuHost ? 0 : 32
            }
        }
    }
}
