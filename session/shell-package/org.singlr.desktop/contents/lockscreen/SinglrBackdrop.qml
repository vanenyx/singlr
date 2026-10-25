// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: backdrop
    property bool softwareRendering: false
    // Cover the greeter's independent wallpaper plugin even when blur is unavailable.
    Rectangle { anchors.fill: parent; color: Theme.background }
    Wallpaper {
        id: picture
        anchors.fill: parent
        // FastBlur hides its source on the GPU; software keeps the readable solid/image fallback.
        visible: backdrop.softwareRendering
    }
    FastBlur {
        anchors.fill: parent
        source: picture
        radius: 48
        cached: true
        visible: !backdrop.softwareRendering
    }
    Rectangle {
        anchors.fill: parent
        color: Theme.background
        opacity: backdrop.softwareRendering ? 0.82 : 0.58
    }
}
