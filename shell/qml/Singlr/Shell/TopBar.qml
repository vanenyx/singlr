pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import Singlr.Ui
Rectangle {
    id: bar
    property bool sessionMode: false
    property Item menuHost: null
    function closeMenu() { menu.close(); systemTray.close(); }
    property alias tray: systemTray
    property Item trayMenuHost: null
    property bool notificationsUnread: false
    signal controlCenterRequested()
    signal notificationsRequested()
    signal launcherRequested()
    signal applicationsRequested()
    property string activeAppName: "Escritorio"
    readonly property bool menuOpen: menu.visible
    property date now: new Date()
    implicitHeight: 28
    color: "#b3161718"
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#0fffffff" }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: bar.now = new Date() }
    Row { x: 16; height: 28; spacing: 8
        Tool { y: 3; width: 24; height: 22; icon: "circle"; iconSize: 14; description: "Menú Singlr"; onClicked: menu.visible ? menu.close() : menu.open() }
        UiText { height: 28; width: Math.min(360, bar.width-trailing.width-100); text: bar.activeAppName; weight: 590 }
    }
    Row {
        id: trailing; anchors.right: parent.right; anchors.rightMargin: 16; height: 28; spacing: 14
        SystemTray { id: systemTray; menuHost: bar.trayMenuHost; onOpenedChanged: if (opened) menu.close() }
        Tool {
            y: 3; width: 24; height: 22; icon: "bell"; iconSize: 15; description: "Notificaciones"
            onClicked: bar.notificationsRequested()
            Rectangle { x: 18; y: 3; width: 4; height: 4; radius: 2; color: Theme.secondary; visible: bar.notificationsUnread }
        }
        Tool { y: 3; width: 24; height: 22; icon: "magnifying-glass"; iconSize: 15; description: "Buscar"; onClicked: bar.launcherRequested() }
        StatusIndicators { anchors.verticalCenter: parent.verticalCenter; onControlCenterRequested: bar.controlCenterRequested() }
        UiText { height: 28; text: bar.now.toLocaleString(Qt.locale("es_ES"), "ddd d MMM  HH:mm"); weight: 510; color: Theme.secondary }
    }
    Controls.Popup {
        id: menu; onAboutToShow: systemTray.close(); parent: bar.menuHost || bar; x: bar.menuHost ? 0 : 16; y: bar.menuHost ? 0 : 32; width: 220; height: 80; padding: 4; focus: true
        popupType: Controls.Popup.Item
        closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
        background: Rectangle { radius: 8; color: Theme.raised; border.color: Theme.border }
        contentItem: Column {
            Tool { width: parent.width; height: 36; icon: "squares-four"; label: "Todas las aplicaciones"; onClicked: { menu.close(); bar.applicationsRequested(); } }
            Tool { width: parent.width; height: 36; icon: "power"; label: "Salir de Singlr"; onClicked: Qt.quit() }
        }
    }
}
