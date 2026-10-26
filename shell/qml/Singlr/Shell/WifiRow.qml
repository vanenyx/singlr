pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
import org.kde.plasma.networkmanagement as Network
import Singlr.Ui

Item {
    id: wifi
    required property var networkData
    required property var handler
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
    property bool editing: false
    readonly property bool failed: editing && !!failure
    function showPassword(retry = false) {
        if (!editing) password.clear();
        editing = true; requested = false; sawActivation = false;
        failure = retry ? "Contraseña incorrecta" : "";
        timeout.stop(); password.echoMode = TextInput.Password;
        password.forceActiveFocus();
        if (retry) password.selectAll();
    }
    function closePassword() {
        if (!editing) return;
        editing = false; password.clear();
        if (!requested) timeout.stop();
    }
    function submit() {
        if (!password.length || requested) return;
        begin();
        handler.addAndActivateConnection(networkData.DevicePath, networkData.SpecificPath, password.text);
    }
    signal menuRequested(var anchor, real px, real py)
    signal settingsRequested()
    height: 36
    implicitHeight: 36
    onConnectedChanged: if (connected) { requested = false; attempted = false; failure = ""; timeout.stop(); closePassword(); }
    onActivatingChanged: {
        if (activating && requested) sawActivation = true;
        else if (sawActivation && requested && !connected) {
            fail("No se pudo conectar. Comprueba la contraseña e inténtalo de nuevo.");
        }
    }
    function fail(message) {
        requested = false; sawActivation = false; failure = editing ? "Contraseña incorrecta" : message; timeout.stop();
        if (editing) { password.forceActiveFocus(); password.selectAll(); }
    }
    function begin() {
        failure = ""; sawActivation = false; requested = true; attempted = true;
        timeout.restart();
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
    function connectNetwork() {
        if (connected || activating || requested) return;
        if (networkData.Uuid) {
            begin();
            handler.activateConnection(networkData.ConnectionPath, networkData.DevicePath, networkData.SpecificPath);
        } else if (!secured) {
            begin();
            handler.addAndActivateConnection(networkData.DevicePath, networkData.SpecificPath);
        } else if (staticPassword) showPassword();
        else settingsRequested();
    }
    ControlRow {
        id: row
        objectName: "networkRow"
        visible: !wifi.editing
        width: parent.width; height: 36
        text: wifi.networkData.Name
        glyph: wifi.networkData.Signal < 25 ? "wifi-none" : wifi.networkData.Signal < 50 ? "wifi-low" : wifi.networkData.Signal < 75 ? "wifi-medium" : "wifi-high"
        secured: wifi.secured
        secondaryText: wifi.failure || (wifi.activating || wifi.requested ? "Conectando…" : wifi.connected ? "Conectada" : "")
        status: ""
        busy: wifi.activating || wifi.requested
        actionText: "…"
        onActionTriggered: wifi.menuRequested(row, row.width - 28, row.height)
        TapHandler { acceptedButtons: Qt.RightButton; onTapped: eventPoint => wifi.menuRequested(row, eventPoint.position.x, eventPoint.position.y) }
        Keys.onMenuPressed: wifi.menuRequested(row, row.width - 28, row.height)
        onClicked: wifi.connectNetwork()
    }
    Rectangle {
        anchors.fill: parent; visible: wifi.editing; radius: 6
        color: Theme.hover
        Icon {
            x: 8; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; font.pixelSize: 16
            name: wifi.failed ? "warning" : row.glyph
            color: wifi.failed ? Theme.error : Theme.secondary
            opacity: wifi.requested ? 0.4 : 1
            Accessible.name: wifi.failed ? "Contraseña incorrecta" : wifi.requested ? "Conectando" : "Wi-Fi"
        }
        Controls.TextField {
            id: password; objectName: "wifiPassword"
            x: 34; width: parent.width - 38; height: 36
            leftPadding: 0; rightPadding: 32
            echoMode: TextInput.Password; readOnly: wifi.requested; selectByMouse: true
            placeholderText: wifi.failed ? "Contraseña incorrecta" : "Contraseña"
            color: Theme.text; placeholderTextColor: Theme.secondary; font.family: Theme.family; font.pixelSize: 13
            Accessible.name: "Contraseña de " + wifi.networkData.Name
            background: Rectangle { color: "transparent"; radius: 4; border.color: password.activeFocus ? Theme.accentText : "transparent" }
            onAccepted: wifi.submit()
            Keys.onEscapePressed: wifi.closePassword()
            Tool {
                objectName: "showPassword"; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                iconSize: 14; icon: password.echoMode === TextInput.Password ? "eye" : "eye-slash"
                description: "Mostrar u ocultar contraseña"
                onClicked: { password.echoMode = password.echoMode === TextInput.Password ? TextInput.Normal : TextInput.Password; password.forceActiveFocus(); }
            }
        }
    }
    TapHandler {
        parent: wifi.Window.window ? wifi.Window.window.contentItem : wifi
        enabled: wifi.editing
        onTapped: point => {
            const local = wifi.mapFromItem(parent, point.position.x, point.position.y);
            if (!wifi.contains(local)) wifi.closePassword();
        }
    }
}
