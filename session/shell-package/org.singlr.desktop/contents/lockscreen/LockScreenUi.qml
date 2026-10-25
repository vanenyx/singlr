/*
    SPDX-FileCopyrightText: 2014 Aleix Pol Gonzalez <aleixpol@blue-systems.com>
    SPDX-FileCopyrightText: 2026 Kristen McWilliam <kristen@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.private.accessibility
import org.kde.plasma.workspace.components as PW
import org.kde.plasma.workspace.keyboardlayout as Keyboards
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.kirigami as Kirigami
import org.kde.kscreenlocker as ScreenLocker
import org.kde.ki18n

import org.kde.plasma.private.sessions
import org.kde.breeze.components

Item {
    id: lockScreenUi

    // If we're using software rendering, draw outlines instead of shadows
    // See https://bugs.kde.org/show_bug.cgi?id=398317
    readonly property bool softwareRendering: GraphicsInfo.api === GraphicsInfo.Software
    // Whether we expect a given authenticator to prompt for a credential at all.
    // This is a shortcut around the NoPasswordUnlock.qml screen when dealing with prompt-less authenticators.
    property bool expectingPrompt: false // this is set for real when an authenticator is selected
    // <!* Whether we are expected to visualize the prompt message for the authenticator *>
    property bool showPrompt: false // this is set for real when an authenticator is selected

    function handleMessage(msg) {
        if (!root.notification) {
            root.notification += msg;
        } else if (root.notification.includes(msg)) {
            root.notificationRepeated();
        } else {
            root.notification += "\n" + msg
        }
        lockScreenRoot.uiVisible = true
    }


    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    Kirigami.Theme.backgroundColor: Theme.background
    Kirigami.Theme.textColor: Theme.text

    Connections {
        target: authenticator
        function onFailed(kind) {
            if (kind != 0) { // if this is coming from the noninteractive authenticators
                return;
            }
            const msg = i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:status", "Unlocking failed");
            lockScreenUi.handleMessage(msg);
            root.clearPassword();
            authenticator.startAuthenticating();
            notificationRemoveTimer.restart();

        }

        function onSucceeded() {
            // This is important. It stops the all pending authentication processes, preventing timeouts etc.
            authenticator.stopAuthenticating()

            if (!lockScreenUi.expectingPrompt) {
                Qt.quit()
            }
            if (authenticator.hadPrompt) {
                Qt.quit();
            } else {
                mainStack.replace(null, Qt.resolvedUrl("NoPasswordUnlock.qml"),
                    {
                        userListModel: users
                    },
                    StackView.Immediate,
                );
                mainStack.forceActiveFocus();
            }
        }

        function onInfoMessageChanged() {
            lockScreenUi.handleMessage(authenticator.infoMessage);
        }

        function onErrorMessageChanged() {
            lockScreenUi.handleMessage(authenticator.errorMessage);
        }

        function onPromptChanged() {
            lockScreenUi.handleMessage(authenticator.prompt);
        }
        function onPromptForSecretChanged() {
            mainBlock.showPassword = false;
            mainBlock.mainPasswordBox.forceActiveFocus();
            if (lockScreenUi.showPrompt) {
                lockScreenUi.handleMessage(authenticator.promptForSecret);
            }
        }
    }

    SessionManagement {
        id: sessionManagement
    }

    AccessibilityStatus {
        id: accessibilityStatus
    }

    KeyboardIndicator.KeyState {
        id: capsLockState
        key: Qt.Key_CapsLock
    }

    Connections {
        target: sessionManagement
        function onAboutToSuspend() {
            root.clearPassword();
        }
    }

    MouseArea {
        id: lockScreenRoot

        property bool uiVisible: false
        property bool seenPositionChange: false
        property bool blockUI: containsMouse && (mainStack.depth > 1 || mainBlock.mainPasswordBox.text.length > 0 || Keyboards.KWinVirtualKeyboard.visible)

        x: parent.x
        y: parent.y
        width: parent.width
        height: parent.height
        hoverEnabled: true
        cursorShape: uiVisible ? Qt.ArrowCursor : Qt.BlankCursor
        drag.filterChildren: true
        onPressed: uiVisible = true;
        onPositionChanged: {
            uiVisible = seenPositionChange;
            seenPositionChange = true;
        }
        onUiVisibleChanged: {
            if (uiVisible) {
                Window.window.requestActivate();
            }

            if (blockUI) {
                fadeoutTimer.running = false;
            } else if (uiVisible) {
                fadeoutTimer.restart();
            }
            authenticator.startAuthenticating();
        }

        Timer { // heart beat keeping the backend active for as long as we are in visible state
            interval: 1000
            running: !authenticator.unlocked && parent.uiVisible
            repeat: true
            onTriggered: authenticator.startAuthenticating()
        }

        onBlockUIChanged: {
            if (blockUI) {
                fadeoutTimer.running = false;
                uiVisible = true;
            } else {
                fadeoutTimer.restart();
            }
        }
        ScreenLocker.ActiveScreenMonitor {
            id: activeScreenMonitor
            lockscreenState: ScreenLocker.LockscreenState
            window: lockScreenRoot.Window.window
            onActiveChanged: {
                if(!active) {
                    lockScreenRoot.uiVisible = false;
                }
            }
        }
        Keys.onEscapePressed: {
            // If the escape key is pressed, kscreenlocker will turn off the screen.
            // We do not want to show the password prompt in this case.
            if (uiVisible) {
                uiVisible = false;
                if (Keyboards.KWinVirtualKeyboard.visible) {
                    Keyboards.KWinVirtualKeyboard.active = false;
                }
                root.clearPassword();
            }
        }
        Keys.onPressed: event => {
            uiVisible = true;
            event.accepted = false;
        }
        Timer {
            id: fadeoutTimer
            interval: 10000
            onTriggered: {
                if (!lockScreenRoot.blockUI) {
                    mainBlock.mainPasswordBox.showPassword = false;
                    lockScreenRoot.uiVisible = false;
                }
            }
        }
        Timer {
            id: notificationRemoveTimer
            interval: 3000
            onTriggered: root.notification = ""
        }

        // Static blur: no launch/fade/shake animation or live desktop capture.
        SinglrBackdrop {
            anchors.fill: parent
            softwareRendering: lockScreenUi.softwareRendering
        }

        SinglrClock {
            id: clock
            visible: config.alwaysShowClock && (!config.hideClockWhenIdle || lockScreenRoot.uiVisible)
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(24, parent.height * 0.08)
        }

        ListModel {
            id: users

            Component.onCompleted: {
                users.append({
                    name: kscreenlocker_userName,
                    realName: kscreenlocker_userName,
                    icon: kscreenlocker_userImage !== ""
                          ? "file://" + kscreenlocker_userImage.split("/").map(encodeURIComponent).join("/")
                          : "",
                })
            }
        }

        StackView {
            id: mainStack
            anchors {
                left: parent.left
                right: parent.right
            }
            height: lockScreenRoot.height
            focus: true //StackView is an implicit focus scope, so we need to give this focus so the item inside will have it

            // this isn't implicit, otherwise items still get processed for the scenegraph
            visible: lockScreenRoot.uiVisible

            initialItem: MainBlock {
                id: mainBlock
                lockScreenUiVisible: lockScreenRoot.uiVisible

                showUserList: true

                StackView.onStatusChanged: {
                    // prepare for presenting again to the user
                    if (StackView.status === StackView.Activating) {
                        mainPasswordBox.clear();
                        mainPasswordBox.focus = true;
                        root.notification = "";
                    }
                }
                userListModel: users

                authenticationTypeItem: RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    visible: authenticationTypeRepeater.count > 1

                    Repeater {
                        id: authenticationTypeRepeater
                        model: ScreenLocker.AuthenticatorModel

                        delegate: PlasmaComponents3.Button {
                            required property int type
                            required property string iconName
                            required property bool passwordField
                            required property bool expectingPrompt
                            required property string tooltip
                            required property bool showPrompt
                            required property bool functional

                            onFunctionalChanged: {
                                if (functional) {
                                    return
                                }
                                root.notification = ""
                                mainBlock.passwordInputVisible = false
                                lockScreenUi.handleMessage(KI18n.i18ndc(
                                    "plasma_shell_org.kde.plasma.desktop",
                                    "@info:status",
                                    "This authentication method is not functioning correctly. Please try another method, and check your system configuration."))
                            }

                            // Be careful if you remove this to ensure defunct handling is present in all scenarios (e.g. onClicked)
                            enabled: functional
                            icon.name: iconName
                            icon.color: functional ? undefined : Kirigami.Theme.negativeTextColor
                            checked: authenticator.authenticator === type
                            onClicked: {
                                authenticator.authenticator = type
                                root.notification = ""
                                mainBlock.passwordInputVisible = passwordField
                                lockScreenUi.expectingPrompt = expectingPrompt
                                lockScreenUi.showPrompt = showPrompt
                            }

                            PlasmaComponents3.ToolTip.text: tooltip
                            PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                            PlasmaComponents3.ToolTip.visible: hovered

                            Component.onCompleted: {
                                if (checked) {
                                    clicked()
                                }
                            }
                        }
                    }
                }

                notificationMessage: {
                    const parts = [];
                    if (capsLockState.locked) {
                        parts.push(i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:status", "Caps Lock is on"));
                    }
                    if (accessibilityStatus.slowKeysEnabled) {
                        parts.push(i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:status", "Slow Keys are enabled"));
                    }
                    if (root.notification) {
                        parts.push(root.notification);
                    }
                    return parts.join(" • ");
                }

                authenticationBlocked: authenticator.inPasswordDelay
                onPasswordResult: password => authenticator.respond(password)

                actionItems: [
                    ActionButton {
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
                        text: i18ndc("plasma_shell_org.kde.plasma.desktop", "@action:button", "Slee&p")
                        icon.name: "system-suspend"
                        onClicked: sessionManagement.suspend()
                        visible: sessionManagement.canSuspend
                    },
                    ActionButton {
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
                        text: i18ndc("plasma_shell_org.kde.plasma.desktop", "@action:button", "&Hibernate")
                        icon.name: "system-suspend-hibernate"
                        onClicked: sessionManagement.hibernate()
                        visible: sessionManagement.canHibernate
                    },
                    ActionButton {
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
                        text: i18ndc("plasma_shell_org.kde.plasma.desktop", "@action:button", "Switch &User")
                        icon.name: "system-switch-user"
                        onClicked: {
                            sessionManagement.switchUser();
                        }
                        visible: sessionManagement.canSwitchUser
                    }
                ]

                Loader {
                    Layout.topMargin: Kirigami.Units.smallSpacing // some distance to the password field
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 3
                    active: config.showMediaControls
                    source: "MediaControls.qml"
                }
            }
        }

        Loader {
            z: 2
            active: root.viewVisible
            source: "LockOsd.qml"
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: Kirigami.Units.gridUnit
            }
        }

        // Note: Containment masks stretch clickable area of their buttons to
        // the screen edges, essentially making them adhere to Fitts's law.
        // Due to virtual keyboard button having an icon, buttons may have
        // different heights, so fillHeight is required.
        //
        // Note for contributors: Keep this in sync with SDDM Main.qml footer.
        RowLayout {
            id: footer
            anchors {
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                margins: Kirigami.Units.smallSpacing
            }
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.ToolButton {
                id: virtualKeyboardButton

                focusPolicy: Qt.TabFocus
                Accessible.name: i18ndc("plasma_shell_org.kde.plasma.desktop", "Button to show/hide virtual keyboard", "Virtual Keyboard")
                display: AbstractButton.IconOnly
                implicitWidth: 32
                contentItem: Icon { name: "keyboard"; color: Keyboards.KWinVirtualKeyboard.visible ? Theme.text : Theme.muted }
                onClicked: {
                    if (Keyboards.KWinVirtualKeyboard.visible) {
                        Keyboards.KWinVirtualKeyboard.active = false;
                    } else {
                        // Otherwise the password field loses focus and on-screen keyboard
                        // keystrokes get eaten
                        mainBlock.mainPasswordBox.forceActiveFocus();
                        Keyboards.KWinVirtualKeyboard.forceActivate();
                    }
                }

                Layout.fillHeight: true
                containmentMask: Item {
                    parent: virtualKeyboardButton
                    anchors.fill: parent
                    anchors.leftMargin: -footer.anchors.margins
                    anchors.bottomMargin: -footer.anchors.margins
                }
            }

            PlasmaComponents3.ToolButton {
                id: keyboardButton

                focusPolicy: Qt.TabFocus
                Accessible.description: i18ndc("plasma_shell_org.kde.plasma.desktop", "Button to change keyboard layout", "Switch layout")
                icon.name: ""
                Accessible.name: keyboardLayoutSwitcher.layoutNames.longName

                PW.KeyboardLayoutSwitcher {
                    id: keyboardLayoutSwitcher

                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                }

                text: keyboardLayoutSwitcher.layoutNames.longName
                onClicked: keyboardLayoutSwitcher.keyboardLayout.switchToNextLayout()

                visible: keyboardLayoutSwitcher.hasMultipleKeyboardLayouts

                Layout.fillHeight: true
                containmentMask: Item {
                    parent: keyboardButton
                    anchors.fill: parent
                    anchors.leftMargin: virtualKeyboardButton.visible ? 0 : -footer.anchors.margins
                    anchors.bottomMargin: -footer.anchors.margins
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Battery {}
        }
    }
}
