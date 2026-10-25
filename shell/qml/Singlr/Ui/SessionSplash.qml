import QtQuick
Rectangle {
    id: splash
    property int stage: 0
    property bool dark: Theme.dark
    readonly property color ink: dark ? "#f7f8f8" : "#282a30"
    color: dark ? "#08090a" : "#f8f8f8"
    Accessible.role: Accessible.Pane
    Accessible.name: "Iniciando Singlr"
    Rectangle {
        id: ring
        anchors.centerIn: parent
        width: 76; height: 76; radius: 38
        color: "transparent"; border.width: 6; border.color: splash.ink
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity { NumberAnimation { duration: Motion.duration } }
    }
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: ring.y + ring.height + 56
        width: 96; height: 2; radius: 1
        color: Qt.rgba(splash.ink.r, splash.ink.g, splash.ink.b, 0.10)
        Rectangle {
            width: parent.width * Math.min(6, Math.max(0, splash.stage)) / 6
            height: parent.height; radius: 1; color: Qt.rgba(splash.ink.r, splash.ink.g, splash.ink.b, 0.45)
        }
    }
}
