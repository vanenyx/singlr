pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import Singlr.Ui
Window {
    id: desktop
    transientParent: null
    property string capturePath: ""
    property string captureLauncherPath: ""
    property bool capturingLauncher: false
    property bool captureApplications: false
    property bool captureSearch: false
    property string captureQuery: ""
    property bool launcherOpen: false
    readonly property var searchPanel: launcherLoader.item
    readonly property var launcher: searchPanel
    function openLauncher(apps = false) { launcherOpen = true; searchPanel.open(apps); }
    function closeLauncher() { if (searchPanel) searchPanel.close(); }
    width: 2048; height: 1280; visible: true; title: "Singlr"; color: Theme.background
    Item {
        id: canvas; anchors.fill: parent
        Background { id: background; anchors.fill: parent }
        TopBar { notificationsUnread: notifications.unread; onNotificationsRequested: notifications.toggle(); anchors.top: parent.top; width: parent.width; z: 2; activeAppName: dock.activeAppName; onLauncherRequested: desktop.openLauncher(); onApplicationsRequested: desktop.openLauncher(true) }
        Dock { id: dock; anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.horizontalCenter: parent.horizontalCenter; onLauncherRequested: desktop.openLauncher(); onApplicationsRequested: desktop.openLauncher(true) }
        Rectangle { anchors.fill: parent; visible: desktop.launcherOpen; color: Theme.scrim; z: 3
            MouseArea { anchors.fill: parent; onClicked: desktop.closeLauncher() }
        }
        DeferredLoader {
            id: launcherLoader; opened: desktop.launcherOpen; z: 4
            x: (parent.width-width)/2; y: Math.min(286, (parent.height-height)/2)
            sourceComponent: Component {
                Launcher { visible: desktop.launcherOpen; backdrop: background; onClosed: desktop.launcherOpen = false }
            }
        }
        NotificationCenter { id: notifications; x: parent.width - width - 16; y: 40; z: 5 }
        Shortcut { sequences: ["Meta+Space", "Alt+Space"]; onActivated: { if (desktop.launcherOpen) desktop.closeLauncher(); else desktop.openLauncher(); } }
    }
    // KRunner se bloquea si recibe la consulta antes de que arranque el bucle de eventos.
    Component.onCompleted: { if (captureSearch || captureApplications) { desktop.openLauncher(captureApplications); initialQuery.start(); } }
    Timer { id: initialQuery; interval: 300; onTriggered: desktop.searchPanel.query = desktop.captureQuery }
    Timer { id: captureTimer; interval: 2200; running: !!desktop.capturePath; onTriggered: {
        console.log("BACKEND=" + canvas.GraphicsInfo.api + "; RESULTS=" + (desktop.searchPanel ? desktop.searchPanel.resultCount : 0));
        const path = desktop.capturingLauncher ? desktop.captureLauncherPath : desktop.capturePath;
        const started = canvas.grabToImage(result => {
            if (!result.saveToFile(path)) { console.error("CAPTURE_FAILED " + path); Qt.exit(1); return; }
            console.log("CAPTURE_OK " + path);
            if (desktop.captureLauncherPath && !desktop.capturingLauncher) {
                desktop.capturingLauncher = true; desktop.openLauncher(); captureTimer.restart();
            } else Qt.quit();
        }, Qt.size(2048,1280));
        if (!started) Qt.exit(1);
    } }
}
