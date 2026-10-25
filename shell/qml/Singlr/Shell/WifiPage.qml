pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
import org.kde.plasma.networkmanagement as Network
import Singlr.Ui

Column {
    id: page
    required property var networkData
    required property var handler
    property bool passwordPage: false
    property string requestId: ""
    property bool retry: false
    property bool requested: false
    property string failure: retry ? "Contraseña incorrecta" : ""
    readonly property bool staticPassword: [Network.Enums.StaticWep, Network.Enums.WpaPsk, Network.Enums.Wpa2Psk, Network.Enums.SAE].indexOf(networkData.SecurityType) >= 0
    readonly property bool connected: networkData.ConnectionState === Network.Enums.Activated
    signal backRequested()
    signal passwordRequested(var data)
    signal secretSubmitted(string password)
    signal settingsRequested()
    spacing: 8
    function submit() {
        if (!password.length || requested) return;
        failure = ""; requested = true; timeout.restart();
        const value = password.text; password.clear();
        if (requestId) secretSubmitted(value);
        else handler.addAndActivateConnection(networkData.DevicePath, networkData.SpecificPath, value);
    }
    onConnectedChanged: if (connected) { requested = false; timeout.stop(); if (passwordPage) backRequested(); }
    Connections {
        target: page.handler
        function onConnectionActivationFailed(path, message) {
            if (page.requested && (!path || path === page.networkData.ConnectionPath || !page.networkData.Uuid)) {
                page.requested = false; page.failure = message; timeout.stop();
            }
        }
    }
    Timer { id: timeout; interval: 45000; onTriggered: { page.requested = false; page.failure = "No se pudo conectar. Vuelve a intentarlo."; } }
    Row {
        width: parent.width; height: 36
        Tool { objectName: "pageBack"; icon: "caret-left"; description: "Volver"; onClicked: page.backRequested() }
        UiText { width: parent.width - 28; height: 36; weight: 600; text: page.passwordPage ? 'Conectar a "' + page.networkData.Name + '"' : page.networkData.Name; elide: Text.ElideRight }
    }
    Column {
        width: parent.width; spacing: 8; visible: page.passwordPage
        Row {
            width: parent.width
            Controls.TextField {
                id: password; objectName: "wifiPassword"; width: parent.width - 28; height: 36
                echoMode: TextInput.Password; placeholderText: "Contraseña de la red"
                color: Theme.text; font.family: Theme.family; font.pixelSize: 13
                Accessible.name: "Contraseña de " + page.networkData.Name
                background: Rectangle { color: Theme.panel; radius: 5; border.color: password.activeFocus ? Theme.focusBorder : Theme.border }
                onAccepted: page.submit()
                Component.onCompleted: if (page.passwordPage) forceActiveFocus()
            }
            Tool { icon: password.echoMode === TextInput.Password ? "eye" : "eye-slash"; description: "Mostrar u ocultar contraseña"; onClicked: password.echoMode = password.echoMode === TextInput.Password ? TextInput.Normal : TextInput.Password }
        }
        Row {
            spacing: 8
            Tool { objectName: "connectPassword"; icon: "check"; label: page.requested ? "Conectando…" : "Conectar"; enabled: password.length > 0 && !page.requested; onClicked: page.submit() }
            Tool { icon: "x"; label: "Cancelar"; onClicked: page.backRequested() }
        }
    }
    UiText { objectName: "wifiError"; width: parent.width; height: 36; text: page.failure; color: "#ef9a9a"; elide: Text.ElideRight; Accessible.role: Accessible.AlertMessage }
}
