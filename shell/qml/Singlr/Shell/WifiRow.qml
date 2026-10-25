pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
import org.kde.plasma.networkmanagement as Network
import Singlr.Ui

Column {
    id: wifi
    required property var networkData
    required property var handler
    property bool editing: false
    property string secretRequestId: ""
    property bool secretRetry: false
    property var rowState: QtObject {
        property bool menuOpen: false
        property bool confirmingForget: false
        property string password: ""
    }
    property bool menuOpen: rowState.menuOpen
    property bool confirmingForget: rowState.confirmingForget
    onMenuOpenChanged: if (rowState.menuOpen !== menuOpen) rowState.menuOpen = menuOpen
    onConfirmingForgetChanged: if (rowState.confirmingForget !== confirmingForget) rowState.confirmingForget = confirmingForget
    Connections {
        target: wifi.rowState
        function onMenuOpenChanged() { wifi.menuOpen = wifi.rowState.menuOpen; }
        function onConfirmingForgetChanged() { wifi.confirmingForget = wifi.rowState.confirmingForget; }
    }
    signal secretSubmitted(string password)
    signal secretCancelled()
    onSecretRequestIdChanged: {
        password.clear();
        if (secretRequestId) Qt.callLater(function() { if (wifi.secretRequestId && wifi.editing) password.forceActiveFocus(); });
    }
    readonly property string identity: networkData.Uuid ? "uuid:" + networkData.Uuid : "ssid:" + JSON.stringify([networkData.Ssid, networkData.SecurityType])
    readonly property bool connected: networkData.ConnectionState === Network.Enums.Activated
    readonly property bool activating: networkData.ConnectionState === Network.Enums.Activating
    readonly property bool eligible: networkData.Type === Network.Enums.Wireless
        && networkData.ItemType !== Network.NetworkModelItem.UnavailableConnection
        && !!networkData.SpecificPath && networkData.SpecificPath !== "/"
    readonly property bool secured: networkData.SecurityType !== Network.Enums.NoneSecurity && networkData.SecurityType !== Network.Enums.OWE
    readonly property bool staticPassword: [Network.Enums.StaticWep, Network.Enums.WpaPsk, Network.Enums.Wpa2Psk, Network.Enums.SAE].indexOf(networkData.SecurityType) >= 0
    property bool attempted: false
    property bool requested: false
    property bool sawActivation: false
    property string failure: ""
    signal editRequested()
    signal editFinished()
    signal settingsRequested()
    spacing: 4
    onVisibleChanged: if (!visible) { menuOpen = false; confirmingForget = false; }
    onEditingChanged: {
        if (!editing) password.clear();
        password.echoMode = TextInput.Password;
        if (editing) password.forceActiveFocus();
        else { menuOpen = false; confirmingForget = false; }
    }
    onConnectedChanged: if (connected) { requested = false; attempted = false; failure = ""; timeout.stop(); }
    onActivatingChanged: {
        if (activating && requested) sawActivation = true;
        else if (sawActivation && requested && !connected) {
            fail("No se pudo conectar. Comprueba la contraseña e inténtalo de nuevo.");
        }
    }
    function fail(message) {
        requested = false; sawActivation = false; failure = message; timeout.stop();
    }
    function begin() {
        failure = ""; sawActivation = false; requested = true; attempted = true;
        timeout.restart();
    }
    function connectPassword() {
        if (!password.length || requested) return;
        if (secretRequestId) {
            const value = password.text; password.clear(); secretSubmitted(value); editFinished(); return;
        }
        begin();
        handler.addAndActivateConnection(networkData.DevicePath, networkData.SpecificPath, password.text);
        password.clear(); editFinished();
    }
    Connections {
        target: wifi.handler
        function onConnectionActivationFailed(path, message) {
            if (wifi.attempted && (!path || path === wifi.networkData.ConnectionPath || !wifi.networkData.Uuid)) wifi.fail(message);
        }
    }
    Timer {
        id: timeout; interval: 45000
        onTriggered: if (wifi.requested && !wifi.connected) wifi.fail("No se pudo conectar. Comprueba la contraseña y vuelve a intentarlo.");
    }
    ControlRow {
        id: row
        objectName: "networkRow"
        width: parent.width
        text: wifi.networkData.Name
        glyph: wifi.networkData.Signal < 25 ? "wifi-none" : wifi.networkData.Signal < 50 ? "wifi-low" : wifi.networkData.Signal < 75 ? "wifi-medium" : "wifi-high"
        secured: wifi.secured
        secondaryText: wifi.secretRequestId ? "" : wifi.networkData.Signal + " %"
        status: wifi.connected ? "Conectada" : ""
        busy: wifi.activating || wifi.requested
        actionText: !wifi.secretRequestId && wifi.networkData.Uuid ? "…" : ""
        onActionTriggered: { wifi.menuOpen = !wifi.menuOpen; wifi.confirmingForget = false; }
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: { if (!wifi.secretRequestId && wifi.networkData.Uuid) { wifi.menuOpen = !wifi.menuOpen; wifi.confirmingForget = false; } }
        }
        Keys.onMenuPressed: { if (wifi.networkData.Uuid) wifi.menuOpen = !wifi.menuOpen; }
        onClicked: {
            wifi.menuOpen = false;
            if (wifi.connected || busy) return;
            if (wifi.networkData.Uuid) {
                wifi.begin();
                wifi.handler.activateConnection(wifi.networkData.ConnectionPath, wifi.networkData.DevicePath, wifi.networkData.SpecificPath);
            } else if (!wifi.secured) {
                wifi.begin();
                wifi.handler.addAndActivateConnection(wifi.networkData.DevicePath, wifi.networkData.SpecificPath);
            } else if (wifi.staticPassword) wifi.editRequested();
            else wifi.settingsRequested();
        }
    }
    Column {
        width: parent.width - 26; x: 26; spacing: 2; visible: wifi.menuOpen
        ControlRow { width: parent.width; visible: wifi.connected && !wifi.confirmingForget; objectName: "disconnectNetwork"; text: "Desconectar"; onClicked: { wifi.handler.deactivateConnection(wifi.networkData.ConnectionPath, wifi.networkData.DevicePath); wifi.menuOpen = false; } }
        ControlRow { width: parent.width; visible: !wifi.confirmingForget; objectName: "forgetNetwork"; text: "Olvidar red"; onClicked: wifi.confirmingForget = true }
        ControlRow { width: parent.width; visible: !wifi.confirmingForget; text: "Ajustes…"; onClicked: { wifi.menuOpen = false; wifi.settingsRequested(); } }
        UiText { width: parent.width; visible: wifi.confirmingForget; text: "¿Olvidar «" + wifi.networkData.Name + "»?"; wrapMode: Text.Wrap }
        Row {
            visible: wifi.confirmingForget; spacing: 8
            Tool { objectName: "confirmForget"; icon: "check"; label: "Olvidar"; onClicked: { wifi.handler.removeConnection(wifi.networkData.ConnectionPath); wifi.menuOpen = false; wifi.confirmingForget = false; } }
            Tool { icon: "x"; label: "Cancelar"; onClicked: { wifi.confirmingForget = false; wifi.menuOpen = false; } }
        }
    }
    Column {
        width: parent.width - 34; x: 26; spacing: 4; visible: wifi.editing
        Row {
            width: parent.width; spacing: 4
            Controls.TextField {
                id: password
                objectName: "wifiPassword"
                text: wifi.rowState.password
                onTextChanged: if (wifi.rowState.password !== text) wifi.rowState.password = text
                width: parent.width - 32; height: 32
                placeholderText: "Contraseña de la red"; echoMode: TextInput.Password
                font.family: Theme.family; font.pixelSize: 13
                color: Theme.text; placeholderTextColor: Theme.muted
                palette.highlight: Theme.control; palette.highlightedText: "#16171a"
                Accessible.name: "Contraseña de " + wifi.networkData.Name
                background: Rectangle { radius: 5; color: Theme.panel; border.color: password.activeFocus ? Theme.focusBorder : Theme.border }
                onAccepted: wifi.connectPassword()
                Keys.onEscapePressed: event => { password.clear(); if (wifi.secretRequestId) wifi.secretCancelled(); wifi.editFinished(); row.forceActiveFocus(); event.accepted = false; }
            }
            Tool {
                icon: password.echoMode === TextInput.Password ? "eye" : "eye-slash"
                description: password.echoMode === TextInput.Password ? "Mostrar contraseña" : "Ocultar contraseña"
                onClicked: password.echoMode = password.echoMode === TextInput.Password ? TextInput.Normal : TextInput.Password
            }
        }
        Row {
            spacing: 8
            Tool { icon: "check"; label: "Conectar"; enabled: password.length > 0; onClicked: wifi.connectPassword() }
            Tool { icon: "x"; label: "Cancelar"; onClicked: { password.clear(); if (wifi.secretRequestId) wifi.secretCancelled(); wifi.editFinished(); row.forceActiveFocus(); } }
        }
    }
    UiText {
        width: parent.width - 34; x: 26; visible: !!wifi.failure || (!!wifi.secretRequestId && wifi.secretRetry)
        text: wifi.secretRequestId && wifi.secretRetry ? "Contraseña incorrecta" : wifi.failure; color: "#ef9a9a"; wrapMode: Text.Wrap; elide: Text.ElideNone
        Accessible.role: Accessible.AlertMessage
    }
}
