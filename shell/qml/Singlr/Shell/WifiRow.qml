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
    readonly property string identity: networkData.DevicePath + ":" + networkData.Ssid
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
    onEditingChanged: {
        password.clear(); password.echoMode = TextInput.Password;
        if (editing) password.forceActiveFocus();
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
        secondaryText: wifi.networkData.Signal + " %"
        status: wifi.connected ? "Conectada" : ""
        busy: wifi.activating || wifi.requested
        actionText: wifi.connected ? "Desconectar" : ""
        onActionTriggered: wifi.handler.deactivateConnection(wifi.networkData.ConnectionPath, wifi.networkData.DevicePath)
        onClicked: {
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
        width: parent.width - 34; x: 26; spacing: 4; visible: wifi.editing
        Row {
            width: parent.width; spacing: 4
            Controls.TextField {
                id: password
                objectName: "wifiPassword"
                width: parent.width - 32; height: 32
                placeholderText: "Contraseña de la red"; echoMode: TextInput.Password
                font.family: Theme.family; font.pixelSize: 13
                color: Theme.text; placeholderTextColor: Theme.muted
                palette.highlight: Theme.control; palette.highlightedText: "#16171a"
                Accessible.name: "Contraseña de " + wifi.networkData.Name
                background: Rectangle { radius: 5; color: Theme.panel; border.color: password.activeFocus ? Theme.focusBorder : Theme.border }
                onAccepted: wifi.connectPassword()
                Keys.onEscapePressed: event => { password.clear(); wifi.editFinished(); row.forceActiveFocus(); event.accepted = true; }
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
            Tool { icon: "x"; label: "Cancelar"; onClicked: { password.clear(); wifi.editFinished(); row.forceActiveFocus(); } }
        }
    }
    UiText {
        width: parent.width - 34; x: 26; visible: !!wifi.failure
        text: wifi.failure; color: "#ef9a9a"; wrapMode: Text.Wrap; elide: Text.ElideNone
        Accessible.role: Accessible.AlertMessage
    }
}
