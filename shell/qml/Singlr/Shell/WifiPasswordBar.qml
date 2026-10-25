pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
import org.kde.plasma.networkmanagement as Network
import Singlr.Ui

Controls.Popup {
    id: bar
    required property var handler
    property WifiRow row: null
    readonly property var networkData: row ? row.networkData : ({})
    property string requestId: ""
    property bool requested: false
    property bool failed: false
    property bool succeeded: false
    readonly property bool connected: networkData.ConnectionState === Network.Enums.Activated
    signal secretSubmitted(string requestId, string password)
    signal cancelled()
    objectName: "wifiPasswordBar"
    parent: row
    x: 0; y: 0; width: row ? row.width : 0; height: 36
    padding: 0; margins: -1
    focus: true; modal: true; dim: false
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
    enter: null; exit: null
    function show(target, secret = "", retry = false) {
        const same = visible && row === target;
        if (visible && !same) close();
        timeout.stop();
        row = target; requestId = secret; requested = false; failed = retry; succeeded = false;
        if (!same) password.clear();
        password.echoMode = TextInput.Password;
        open();
        password.forceActiveFocus();
        if (retry) password.selectAll();
    }
    function fail() {
        requested = false; failed = true; timeout.stop();
        password.forceActiveFocus(); password.selectAll();
    }
    function submit() {
        if (!password.length || requested) return;
        failed = false; requested = true; timeout.restart();
        if (requestId) secretSubmitted(requestId, password.text);
        else handler.addAndActivateConnection(networkData.DevicePath, networkData.SpecificPath, password.text);
    }
    onRowChanged: if (!row && visible) close()
    onConnectedChanged: if (visible && connected) { succeeded = true; close(); }
    onClosed: {
        timeout.stop(); requested = false; password.clear();
        if (!succeeded) cancelled();
        if (row) row.forceActiveFocus();
    }
    Connections {
        target: bar.handler
        function onConnectionActivationFailed(path, message) {
            if (bar.visible && bar.requested && (!path || path === bar.networkData.ConnectionPath || !bar.networkData.Uuid)) bar.fail();
        }
    }
    Timer { id: timeout; interval: 45000; onTriggered: bar.fail() }
    background: Rectangle { color: Theme.raised; radius: 5; border.color: bar.failed ? "#ef9a9a" : Theme.focusBorder }
    contentItem: Item {
        Icon {
            x: 8; anchors.verticalCenter: parent.verticalCenter; width: 14; height: 14; font.pixelSize: 14
            name: "lock-simple"; visible: !bar.failed
        }
        UiText {
            x: 8; anchors.verticalCenter: parent.verticalCenter; width: 14; height: 14; font.pixelSize: 14
            text: "⚠"; color: "#ef9a9a"; visible: bar.failed
        }
        Controls.TextField {
            id: password; objectName: "wifiPassword"
            x: 28; width: parent.width - 116; height: 36
            leftPadding: 0; rightPadding: 4
            echoMode: TextInput.Password; readOnly: bar.requested; selectByMouse: true
            placeholderText: bar.failed ? "Contraseña incorrecta" : "Contraseña de " + (bar.networkData.Name || "")
            color: Theme.text; placeholderTextColor: Theme.secondary; font.family: Theme.family; font.pixelSize: 13
            Accessible.name: placeholderText
            background: Rectangle { color: "transparent"; radius: 4; border.color: bar.failed ? "#ef9a9a" : "transparent" }
            onAccepted: bar.submit()
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter
            Tool { objectName: "showPassword"; iconSize: 14; icon: password.echoMode === TextInput.Password ? "eye" : "eye-slash"; description: "Mostrar u ocultar contraseña"; onClicked: { password.echoMode = password.echoMode === TextInput.Password ? TextInput.Normal : TextInput.Password; password.forceActiveFocus(); } }
            Item {
                width: 28; height: 28
                Tool { objectName: "connectPassword"; iconSize: 14; icon: "key-return"; description: "Conectar"; visible: !bar.requested; enabled: password.length > 0; onClicked: bar.submit() }
                Icon { anchors.centerIn: parent; name: "dots-three"; visible: bar.requested; Accessible.name: "Conectando" }
            }
            Tool { objectName: "cancelPassword"; iconSize: 14; icon: "x"; description: "Cancelar"; onClicked: bar.close() }
        }
    }
}
