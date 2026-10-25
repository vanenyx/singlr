pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
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
    implicitHeight: 560
    readonly property string page: pages.currentItem ? pages.currentItem.objectName : "main"
    readonly property alias navigation: pages
    property var networkSource: availableNetworks
    property var networkActions: networkHandler
    property var selectedNetwork: ({})
    property string selectedKey: ""
    property var selectedDevice: null
    function openPage(name) {
        if (pages.busy) return;
        pages.pushItem(name === "wifi" ? wifiComponent : bluetoothComponent);
    }
    function openNetwork(data, passwordPage) {
        if (!passwordPage) return;
        secretRetry = false;
        selectedNetwork = data;
        selectedKey = data.Uuid ? "uuid:" + data.Uuid : "ssid:" + JSON.stringify([data.Ssid, data.SecurityType]);
        pages.pushItem(networkComponent, {passwordPage: passwordPage});
    }
    function resetPages() { if (pages.depth > 1) pages.popToIndex(0, Controls.StackView.Immediate); }
    function openNetworkMenu(data, anchor, px, py) {
        selectedNetwork = data;
        selectedKey = data.Uuid ? "uuid:" + data.Uuid : "ssid:" + JSON.stringify([data.Ssid, data.SecurityType]);
        const entries = [{label: data.ConnectionState === Network.Enums.Activated ? "Desconectar" : "Conectar", icon: "wifi-high", shortcut: "⏎", action: "wifi"}];
        if (data.Uuid) entries.push({label: "Olvidar red", icon: "trash", shortcut: "Supr", action: "forgetWifi", destructive: true, confirmation: "¿Olvidar red? Pulsa de nuevo"});
        entries.push({label: "Ajustes…", icon: "gear", separator: true, action: "wifiSettings"});
        contextMenu.entries = entries;
        contextMenu.showAt(anchor, px, py);
    }
    function openDeviceMenu(device, anchor, px, py) {
        selectedDevice = device; errorText = "";
        contextMenu.entries = [
            {label: device.connected ? "Desconectar" : "Conectar", icon: "bluetooth", shortcut: "⏎", action: "bluetooth"},
            {label: "Olvidar dispositivo", icon: "trash", destructive: true, confirmation: "¿Olvidar? Pulsa de nuevo", action: "forgetBluetooth"},
            {label: "Ajustes…", icon: "gear", separator: true, action: "bluetoothSettings"}
        ];
        contextMenu.showAt(anchor, px, py);
    }
    ContextMenu {
        id: contextMenu; objectName: "controlContextMenu"; parent: panel
        onTriggered: entry => {
            const n = panel.selectedNetwork;
            if (entry.action === "forgetWifi") panel.networkActions.removeConnection(n.ConnectionPath);
            else if (entry.action === "wifiSettings") KCMUtils.KCMLauncher.openSystemSettings("kcm_networkmanagement");
            else if (entry.action === "bluetoothSettings") KCMUtils.KCMLauncher.openSystemSettings("kcm_bluetooth");
            else if (entry.action === "wifi") {
                if (n.ConnectionState === Network.Enums.Activated) panel.networkActions.deactivateConnection(n.ConnectionPath, n.DevicePath);
                else if (n.Uuid) panel.networkActions.activateConnection(n.ConnectionPath, n.DevicePath, n.SpecificPath);
                else if (n.SecurityType === Network.Enums.NoneSecurity || n.SecurityType === Network.Enums.OWE) panel.networkActions.addAndActivateConnection(n.DevicePath, n.SpecificPath);
                else if ([Network.Enums.StaticWep, Network.Enums.WpaPsk, Network.Enums.Wpa2Psk, Network.Enums.SAE].indexOf(n.SecurityType) >= 0) Qt.callLater(() => panel.openNetwork(n, true));
                else KCMUtils.KCMLauncher.openSystemSettings("kcm_networkmanagement");
            } else {
                const device = panel.selectedDevice;
                if (!device) return;
                const call = entry.action === "forgetBluetooth" ? device.adapter.removeDevice(device) : device.connected ? device.disconnectFromDevice() : device.connectToDevice();
                call.finished.connect(function(result) { if (result.error) panel.errorText = result.errorText; });
            }
        }
    }
    // Context property supplied only by the native session launcher.
    // qmllint disable unqualified
    property var secrets: typeof SinglrSecrets !== "undefined" ? SinglrSecrets : null
    // qmllint enable unqualified
    property string secretId: ""
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
        if (pages.depth > 1) { cancelSecret(); pages.popCurrentItem(pages.busy ? Controls.StackView.Immediate : Controls.StackView.PopTransition); }
        else closed();
        forceActiveFocus();
    }
    Connections {
        target: panel.secrets
        function onSecretRequested(requestId, ssid, connectionUuid, retry) {
            panel.cancelSecret(); panel.openRequested(); panel.resetPages();
            pages.pushItem(wifiComponent, {}, Controls.StackView.Immediate);
            panel.selectedKey = "";
            panel.secretId = requestId; panel.secretRetry = retry;
            panel.selectedNetwork = {Name: ssid, Ssid: ssid, Uuid: connectionUuid, Signal: 0, SecurityType: Network.Enums.Wpa2Psk, ConnectionState: Network.Enums.Deactivated};
            pages.pushItem(networkComponent, {passwordPage: true});
        }
        function onRequestCancelled(requestId) {
            if (panel.secretId === requestId) { panel.secretId = ""; if (panel.page === "network") panel.back(); }
        }
    }
    property string errorText: ""
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
        else { contextMenu.close(); cancelSecret(); errorText = ""; resetPages(); }
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
    Volume.SinkModel { id: sinks }
    Controls.StackView {
        id: pages; anchors.fill: parent; anchors.margins: 16; clip: true
        initialItem: mainComponent
        pushEnter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 120 } }
        pushExit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 120 } }
        popEnter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 120 } }
        popExit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 120 } }
        replaceEnter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 120 } }
        replaceExit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 120 } }
    }
    Component {
        id: mainComponent
        Controls.ScrollView {
            // Sin barras visibles: se desplaza con rueda o gesto.
            Controls.ScrollBar.vertical.policy: Controls.ScrollBar.AlwaysOff
            Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
        objectName: "main"
        Component.onCompleted: Qt.callLater(function() { panel.implicitHeight = Math.min(760, content.implicitHeight + 32); })
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
                width: parent.width; height: 36; spacing: 10
                Toggle { width: 34; checked: enabledConnections.wirelessEnabled; enabled: enabledConnections.wirelessHwEnabled; Accessible.name: "Wi-Fi"; onToggled: networkHandler.enableWireless(checked) }
                Column {
                    width: parent.width - 82
                    UiText { height: 18; text: "Wi-Fi" }
                    UiText { width: parent.width; height: 18; text: enabledConnections.wirelessEnabled ? network.activeConnections || "Sin conexión" : "Desactivado"; color: Theme.secondary; font.pixelSize: 11; elide: Text.ElideRight }
                }
                Tool { icon: "caret-right"; description: "Redes Wi-Fi"; onClicked: panel.openPage("wifi") }
            }
            Row {
                width: parent.width; height: 36; spacing: 10
                Toggle { width: 34; checked: panel.bluetoothEnabled; enabled: Bluetooth.Manager.adapters.length > 0; Accessible.name: "Bluetooth"; onToggled: panel.setBluetooth(checked) }
                Column {
                    width: parent.width - 82
                    UiText { height: 18; text: "Bluetooth" }
                    UiText { width: parent.width; height: 18; color: Theme.secondary; font.pixelSize: 11; elide: Text.ElideRight
                        text: !panel.bluetoothEnabled ? "Desactivado" : Bluetooth.Manager.devices.filter(device => device.connected).map(device => device.friendlyName).join(", ") || "Sin conexión"
                    }
                }
                Tool { icon: "caret-right"; description: "Dispositivos Bluetooth"; onClicked: panel.openPage("bluetooth") }
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
    }
    Component {
        id: wifiComponent
        Item {
            objectName: "wifi"
            Row {
                width: parent.width; height: 36
                Tool { objectName: "pageBack"; icon: "caret-left"; description: "Volver"; onClicked: panel.back() }
                UiText { width: parent.width - 62; height: 36; text: "Wi-Fi"; weight: 600 }
                Toggle { width: 34; checked: enabledConnections.wirelessEnabled; Accessible.name: "Wi-Fi"; onToggled: networkHandler.enableWireless(checked) }
            }
            StableWifiList {
                id: wifiList; objectName: "wifiList"; y: 44; width: parent.width; height: parent.height - 80
                handler: panel.networkActions; sourceModel: panel.networkSource
                pageActive: panel.opened && panel.page === "wifi"
                onNetworkUpdated: (key, data) => { if (key === panel.selectedKey || (panel.secretId && data.Ssid === panel.selectedNetwork.Ssid)) panel.selectedNetwork = data; }
                onPasswordRequested: data => panel.openNetwork(data, true)
                onMenuRequested: (data, anchor, px, py) => panel.openNetworkMenu(data, anchor, px, py)
                onSettingsRequested: KCMUtils.KCMLauncher.openSystemSettings("kcm_networkmanagement")
            }
            ControlRow { y: parent.height - 36; width: parent.width; height: 36; text: "Más ajustes de red…"; glyph: "gear"; onClicked: KCMUtils.KCMLauncher.openSystemSettings("kcm_networkmanagement") }
        }
    }
    Component {
        id: networkComponent
        Controls.ScrollView {
            // Sin barras visibles: se desplaza con rueda o gesto.
            Controls.ScrollBar.vertical.policy: Controls.ScrollBar.AlwaysOff
            Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
            id: networkPage
            objectName: "network"
            property bool passwordPage: false
            contentWidth: availableWidth; clip: true
            WifiPage {
                width: networkPage.availableWidth
                networkData: panel.selectedNetwork; handler: panel.networkActions
                passwordPage: networkPage.passwordPage; requestId: panel.secretId; retry: panel.secretRetry
                onBackRequested: panel.back()
                onPasswordRequested: data => panel.openNetwork(data, true)
                onSecretSubmitted: password => { const id = panel.secretId; panel.secretId = ""; if (id && panel.secrets) panel.secrets.provide(id, password); }
                onSettingsRequested: KCMUtils.KCMLauncher.openSystemSettings("kcm_networkmanagement")
            }
        }
    }
    Component {
        id: bluetoothComponent
        Item {
            objectName: "bluetooth"
            Row {
                width: parent.width; height: 36
                Tool { objectName: "pageBack"; icon: "caret-left"; description: "Volver"; onClicked: panel.back() }
                UiText { width: parent.width - 28; height: 36; text: "Bluetooth"; weight: 600 }
            }
            ListView {
                id: bluetoothList; y: 44; width: parent.width; height: parent.height - 80; clip: true
                reuseItems: false; currentIndex: -1
                model: bluetoothStable.rows
                add: null; remove: null; displaced: null; move: null; populate: null
                StableDeviceModel { id: bluetoothStable }
                function refresh() {
                    bluetoothStable.sync(Bluetooth.Manager.devices.filter(device => device.paired).map(device => ({deviceKey: device.address, payload: {name: device.friendlyName, connected: device.connected, device: device}, rank: 0, active: device.connected})));
                }
                Timer { interval: 100; running: panel.opened; repeat: true; triggeredOnStart: true; onTriggered: bluetoothList.refresh() }
                delegate: ControlRow {
                    required property var payload
                    width: bluetoothList.width; height: 36; glyph: "bluetooth"; text: payload.name; status: payload.connected ? "Conectado" : ""
                    id: deviceRow
                    actionText: "…"
                    onClicked: panel.openDeviceMenu(payload.device, deviceRow, width - 28, height)
                    onActionTriggered: panel.openDeviceMenu(payload.device, deviceRow, width - 28, height)
                    TapHandler { acceptedButtons: Qt.RightButton; onTapped: point => panel.openDeviceMenu(deviceRow.payload.device, deviceRow, point.position.x, point.position.y) }
                    Keys.onMenuPressed: panel.openDeviceMenu(payload.device, deviceRow, width - 28, height)
                }
            }
            UiText { y: parent.height - 36; width: parent.width; height: 36; text: panel.errorText; color: "#ef9a9a"; Accessible.role: Accessible.AlertMessage }
        }
    }
}
