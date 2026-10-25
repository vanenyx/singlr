/*
    SPDX-FileCopyrightText: 2014 Aleix Pol Gonzalez <aleixpol@blue-systems.com>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

Item {
    id: root
    property bool debug: false
    property string notification
    signal clearPassword()
    signal notificationRepeated()

    // These are magical properties that kscreenlocker looks for
    property bool viewVisible: false

    LayoutMirroring.enabled: Application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    implicitWidth: 800
    implicitHeight: 600

    // Singlr reads its own wallpaper settings; do not render the independent KDE
    // lockscreen wallpaper (which could be animated) behind this opaque backdrop.
    Component.onCompleted: {
        if (wallpaper) wallpaper.visible = false;
    }

    LockScreenUi {
        anchors.fill: parent
    }
}
