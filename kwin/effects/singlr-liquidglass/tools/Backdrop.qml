// Measurement fixture, never installed in the shell. Animation is opt-in.
import QtQuick
import QtQuick.Window
Window {
    id: window
    width: 1600; height: 1000; visible: true; title: "Singlr material measurement backdrop"
    color: "#28364a"
    property real phase: 0
    Item {
        x: -80 + window.phase * 80; width: window.width + 160; height: window.height
        Repeater {
            model: Math.ceil((window.width + 160) / 80) * Math.ceil(window.height / 80)
            Rectangle {
                required property int index
                readonly property int columns: Math.ceil((window.width + 160) / 80)
                x: (index % columns) * 80; y: Math.floor(index / columns) * 80
                width: 80; height: 80
                color: (index % columns + Math.floor(index / columns)) % 2 ? "#b4c3d2" : "#314966"
            }
        }
    }
    NumberAnimation on phase {
        from: 0; to: 1; duration: 2000; loops: Animation.Infinite
        running: Qt.application.arguments.indexOf("--animate") >= 0
    }
    Timer { interval: 60000; running: true; onTriggered: Qt.quit() }
}
