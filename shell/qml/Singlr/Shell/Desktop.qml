pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import Singlr.Ui
Window {
    id: desktop
    property string capturePath: ""
    property string captureLauncherPath: ""
    property bool capturingLauncher: false
    property bool captureSearch: false
    property string captureQuery: "konsole"
    property alias launcher: searchPanel
    width: 2048; height: 1280; visible: true; title: "Singlr"; color: Theme.background
    Item {
        id: canvas; anchors.fill: parent
        Background { id: background; anchors.fill: parent }
        TopBar { anchors.top: parent.top; width: parent.width; z: 2; onLauncherRequested: searchPanel.open() }
        Dock { anchors.bottom: parent.bottom; anchors.bottomMargin: 30; anchors.horizontalCenter: parent.horizontalCenter; onLauncherRequested: searchPanel.open() }
        Rectangle { anchors.fill: parent; visible: searchPanel.visible; color: "#38000000"; z: 3
            MouseArea { anchors.fill: parent; onClicked: searchPanel.close() }
        }
        Launcher { id: searchPanel; visible: false; z: 4; x: (parent.width-width)/2; y: Math.min(286, (parent.height-height)/2); backdrop: background }
        Shortcut { sequences: ["Meta+Space", "Alt+Space"]; onActivated: { if (searchPanel.visible) searchPanel.close(); else searchPanel.open(); } }
    }
    // KRunner se bloquea si recibe la consulta antes de que arranque el bucle de eventos.
    Component.onCompleted: { if (captureSearch) { searchPanel.open(); initialQuery.start(); } }
    Timer { id: initialQuery; interval: 300; onTriggered: searchPanel.query = desktop.captureQuery }
    Timer { id: captureTimer; interval: 2200; running: !!desktop.capturePath; onTriggered: {
        console.log("BACKEND=" + canvas.GraphicsInfo.api + "; RESULTS=" + searchPanel.resultCount);
        const path = desktop.capturingLauncher ? desktop.captureLauncherPath : desktop.capturePath;
        const started = canvas.grabToImage(result => {
            if (!result.saveToFile(path)) { console.error("CAPTURE_FAILED " + path); Qt.exit(1); return; }
            console.log("CAPTURE_OK " + path);
            if (desktop.captureLauncherPath && !desktop.capturingLauncher) {
                desktop.capturingLauncher = true; searchPanel.open(); captureTimer.restart();
            } else Qt.quit();
        }, Qt.size(2048,1280));
        if (!started) Qt.exit(1);
    } }
}
