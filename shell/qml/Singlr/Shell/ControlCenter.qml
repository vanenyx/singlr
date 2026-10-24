pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import org.kde.plasma.private.volume as Volume
import org.kde.plasma.private.battery as Battery
import org.kde.plasma.private.batterymonitor as Power
import org.kde.plasma.private.brightnesscontrolplugin as Brightness
import org.kde.plasma.networkmanagement as Network
import org.kde.bluezqt as Bluetooth
import org.kde.plasma.private.kicker as Kicker
import Singlr.Ui

Controls.Control {
    id: panel
    required property SystemControls audio
    required property var notifications
    signal closed()
    implicitWidth: 340
    implicitHeight: Math.min(760, content.implicitHeight + 32)
    property string errorText: ""
    property bool networksExpanded: false
    property var pendingWifi: null
    property bool opened: true
    palette.window: Theme.raised
    palette.windowText: Theme.text
    palette.text: Theme.text
    palette.button: Theme.hover
    palette.buttonText: Theme.text
    palette.base: Theme.panel
    palette.highlight: Theme.accent
    onOpenedChanged: {
        if (opened) networkHandler.requestScan();
        else { pendingWifi = null; wifiPassword.clear(); errorText = ""; }
    }
    Timer { interval: 15000; running: panel.opened; repeat: true; onTriggered: networkHandler.requestScan() }
    function openSettings() {
        if (settingsApp.count > 0 && settingsApp.trigger(0, "", null)) panel.closed();
        else panel.errorText = "Configuración no encontrada en el catálogo.";
    }
    Keys.onEscapePressed: closed()
    Rectangle { anchors.fill: parent; radius: 12; color: "#ed191a1b"; border.color: Theme.focusBorder }
    Kicker.SimpleFavoritesModel { id: settingsApp; favorites: ["systemsettings.desktop"] }
    Battery.BatteryControlModel { id: battery }
    Power.PowerProfilesControl { id: power }
    Brightness.ScreenBrightnessControl { id: brightness }
    Network.NetworkStatus { id: network }
    Network.EnabledConnections { id: enabledConnections }
    Network.Handler { id: networkHandler; onConnectionActivationFailed: (path, message) => panel.errorText = message }
    Network.NetworkModel { id: networks }
    Volume.SinkModel { id: sinks }
    Controls.ScrollView {
        anchors.fill: parent; anchors.margins: 16
        contentWidth: availableWidth
        clip: true
        Column {
            id: content; width: parent.width; spacing: 8
            Row {
                width: parent.width; height: 28
                UiText { width: parent.width - 28; height: 28; text: "Centro de control"; weight: 600 }
                Tool { icon: "x"; description: "Cerrar"; onClicked: panel.closed() }
            }
            Controls.Switch {
                width: parent.width; text: "Wi-Fi"; checked: enabledConnections.wirelessEnabled
                enabled: enabledConnections.wirelessHwEnabled
                onToggled: networkHandler.enableWireless(checked)
            }
            UiText {
                width: parent.width; height: 24; elide: Text.ElideRight; color: Theme.secondary
                text: network.activeConnections || "Sin conexión activa"
            }
            Tool {
                width: parent.width; height: 28; icon: panel.networksExpanded ? "caret-down" : "caret-right"
                label: panel.networksExpanded ? "Ocultar redes" : "Ver redes"
                enabled: enabledConnections.wirelessEnabled
                onClicked: panel.networksExpanded = !panel.networksExpanded
            }
            // NetworkManager owns connections and credentials. Enterprise setup
            // remains in System Settings, where KDE supports certificates/EAP.
            Column {
                width: parent.width; visible: panel.networksExpanded
                Repeater {
                    model: networks
                    delegate: Tool {
                        required property var model
                        width: parent.width; height: visible ? 30 : 0
                        visible: model.Type === Network.Enums.Wireless && enabledConnections.wirelessEnabled
                        icon: model.ConnectionState === Network.Enums.Activated ? "check" : "wifi-high"
                        label: model.Name; clip: true
                        description: model.Name + (model.ConnectionState === Network.Enums.Activated ? ", conectada" : "")
                        onClicked: {
                            if (model.ConnectionState === Network.Enums.Activated) return;
                            if (model.ConnectionPath) networkHandler.activateConnection(model.ConnectionPath, model.DevicePath, model.SpecificPath);
                            else if (model.SecurityType === Network.Enums.NoneSecurity || model.SecurityType === Network.Enums.OWE)
                                networkHandler.addAndActivateConnection(model.DevicePath, model.SpecificPath);
                            else if ([Network.Enums.StaticWep, Network.Enums.WpaPsk, Network.Enums.Wpa2Psk, Network.Enums.SAE].indexOf(model.SecurityType) >= 0) {
                                panel.pendingWifi = {name: model.Name, device: model.DevicePath, accessPoint: model.SpecificPath};
                                wifiPassword.clear(); wifiPassword.forceActiveFocus();
                            } else panel.openSettings();
                        }
                    }
                }
            }
            Column {
                width: parent.width; spacing: 4; visible: panel.pendingWifi !== null
                UiText { width: parent.width; height: 24; text: panel.pendingWifi ? "Conectar a " + panel.pendingWifi.name : "" }
                Controls.TextField {
                    id: wifiPassword; width: parent.width; placeholderText: "Contraseña de la red"
                    echoMode: TextInput.Password; Accessible.name: "Contraseña Wi-Fi"
                    onAccepted: connectWifi.clicked()
                }
                Row {
                    spacing: 8
                    Controls.Button {
                        id: connectWifi; text: "Conectar"; enabled: wifiPassword.length > 0 && panel.pendingWifi !== null
                        onClicked: {
                            if (!enabled) return;
                            networkHandler.addAndActivateConnection(panel.pendingWifi.device, panel.pendingWifi.accessPoint, wifiPassword.text);
                            wifiPassword.clear(); panel.pendingWifi = null;
                        }
                    }
                    Controls.Button { text: "Cancelar"; onClicked: { wifiPassword.clear(); panel.pendingWifi = null; } }
                }
            }
            Controls.Switch {
                id: bluetoothToggle; width: parent.width; text: "Bluetooth"
                visible: Bluetooth.Manager.adapters.length > 0
                checked: !Bluetooth.Manager.bluetoothBlocked && Bluetooth.Manager.adapters.some(adapter => adapter.powered)
                onToggled: {
                    Bluetooth.Manager.bluetoothBlocked = !checked;
                    for (const adapter of Bluetooth.Manager.adapters) adapter.powered = checked;
                }
            }
            Column {
                width: parent.width; visible: bluetoothToggle.checked
                Repeater {
                    model: Bluetooth.Manager.devices
                    delegate: Tool {
                        required property var modelData
                        width: parent.width; height: visible ? 30 : 0
                        visible: modelData.paired
                        icon: modelData.connected ? "check" : "bluetooth"
                        label: modelData.friendlyName; clip: true
                        onClicked: {
                            const call = modelData.connected ? modelData.disconnectFromDevice() : modelData.connectToDevice();
                            call.finished.connect(function(result) { if (result.error) panel.errorText = result.errorText; });
                        }
                    }
                }
            }
            Rectangle { width: parent.width; height: 1; color: Theme.border }
            Column {
                width: parent.width; visible: !!panel.audio.sink
                Row {
                    width: parent.width; height: 28
                    Tool { icon: panel.audio.sink && panel.audio.sink.muted ? "speaker-slash" : "speaker-high"; description: "Silenciar salida"; onClicked: panel.audio.toggleMute(panel.audio.sink) }
                    UiText { width: parent.width - 28; height: 28; text: panel.audio.sink ? panel.audio.sink.description : ""; elide: Text.ElideRight }
                }
                Controls.Slider {
                    width: parent.width; from: 0; to: 100; stepSize: 1
                    value: panel.audio.percent(panel.audio.sink)
                    enabled: !!panel.audio.sink && panel.audio.sink.volumeWritable
                    Accessible.name: "Volumen de salida"
                    onMoved: panel.audio.setVolume(panel.audio.sink, value)
                }
                Repeater {
                    model: sinks
                    delegate: Tool {
                        required property var model
                        width: parent.width; height: 28
                        icon: model.Default ? "check" : "speaker-high"
                        label: model.Description; clip: true
                        onClicked: model.PulseObject.default = true
                    }
                }
            }
            Column {
                width: parent.width; visible: !!panel.audio.source
                Row {
                    width: parent.width; height: 28
                    Tool { icon: panel.audio.source && panel.audio.source.muted ? "microphone-slash" : "microphone"; description: "Silenciar micrófono"; onClicked: panel.audio.toggleMute(panel.audio.source, true) }
                    UiText { width: parent.width - 28; height: 28; text: "Micrófono"; color: Theme.secondary }
                }
                Controls.Slider {
                    width: parent.width; from: 0; to: 100; stepSize: 1
                    value: panel.audio.percent(panel.audio.source)
                    enabled: !!panel.audio.source && panel.audio.source.volumeWritable
                    Accessible.name: "Volumen de micrófono"
                    onMoved: panel.audio.setVolume(panel.audio.source, value, true)
                }
            }
            Repeater {
                model: brightness.displays
                delegate: Column {
                    id: brightnessDisplay
                    required property var model
                    width: content.width; visible: brightness.isBrightnessAvailable
                    UiText { width: parent.width; height: 26; text: "Brillo · " + brightnessDisplay.model.label; elide: Text.ElideRight }
                    Controls.Slider {
                        width: parent.width; from: 0; to: brightnessDisplay.model.maxBrightness; stepSize: 1
                        value: brightnessDisplay.model.brightness; Accessible.name: "Brillo de " + brightnessDisplay.model.label
                        onMoved: brightness.setBrightness(brightnessDisplay.model.displayName, Math.round(value))
                    }
                }
            }
            UiText {
                width: parent.width; height: visible ? 28 : 0
                visible: battery.hasInternalBatteries && battery.hasCumulative
                text: "Batería · " + battery.percent + " %" + (battery.pluggedIn ? " · Conectada" : "")
            }
            Controls.ComboBox {
                width: parent.width; visible: power.profiles.length > 0
                model: power.profiles; currentIndex: power.profiles.indexOf(power.activeProfile)
                Accessible.name: "Perfil de energía"
                onActivated: power.setProfile(currentText)
            }
            UiText { width: parent.width; height: visible ? 32 : 0; visible: !!power.profileError; text: power.profileError; wrapMode: Text.Wrap }
            Controls.Switch {
                width: parent.width; text: "No molestar"; checked: panel.notifications.inhibited
                onToggled: panel.notifications.setInhibited(checked)
            }
            Rectangle { width: parent.width; height: 1; color: Theme.border }
            Tool { width: parent.width; height: 32; icon: "gear"; label: "Configuración del sistema"; onClicked: panel.openSettings() }
            UiText { width: parent.width; height: visible ? implicitHeight : 0; visible: !!panel.errorText; text: panel.errorText; wrapMode: Text.Wrap; color: Theme.secondary }
        }
    }
}
