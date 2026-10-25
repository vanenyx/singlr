pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
import org.kde.kitemmodels as ItemModels
import org.kde.kcmutils as KCMUtils
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
    signal openRequested()
    implicitWidth: 340
    implicitHeight: Math.min(760, (page === "main" ? content.implicitHeight : detailContent.implicitHeight) + 32)
    Behavior on implicitHeight { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    property string page: "main"
    // Context property supplied only by the native session launcher.
    // qmllint disable unqualified
    property var secrets: typeof SinglrSecrets !== "undefined" ? SinglrSecrets : null
    // qmllint enable unqualified
    property string secretId: ""
    property string secretSsid: ""
    property string secretUuid: ""
    property bool secretRetry: false
    readonly property bool bluetoothEnabled: !Bluetooth.Manager.bluetoothBlocked && Bluetooth.Manager.adapters.some(adapter => adapter.powered)
    function setBluetooth(value) {
        Bluetooth.Manager.bluetoothBlocked = !value;
        for (const adapter of Bluetooth.Manager.adapters) adapter.powered = value;
    }
    function cancelSecret() {
        const request = secretId;
        secretId = "";
        if (request && secrets) secrets.cancel(request);
    }
    function back() {
        if (page !== "main") { cancelSecret(); editingWifi = ""; page = "main"; forceActiveFocus(); }
        else closed();
    }
    Connections {
        target: panel.secrets
        function onSecretRequested(requestId, ssid, connectionUuid, retry) {
            if (panel.secretId && panel.secretId !== requestId) panel.cancelSecret();
            panel.secretSsid = ssid; panel.secretUuid = connectionUuid; panel.secretRetry = retry;
            panel.openRequested(); panel.page = "wifi"; panel.secretId = requestId;
            Qt.callLater(function() {
                const viewport = detailScroll.contentItem as Flickable;
                if (viewport) viewport.contentY = 0;
            });
        }
        function onRequestCancelled(requestId) {
            if (panel.secretId === requestId) panel.secretId = "";
        }
    }
    property string errorText: ""
    property string editingWifi: ""
    property bool opened: true
    palette.window: Theme.raised
    palette.windowText: Theme.text
    palette.text: Theme.text
    palette.button: Theme.hover
    palette.buttonText: Theme.text
    palette.base: Theme.panel
    palette.accent: Theme.control
    palette.highlightedText: "#16171a"
    palette.highlight: Theme.control
    onOpenedChanged: {
        if (opened) networkHandler.requestScan();
        else { cancelSecret(); editingWifi = ""; errorText = ""; page = "main"; }
    }
    Component.onCompleted: if (opened) networkHandler.requestScan()
    Timer { interval: 15000; running: panel.opened; repeat: true; onTriggered: networkHandler.requestScan() }
    function openSettings() {
        if (settingsApp.count > 0 && settingsApp.trigger(0, "", null)) panel.closed();
        else panel.errorText = "Configuración no encontrada en el catálogo.";
    }
    Keys.onEscapePressed: back()
    Rectangle { anchors.fill: parent; radius: 12; color: "#ed191a1b"; border.color: Theme.focusBorder }
    Kicker.SimpleFavoritesModel { id: settingsApp; favorites: ["systemsettings.desktop"] }
    Battery.BatteryControlModel { id: battery }
    Power.PowerProfilesControl { id: power }
    Brightness.ScreenBrightnessControl { id: brightness }
    Network.NetworkStatus { id: network }
    Network.EnabledConnections { id: enabledConnections }
    Network.Handler { id: networkHandler }
    Network.NetworkModel { id: networks }
    Network.AppletProxyModel { id: availableNetworks; sourceModel: networks }
    ItemModels.KSortFilterProxyModel {
        id: signalNetworks; sourceModel: availableNetworks
        sortRoleName: "Signal"; sortOrder: Qt.DescendingOrder; sortColumn: 0
    }
    Volume.SinkModel { id: sinks }
    Controls.ScrollView {
        x: panel.page === "main" ? 16 : -16; y: 16
        width: parent.width - 32; height: parent.height - 32
        opacity: panel.page === "main" ? 1 : 0
        visible: opacity > 0; enabled: panel.page === "main"
        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 160 } }
        contentWidth: availableWidth
        clip: true
        Column {
            id: content; width: parent.width; spacing: 8
            Row {
                width: parent.width; height: 28
                UiText { width: parent.width - 28; height: 28; text: "Centro de control"; weight: 600 }
                Tool { icon: "x"; description: "Cerrar"; onClicked: panel.closed() }
            }
            Row {
                width: parent.width; height: 44; spacing: 10
                Toggle { width: 34; checked: enabledConnections.wirelessEnabled; enabled: enabledConnections.wirelessHwEnabled; Accessible.name: "Wi-Fi"; onToggled: networkHandler.enableWireless(checked) }
                Column {
                    width: parent.width - 82
                    UiText { height: 22; text: "Wi-Fi" }
                    UiText { width: parent.width; height: 20; text: enabledConnections.wirelessEnabled ? network.activeConnections || "Sin conexión" : "Desactivado"; color: Theme.secondary; font.pixelSize: 11; elide: Text.ElideRight }
                }
                Tool { icon: "caret-right"; description: "Redes Wi-Fi"; onClicked: panel.page = "wifi" }
            }
            Row {
                width: parent.width; height: 44; spacing: 10
                Toggle { width: 34; checked: panel.bluetoothEnabled; enabled: Bluetooth.Manager.adapters.length > 0; Accessible.name: "Bluetooth"; onToggled: panel.setBluetooth(checked) }
                Column {
                    width: parent.width - 82
                    UiText { height: 22; text: "Bluetooth" }
                    UiText { width: parent.width; height: 20; color: Theme.secondary; font.pixelSize: 11; elide: Text.ElideRight
                        text: !panel.bluetoothEnabled ? "Desactivado" : Bluetooth.Manager.devices.filter(device => device.connected).map(device => device.friendlyName).join(", ") || "Sin conexión"
                    }
                }
                Tool { icon: "caret-right"; description: "Dispositivos Bluetooth"; onClicked: panel.page = "bluetooth" }
            }
            Rectangle { width: parent.width; height: 1; color: Theme.border }
            Column {
                width: parent.width; visible: !!panel.audio.sink
                Row {
                    width: parent.width; height: 28
                    Tool { icon: panel.audio.sink && panel.audio.sink.muted ? "speaker-slash" : "speaker-high"; description: "Silenciar salida"; onClicked: panel.audio.toggleMute(panel.audio.sink) }
                    UiText { width: parent.width - 28; height: 28; text: panel.audio.sink ? panel.audio.sink.description : ""; elide: Text.ElideRight }
                }
                SliderControl {
                    width: parent.width; from: 0; to: 100; stepSize: 1
                    value: panel.audio.percent(panel.audio.sink)
                    enabled: !!panel.audio.sink && panel.audio.sink.volumeWritable
                    Accessible.name: "Volumen de salida"
                    onMoved: panel.audio.setVolume(panel.audio.sink, value)
                }
                Repeater {
                    model: sinks
                    delegate: ControlRow {
                        required property var model
                        width: parent.width; height: 36
                        glyph: model.Default ? "check" : "speaker-high"
                        text: model.Description; clip: true
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
                SliderControl {
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
                    SliderControl {
                        width: parent.width; from: 0; to: brightnessDisplay.model.maxBrightness; stepSize: 1
                        value: brightnessDisplay.model.brightness; Accessible.name: "Brillo de " + brightnessDisplay.model.label
                        onMoved: brightness.setBrightness(brightnessDisplay.model.displayName, Math.round(value))
                    }
                }
            }
            Toggle {
                width: parent.width; text: "No molestar"; checked: panel.notifications.inhibited
                onToggled: panel.notifications.setInhibited(checked)
            }
            Rectangle { width: parent.width; height: 1; color: Theme.border }
            ControlRow { width: parent.width; glyph: "gear"; text: "Configuración del sistema"; onClicked: panel.openSettings() }
            UiText { width: parent.width; height: visible ? implicitHeight : 0; visible: !!panel.errorText; text: panel.errorText; wrapMode: Text.Wrap; color: Theme.secondary }
            Column {
                width: parent.width; spacing: 8
                visible: battery.hasInternalBatteries && battery.hasCumulative
                Rectangle { width: parent.width; height: 1; color: Theme.border }
                Row {
                    spacing: 8; height: 30
                    Icon { name: "battery-high"; width: 22; height: 22; anchors.verticalCenter: parent.verticalCenter }
                    UiText { height: 30; text: battery.percent + " %"; font.pixelSize: 20; weight: 590 }
                }
                UiText {
                    width: parent.width; color: Theme.secondary
                    text: {
                        const minutes = Math.floor(battery.smoothedRemainingMsec / 60000);
                        const duration = Math.floor(minutes / 60) + " h " + String(minutes % 60).padStart(2, "0") + " min";
                        if (battery.state === Battery.BatteryControlModel.Charging) return "Cargando" + (minutes > 0 ? " · llena en " + duration : "");
                        if (battery.pluggedIn) return battery.state === Battery.BatteryControlModel.FullyCharged ? "Conectado · batería llena" : "Conectado, sin cargar";
                        return "Batería" + (minutes > 0 ? " · quedan " + duration : "");
                    }
                }
                Rectangle {
                    width: parent.width; height: 3; radius: 2; color: "#1fffffff"
                    Rectangle { width: parent.width * battery.percent / 100; height: 3; radius: 2; color: Theme.control }
                }
                Row {
                    width: parent.width; spacing: 2; visible: power.profiles.length > 0
                    Repeater {
                        model: [{key: "power-saver", title: "Ahorro"}, {key: "balanced", title: "Equilibrado"}, {key: "performance", title: "Rendimiento"}]
                        delegate: Controls.Button {
                            id: profileButton
                            required property var modelData
                            width: (content.width - 4) / 3; height: 30
                            text: modelData.title; enabled: power.profiles.indexOf(modelData.key) >= 0
                            Accessible.name: "Perfil " + text
                            Accessible.checkable: true; Accessible.checked: power.activeProfile === modelData.key
                            opacity: enabled ? 1 : 0.4
                            contentItem: UiText { text: profileButton.text; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; color: power.activeProfile === profileButton.modelData.key ? "#16171a" : Theme.secondary }
                            background: Rectangle { radius: 5; color: power.activeProfile === profileButton.modelData.key ? Theme.control : profileButton.hovered ? Theme.hover : Theme.raised; border.color: profileButton.visualFocus ? Theme.control : "transparent" }
                            onClicked: power.setProfile(modelData.key)
                        }
                    }
                }
                UiText { width: parent.width; visible: !!power.profileError; text: power.profileError; color: "#ef9a9a"; wrapMode: Text.Wrap }
            }
        }
    }
    Controls.ScrollView {
        id: detailScroll
        x: panel.page === "main" ? 48 : 16; y: 16
        width: parent.width - 32; height: parent.height - 32
        opacity: panel.page === "main" ? 0 : 1
        visible: opacity > 0; enabled: panel.page !== "main"
        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 160 } }
        contentWidth: availableWidth; clip: true
        Column {
            id: detailContent; width: detailScroll.availableWidth; spacing: 8
            Row {
                width: parent.width; height: 36; spacing: 8
                Tool { icon: "caret-left"; description: "Volver"; onClicked: panel.back() }
                UiText { width: parent.width - 78; height: 36; weight: 600; text: panel.page === "bluetooth" ? "Bluetooth" : "Wi-Fi" }
                Toggle {
                    width: 34; Accessible.name: panel.page === "wifi" ? "Wi-Fi" : "Bluetooth"
                    checked: panel.page === "wifi" ? enabledConnections.wirelessEnabled : panel.bluetoothEnabled
                    enabled: panel.page === "wifi" ? enabledConnections.wirelessHwEnabled : Bluetooth.Manager.adapters.length > 0
                    onToggled: { if (panel.page === "wifi") networkHandler.enableWireless(checked); else panel.setBluetooth(checked); }
                }
            }
            WifiRow {
                objectName: "secretWifiRow"
                width: parent.width; visible: panel.page === "wifi" && !!panel.secretId
                height: visible ? implicitHeight : 0
                handler: networkHandler
                networkData: ({Name: panel.secretSsid, Ssid: panel.secretSsid, Uuid: panel.secretUuid,
                    DevicePath: "", SpecificPath: "/", ConnectionPath: "", Signal: 0,
                    SecurityType: Network.Enums.Wpa2Psk, Type: Network.Enums.Wireless,
                    ItemType: Network.NetworkModelItem.AvailableAccessPoint, ConnectionState: Network.Enums.Deactivated})
                secretRequestId: panel.secretId; secretRetry: panel.secretRetry
                editing: visible && panel.opened
                onSecretSubmitted: password => { const request = panel.secretId; panel.secretId = ""; if (request && panel.secrets) panel.secrets.provide(request, password); }
                onSecretCancelled: panel.cancelSecret()
                onEditFinished: panel.cancelSecret()
                onSettingsRequested: KCMUtils.KCMLauncher.openSystemSettings("kcm_networkmanagement")
            }
            Column {
                width: parent.width; visible: panel.page === "wifi" && enabledConnections.wirelessEnabled
                // Two groups preserve strict signal ordering after the active network.
                Repeater {
                    model: signalNetworks
                    delegate: WifiRow {
                        required property var model
                        width: detailContent.width; networkData: model; handler: networkHandler
                        visible: panel.page === "wifi" && eligible && connected && !(panel.secretId && networkData.Ssid === panel.secretSsid)
                        height: visible ? implicitHeight : 0
                        editing: visible && panel.opened && panel.editingWifi === identity
                        onEditRequested: panel.editingWifi = identity
                        onEditFinished: panel.editingWifi = ""
                        onSettingsRequested: KCMUtils.KCMLauncher.openSystemSettings("kcm_networkmanagement")
                    }
                }
                Repeater {
                    model: signalNetworks
                    delegate: WifiRow {
                        required property var model
                        width: detailContent.width; networkData: model; handler: networkHandler
                        visible: panel.page === "wifi" && eligible && !connected && !(panel.secretId && networkData.Ssid === panel.secretSsid)
                        height: visible ? implicitHeight : 0
                        editing: visible && panel.opened && panel.editingWifi === identity
                        onEditRequested: panel.editingWifi = identity
                        onEditFinished: panel.editingWifi = ""
                        onSettingsRequested: KCMUtils.KCMLauncher.openSystemSettings("kcm_networkmanagement")
                    }
                }
                ControlRow { width: parent.width; glyph: "gear"; text: "Más ajustes de red…"; onClicked: KCMUtils.KCMLauncher.openSystemSettings("kcm_networkmanagement") }
            }
            Column {
                width: parent.width; visible: panel.page === "bluetooth" && panel.bluetoothEnabled
                Repeater {
                    model: Bluetooth.Manager.devices
                    delegate: ControlRow {
                        required property var modelData
                        width: parent.width; height: visible ? 36 : 0
                        visible: modelData.paired
                        glyph: "bluetooth"
                        status: modelData.connected ? "Conectado" : ""
                        text: modelData.friendlyName; clip: true
                        onClicked: {
                            const call = modelData.connected ? modelData.disconnectFromDevice() : modelData.connectToDevice();
                            call.finished.connect(function(result) { if (result.error) panel.errorText = result.errorText; });
                        }
                    }
                }
            }
            UiText { width: parent.width; visible: !!panel.errorText; text: panel.errorText; color: "#ef9a9a"; wrapMode: Text.Wrap }
        }
    }
}
