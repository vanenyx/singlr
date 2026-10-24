// Only exercises check-shell's CLI/capture transport, not the actual shell.
import QtQuick
import QtQuick.Window

Window {
    id: root
    width: 640
    height: 360
    visible: true
    color: "#183040"
    Text { anchors.centerIn: parent; color: "white"; text: "T202 · offscreen fixture" }
    Timer {
        interval: 300
        running: true
        onTriggered: {
            if (!Qt.application.arguments.includes("--windowed")) {
                Qt.exit(2)
                return
            }
            const prefix = "--capture="
            const arg = Qt.application.arguments.find(value => value.startsWith(prefix))
            if (!arg) {
                Qt.exit(3)
                return
            }
            root.contentItem.grabToImage(result => {
                Qt.exit(result.saveToFile(arg.substring(prefix.length)) ? 0 : 4)
            })
        }
    }
}
