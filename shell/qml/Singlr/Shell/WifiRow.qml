pragma ComponentBehavior: Bound
import QtQuick
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
    signal passwordRequested()
    signal menuRequested(var anchor, real px, real py)
    signal settingsRequested()
    height: 36
    implicitHeight: 36
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
        } else if (staticPassword) passwordRequested();
        else settingsRequested();
    }
    ControlRow {
        id: row
        objectName: "networkRow"
        width: parent.width; height: 36
        text: wifi.networkData.Name
        glyph: wifi.networkData.Signal < 25 ? "wifi-none" : wifi.networkData.Signal < 50 ? "wifi-low" : wifi.networkData.Signal < 75 ? "wifi-medium" : "wifi-high"
        secured: wifi.secured
        secondaryText: wifi.failure || wifi.networkData.Signal + " %"
        status: wifi.connected ? "Conectada" : ""
        busy: wifi.activating || wifi.requested
        actionText: "…"
        onActionTriggered: wifi.menuRequested(row, row.width - 28, row.height)
        TapHandler { acceptedButtons: Qt.RightButton; onTapped: eventPoint => wifi.menuRequested(row, eventPoint.position.x, eventPoint.position.y) }
        Keys.onMenuPressed: wifi.menuRequested(row, row.width - 28, row.height)
        onClicked: wifi.connectNetwork()
    }
}
