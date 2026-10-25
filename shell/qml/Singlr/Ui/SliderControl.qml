pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
Controls.Slider {
    id: sl
    implicitHeight: 28
    opacity: enabled ? 1 : 0.45
    palette.highlight: Theme.control
    palette.accent: Theme.control
    palette.button: Theme.control
    background: Rectangle {
        x: sl.leftPadding; y: sl.topPadding + sl.availableHeight / 2 - height / 2
        width: sl.availableWidth; height: 4; radius: 2; color: "#1fffffff"
        Rectangle { width: sl.visualPosition * parent.width; height: parent.height; radius: 2; color: Theme.control }
    }
    handle: Rectangle {
        x: sl.leftPadding + sl.visualPosition * (sl.availableWidth - width); y: sl.topPadding + sl.availableHeight / 2 - height / 2
        width: 14; height: 14; radius: 7; color: Theme.control
        border.color: sl.visualFocus ? Theme.text : "#33000000"
    }
}
