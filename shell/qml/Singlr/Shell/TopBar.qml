pragma ComponentBehavior: Bound
import QtQuick
import Singlr.Ui
Rectangle {
    id: bar
    signal launcherRequested()
    property bool menuOpen: false
    property date now: new Date()
    Keys.onEscapePressed: menuOpen = false
    implicitHeight: 38
    color: Theme.panel
    Timer { interval: 1000; running: true; repeat: true; onTriggered: bar.now = new Date() }
    Row { x: 24; height: 38; spacing: 16
        Tool { y: 5; icon: "circle"; label: "Singlr"; onClicked: bar.menuOpen = !bar.menuOpen }
        Tool { y: 5; icon: "magnifying-glass"; label: "Buscar"; onClicked: bar.launcherRequested() }
    }
    UiText { anchors.centerIn: parent; text: Qt.formatDateTime(bar.now, "ddd d MMM    HH:mm"); font.pixelSize: 12; color: Theme.muted }
    Rectangle {
        visible: bar.menuOpen; x: 24; y: 38; width: 206; height: 44; radius: 6
        color: Theme.raised; border.color: Theme.border; z: 10
        Tool { anchors.centerIn: parent; width: 190; icon: "power"; label: "Salir de Singlr"; onClicked: Qt.quit() }
        Keys.onEscapePressed: bar.menuOpen = false
    }
}
