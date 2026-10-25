// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.breeze.components as Breeze

// Presentation only. Authentication and session actions remain in KDE's MainBlock/LockScreenUi.
FocusScope {
    id: screen
    property alias notificationMessage: message.text
    property alias actionItems: actions.children
    property alias actionItemsVisible: actions.visible
    property alias userListModel: users.model
    property alias userListCurrentIndex: users.currentIndex
    property alias userListCurrentItem: users.currentItem
    property alias userList: users
    property bool showUserList: true
    property Item authenticationTypeItem: null
    default property alias content: inputs.children
    signal userSelected()

    // Fixed viewport: late media/PAM events cannot move the password field.
    QQC2.ScrollView {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(160, parent.height * 0.31)
        width: Math.min(420, parent.width - 32)
        height: Math.max(0, parent.height - y - 64)
        contentWidth: availableWidth
        clip: true
        QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

        ColumnLayout {
            width: parent.width
            spacing: 12
            Breeze.UserList {
                id: users
                Layout.fillWidth: true
                Layout.preferredHeight: 170
                fontSize: 13
                visible: screen.showUserList
                onUserSelected: screen.userSelected()
            }
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                // Reserve method height even when only one authenticator is available.
                children: screen.authenticationTypeItem ? [screen.authenticationTypeItem] : []
                onWidthChanged: if (screen.authenticationTypeItem) screen.authenticationTypeItem.width = width
            }
            ColumnLayout {
                id: inputs
                Layout.fillWidth: true
                spacing: 10
            }
            // Reserved error region, scrollable even for long PAM prompts.
            QQC2.ScrollView {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                contentWidth: availableWidth
                clip: true
                QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
                Text {
                    id: message
                    width: parent.width
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.error
                    font.family: Theme.family
                    font.pixelSize: 13
                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }
            }
            RowLayout {
                id: actions
                Layout.alignment: Qt.AlignHCenter
                spacing: 20
            }
        }
    }
}
