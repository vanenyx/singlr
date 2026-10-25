pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import Singlr.Ui
import org.kde.plasma.private.kicker as Kicker
Rectangle {
    id: bar
    readonly property var menu: menuLoader.item
    property bool sessionMode: false
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
        Tool { y: 3; width: 24; height: 22; icon: "circle"; iconSize: 14; description: "Menú Singlr"; onClicked: bar.menuOpen = !bar.menuOpen }
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
        onLoaded: if (bar.menuOpen) (item as Controls.Popup).forceActiveFocus()
        id: menuLoader; objectName: "TopBarMenuLoader"; opened: bar.menuOpen
        sourceComponent: Component {
            Controls.Popup {
                Kicker.SimpleFavoritesModel { id: singlrSettings; favorites: ["singlr-settings.desktop"] }
                id: menu; visible: bar.menuOpen; onClosed: bar.menuOpen = false; onAboutToShow: systemTray.close(); parent: bar.menuHost || bar; x: bar.menuHost ? 0 : 16; y: bar.menuHost ? 0 : 32; width: 220; height: 116; padding: 4; focus: true
                popupType: Controls.Popup.Item
                closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
                background: Rectangle { radius: 8; color: Theme.raised; border.color: Theme.border }
                contentItem: Column {
                    Tool { width: parent.width; height: 36; icon: "squares-four"; label: "Todas las aplicaciones"; onClicked: { bar.menuOpen = false; bar.applicationsRequested(); } }
                    Tool { width: parent.width; height: 36; icon: "gear"; label: "Ajustes de Singlr"; onClicked: { if (singlrSettings.count > 0 && singlrSettings.trigger(0, "", null)) bar.menuOpen = false; } }
                    Tool { width: parent.width; height: 36; icon: "power"; label: "Salir de Singlr"; onClicked: Qt.quit() }
                }
            }
        }
    }
}
