// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.clock as PlasmaClock

ColumnLayout {
    spacing: 4
    Text {
        Layout.alignment: Qt.AlignHCenter
        text: Qt.formatTime(clock.dateTime, Qt.locale(), Locale.ShortFormat)
        textFormat: Text.PlainText
        font.family: Theme.family
        font.pixelSize: 80
        font.weight: Font.Medium
        font.features: ({"tnum": 1})
        color: Theme.text
    }
    Text {
        Layout.alignment: Qt.AlignHCenter
        text: Qt.formatDate(clock.dateTime, Qt.locale(), Locale.LongFormat)
        textFormat: Text.PlainText
        font.family: Theme.family
        font.pixelSize: 15
        color: Theme.secondary
    }
    PlasmaClock.Clock {
        id: clock
        trackSeconds: false
    }
}
