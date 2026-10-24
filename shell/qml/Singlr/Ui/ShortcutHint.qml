import QtQuick
Rectangle {
    property alias text: label.text
    implicitWidth: label.implicitWidth + 10
    implicitHeight: 20
    radius: 4
    color: "transparent"
    border.color: Theme.border
    UiText { id: label; anchors.centerIn: parent; font.pixelSize: 10; color: Theme.muted }
}
