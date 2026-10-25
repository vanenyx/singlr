/*
    SPDX-FileCopyrightText: 2016 David Edmundson <davidedmundson@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick

import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.kscreenlocker as ScreenLocker


SinglrSessionScreen {
    id: sessionManager

    property alias passwordInputVisible: passwordLayout.visible
    readonly property alias mainPasswordBox: passwordBox
    property bool lockScreenUiVisible: false
    property bool authenticationBlocked: false
    property alias showPassword: passwordBox.showPassword

    //the y position that should be ensured visible when the on screen keyboard is visible
    property int visibleBoundary: mapFromItem(loginButton, 0, 0).y
    onHeightChanged: visibleBoundary = mapFromItem(loginButton, 0, 0).y + loginButton.height + Kirigami.Units.smallSpacing
    /*
     * Login has been requested with the following username and password
     * If username field is visible, it will be taken from that, otherwise from the "name" property of the currentIndex
     */
    signal passwordResult(string password)

    onUserSelected: {
        const nextControl = (passwordBox.visible ? passwordBox : loginButton);
        // Don't startLogin() here, because the signal is connected to the
        // Escape key as well, for which it wouldn't make sense to trigger
        // login. Using TabFocusReason, so that the loginButton gets the
        // visual highlight.
        nextControl.forceActiveFocus(Qt.TabFocusReason);
    }

    function startLogin() {
        if (authenticationBlocked) return;
        const password = passwordBox.text

        // This is partly because it looks nicer, but more importantly it
        // works round a Qt bug that can trigger if the app is closed with a
        // TextField focused.
        //
        // See https://bugreports.qt.io/browse/QTBUG-55460
        loginButton.forceActiveFocus();
        passwordResult(password);
    }

    QQC2.Control {
        id: passwordLayout
        Layout.fillWidth: true
        implicitHeight: 44
        background: Rectangle {
            radius: 8
            color: Theme.surface
            border.color: passwordBox.activeFocus ? Theme.focusBorder : Theme.border
        }
        contentItem: RowLayout {
            spacing: 0

            Icon {
                name: "lock-simple"
                color: Theme.secondary
                Layout.preferredWidth: 36
                Layout.preferredHeight: 44
            }

            PlasmaExtras.PasswordField {
                id: passwordBox
                font.family: Theme.family
                font.pixelSize: 15
                leftPadding: 4
                color: Theme.text
                background: Item {}
                Layout.fillWidth: true
                text: PasswordSync.password

                placeholderText: i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:placeholder in text field", "Password")
                focus: true

                // In Qt this is implicitly active based on focus rather than visibility
                // in any other application having a focussed invisible object would be weird
                // but here we are using to wake out of screensaver mode
                // We need to explicitly disable cursor flashing to avoid unnecessary renders
                cursorVisible: visible

                onAccepted: {
                    if (sessionManager.lockScreenUiVisible) {
                        sessionManager.startLogin();
                    }
                }

                //if empty and left or right is pressed change selection in user switch
                //this cannot be in keys.onLeftPressed as then it doesn't reach the password box
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Left && !text) {
                        sessionManager.userList.decrementCurrentIndex();
                        event.accepted = true
                    }
                    if (event.key === Qt.Key_Right && !text) {
                        sessionManager.userList.incrementCurrentIndex();
                        event.accepted = true
                    }
                }

                Connections {
                    target: root
                    function onClearPassword() {
                        passwordBox.forceActiveFocus()
                        passwordBox.text = "";
                        passwordBox.text = Qt.binding(() => PasswordSync.password);
                    }
                    function onNotificationRepeated() {
                        // Repeated errors stay in the reserved message area.
                    }
                }
            }
            Binding {
                target: PasswordSync
                property: "password"
                value: passwordBox.text
            }

            PlasmaComponents3.Button {
                id: loginButton
                enabled: !sessionManager.authenticationBlocked
                Accessible.name: i18ndc("plasma_shell_org.kde.plasma.desktop", "@action:button accessible only", "Unlock")
                Layout.preferredHeight: passwordBox.implicitHeight
                Layout.preferredWidth: loginButton.Layout.preferredHeight

                background: Rectangle {
                    radius: 6
                    color: loginButton.hovered ? Theme.toolHover : "transparent"
                }
                contentItem: Icon {
                    name: LayoutMirroring.enabled ? "arrow-left" : "arrow-right"
                    color: Theme.text
                }

                onClicked: sessionManager.startLogin()
                Keys.onEnterPressed: clicked()
                Keys.onReturnPressed: clicked()
            }
        }
    }

    component FailableLabel : PlasmaComponents3.Label {
        id: _failableLabel
        required property int kind
        required property string label

        visible: authenticator.authenticatorTypes & kind
        text: label
        textFormat: Text.PlainText
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true


        Connections {
            target: authenticator
            function onNoninteractiveError(kind, authenticator) {
                if (kind & _failableLabel.kind) {
                    _failableLabel.text = Qt.binding(() => authenticator.errorMessage)
                    _timer.restart()
                }
            }
        }
        Timer {
            id: _timer
            interval: Kirigami.Units.humanMoment
            onTriggered: {
                _failableLabel.text = Qt.binding(() => _failableLabel.label)
            }
        }
    }

    FailableLabel {
        kind: ScreenLocker.Authenticator.Fingerprint
        label: i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:usagetip", "(or scan your fingerprint on the reader)")
    }
    FailableLabel {
        kind: ScreenLocker.Authenticator.Smartcard
        label: i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:usagetip", "(or scan your smartcard)")
    }
}
