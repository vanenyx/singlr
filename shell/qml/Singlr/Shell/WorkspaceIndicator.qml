pragma ComponentBehavior: Bound
import QtQuick
import org.kde.taskmanager as TaskManager
import org.kde.plasma.workspace.dbus as DBus
import Singlr.Ui

Item {
    id: indicator
    property string screenName: ""
    property var backend: desktops
    readonly property var desktopIds: backend.desktopIds
    readonly property var currentDesktop: screenName ? backend.currentDesktopByScreenName(screenName) : backend.currentDesktop
    visible: desktopIds.length > 1
    implicitWidth: 72
    implicitHeight: 22
    function activate(id) {
        if (desktopIds.indexOf(id) < 0) return;
        DBus.SessionBus.asyncCall({service: "org.kde.KWin", path: "/VirtualDesktopManager",
            iface: "org.freedesktop.DBus.Properties", member: "Set",
            arguments: ["org.kde.KWin.VirtualDesktopManager", "current", DBus.variant(DBus.string(id))]},
            () => {}, error => console.warn("Singlr: escritorio: " + error.message));
    }
    TaskManager.VirtualDesktopInfo { id: desktops }
    ListView {
        id: list
        anchors.fill: parent
        orientation: ListView.Horizontal
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: indicator.desktopIds
        currentIndex: indicator.desktopIds.indexOf(indicator.currentDesktop)
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        delegate: Tool {
            required property var modelData
            required property int index
            objectName: "workspaceDesktop" + index
            width: 24; height: 22
            label: String(index + 1)
            icon: ""; iconSize: 0
            description: indicator.backend.desktopNames[index] || "Escritorio " + (index + 1)
            border.width: 1
            border.color: modelData === indicator.currentDesktop ? Theme.focusBorder : "transparent"
            color: modelData === indicator.currentDesktop ? Theme.toolHover : "transparent"
            onClicked: indicator.activate(modelData)
        }
    }
}
