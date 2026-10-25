pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
Controls.Switch {
    id: sw
    implicitHeight: 36
    leftPadding: 0; rightPadding: 44
    spacing: 10
    opacity: enabled ? 1 : 0.45
    palette.highlight: Theme.control
    palette.accent: Theme.control
    palette.button: Theme.hover
    palette.buttonText: Theme.text
    palette.text: Theme.text
    contentItem: UiText { text: sw.text; color: Theme.secondary; horizontalAlignment: Text.AlignLeft }
    indicator: Rectangle {
        implicitWidth: 34; implicitHeight: 20; radius: 10
        x: sw.width - width; y: (sw.height - height) / 2
        color: sw.checked ? Theme.control : "#1fffffff"
        border.color: sw.visualFocus ? Theme.control : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
        Rectangle {
            width: 16; height: 16; radius: 8; y: 2
            x: sw.checked ? parent.width - width - 2 : 2
            color: sw.checked ? "#16171a" : "#d0d6e0"
            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
    }
    background: Item { }
}
