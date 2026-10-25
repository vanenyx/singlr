pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import "../Ui/Focus.js" as Focus
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
    function focusFirst() { Focus.advance(panel, panel, true); }
    Keys.onTabPressed: Focus.advance(panel, Window.window.activeFocusItem, true)
    Keys.onBacktabPressed: Focus.advance(panel, Window.window.activeFocusItem, false)
    Keys.onUpPressed: Focus.advance(panel, Window.window.activeFocusItem, false)
    Keys.onDownPressed: Focus.advance(panel, Window.window.activeFocusItem, true)
    Accessible.role: Accessible.Pane
    Accessible.name: "Centro de control"

    // Qt's screen list is maintained by KWin; use the standard KScreen KCM.
    property int outputCount: Qt.application.screens.length
    property var nightLightBackend: NightLight
    property bool contextMenuOpen: false
    readonly property var contextMenu: contextMenuLoader.item
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
    property var wifiView: null
    property var selectedNetwork: ({})
    property string selectedKey: ""
    property var selectedDevice: null
    function openPage(name) {
        if (pages.busy) return;
        pages.pushItem(name === "wifi" ? wifiComponent : bluetoothComponent);
    }
    function openNetwork(data) {
        if (panel.page === "wifi") panel.wifiView.showPassword(data);
    }
    function resetPages() { if (pages.depth > 1) pages.popToIndex(0, Controls.StackView.Immediate); }
    function openNetworkMenu(data, anchor, px, py) {
        selectedNetwork = data;
        selectedKey = data.Uuid ? "uuid:" + data.Uuid : "ssid:" + JSON.stringify([data.Ssid, data.SecurityType]);
        const entries = [{label: data.ConnectionState === Network.Enums.Activated ? "Desconectar" : "Conectar", icon: "wifi-high", shortcut: "⏎", action: "wifi"}];
        if (data.Uuid) entries.push({label: "Olvidar red", icon: "trash", shortcut: "Supr", action: "forgetWifi", destructive: true, confirmation: "¿Olvidar red? Pulsa de nuevo"});
        entries.push({label: "Ajustes…", icon: "gear", separator: true, action: "wifiSettings"});
        contextMenuOpen = true;
        contextMenu.entries = entries;
        contextMenu.showAt(anchor, px, py);
    }
    function openDeviceMenu(device, anchor, px, py) {
        selectedDevice = device; errorText = "";
        contextMenuOpen = true;
        contextMenu.entries = [
        {label: device.connected ? "Desconectar" : "Conectar", icon: "bluetooth", shortcut: "⏎", action: "bluetooth"},
        {label: "Olvidar dispositivo", icon: "trash", destructive: true, confirmation: "¿Olvidar? Pulsa de nuevo", action: "forgetBluetooth"},
        {label: "Ajustes…", icon: "gear", separator: true, action: "bluetoothSettings"}
        ];
        contextMenu.showAt(anchor, px, py);
    }
    DeferredLoader {
        id: contextMenuLoader; objectName: "controlMenuLoader"; opened: panel.contextMenuOpen
        sourceComponent: Component {
            ContextMenu {
                id: contextMenu; onClosed: panel.contextMenuOpen = false; objectName: "controlContextMenu"; parent: panel
                onTriggered: entry => {
                    const n = panel.selectedNetwork;
                    if (entry.action === "forgetWifi") panel.networkActions.removeConnection(n.ConnectionPath);
                    else if (entry.action === "wifiSettings") KCMUtils.KCMLauncher.openSystemSettings("kcm_networkmanagement");
                    else if (entry.action === "bluetoothSettings") KCMUtils.KCMLauncher.openSystemSettings("kcm_bluetooth");
                    else if (entry.action === "wifi") {
                        if (n.ConnectionState === Network.Enums.Activated) panel.networkActions.deactivateConnection(n.ConnectionPath, n.DevicePath);
                        else Qt.callLater(() => { if (panel.wifiView) panel.wifiView.connectNetwork(n); });
                    } else {
                        const device = panel.selectedDevice;
                        if (!device) return;
                        if (entry.action === "forgetBluetooth") {
                            const call = device.adapter.removeDevice(device);
                            panel.watchOperation(call, function(result) { if (result.error) panel.errorText = result.errorText; });
                        } else panel.connectDevice(device);
                    }
                }
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
        if (panel.page === "wifi") panel.wifiView.closePassword();
        if (pages.depth > 1) { cancelSecret(); pages.popCurrentItem(pages.busy ? Controls.StackView.Immediate : Controls.StackView.PopTransition); }
        else closed();
        forceActiveFocus();
    }
    Connections {
        target: panel.secrets
        function onSecretRequested(requestId, ssid, connectionUuid, retry) {
            if (panel.secretId !== requestId) panel.cancelSecret();
            panel.openRequested();
            if (panel.page !== "wifi") {
                panel.resetPages(); pages.pushItem(wifiComponent, {}, Controls.StackView.Immediate);
            }
            panel.secretRetry = retry;
            panel.wifiView.showPassword({Ssid: ssid, Uuid: connectionUuid}, requestId, retry);
            panel.secretId = requestId;
        }
        function onRequestCancelled(requestId) {
            if (panel.secretId === requestId) { panel.secretId = ""; if (panel.page === "wifi") panel.wifiView.closePassword(); }
        }
    }
    property var bluetoothDevices: Bluetooth.Manager.devices
    property var deviceOperations: ({})
    property var deviceBusy: ({})
    // Operation signals must disconnect when the cached panel is released.
    Component {
        id: operationWatcher
        Connections {
            required property var operation
            target: operation
            signal completed(var result)
            function onFinished(result) { completed(result); destroy(); }
        }
    }
    function watchOperation(call, callback) {
        const watcher = operationWatcher.createObject(panel, {operation: call});
        watcher.completed.connect(callback);
    }
    function connectDevice(device) {
        const key = device.address || device.friendlyName || "device";
        if (deviceBusy[key]) return;
        deviceBusy = Object.assign({}, deviceBusy, {[key]: true});
        deviceOperations = Object.assign({}, deviceOperations, {[key]: device.paired === false ? "Emparejando…" : device.connected ? "Desconectando…" : "Conectando…"});
        const pairing = device.paired === false;
        const call = pairing ? device.pair() : device.connected ? device.disconnectFromDevice() : device.connectToDevice();
        panel.watchOperation(call, function(result) {
            const busy = Object.assign({}, panel.deviceBusy); delete busy[key]; panel.deviceBusy = busy;
            const next = Object.assign({}, panel.deviceOperations); delete next[key];
            if (result.error) next[key] = result.errorText;
            panel.deviceOperations = next;
            if (!result.error && pairing && device.paired && !device.connected) panel.connectDevice(device);
        });
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
    palette.highlightedText: Theme.onControl
    palette.highlight: Theme.control
    onOpenedChanged: {
        if (opened) networkHandler.requestScan();
        else { if (contextMenu) contextMenu.close(); if (panel.page === "wifi") panel.wifiView.closePassword(); cancelSecret(); errorText = ""; resetPages(); }
    }
    Component.onCompleted: if (opened) networkHandler.requestScan()
    Timer { interval: 15000; running: panel.opened; repeat: true; onTriggered: networkHandler.requestScan() }
    function openSinglrSettings() {
        if (singlrSettingsApp.count > 0 && singlrSettingsApp.trigger(0, "", null)) panel.closed();
        else panel.errorText = "Ajustes de Singlr no encontrados en el catálogo.";
    }
    Kicker.SimpleFavoritesModel { id: singlrSettingsApp; favorites: ["singlr-settings.desktop"] }
    function openSettings() {
        if (settingsApp.count > 0 && settingsApp.trigger(0, "", null)) panel.closed();
        else panel.errorText = "Configuración no encontrada en el catálogo.";
    }
    Keys.onEscapePressed: back()
    Rectangle { anchors.fill: parent; radius: 12; color: Theme.surface; border.color: Theme.surfaceBorder }
    Kicker.SimpleFavoritesModel { id: settingsApp; favorites: ["systemsettings.desktop"] }
    Battery.BatteryControlModel { id: batteryModel }
    Power.PowerProfilesControl { id: powerProfiles }
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
        pushEnter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.duration } }
        pushExit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Motion.duration } }
        popEnter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.duration } }
        popExit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Motion.duration } }
        replaceEnter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.duration } }
        replaceExit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Motion.duration } }
    }
    Component {
        id: mainComponent
        Controls.ScrollView {
            // Sin barras visibles: se desplaza con rueda o gesto.
            Controls.ScrollBar.vertical.policy: Controls.ScrollBar.AlwaysOff
            Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
        objectName: "main"
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
                Icon { name: "wifi-high"; width: 16; height: 36; font.pixelSize: 16; Accessible.name: "Wi-Fi" }
                UiText { width: parent.width - 108; height: 36; text: enabledConnections.wirelessEnabled ? network.activeConnections || "Sin conexión" : "Desactivado"; elide: Text.ElideRight }
                Tool { icon: "caret-right"; description: "Redes Wi-Fi"; onClicked: panel.openPage("wifi") }
            }
            Row {
                width: parent.width; height: 36; spacing: 10
                Toggle { width: 34; checked: panel.bluetoothEnabled; enabled: Bluetooth.Manager.adapters.length > 0; Accessible.name: "Bluetooth"; onToggled: panel.setBluetooth(checked) }
                Icon { name: "bluetooth"; width: 16; height: 36; font.pixelSize: 16; Accessible.name: "Bluetooth" }
                UiText { width: parent.width - 108; height: 36; elide: Text.ElideRight
                    text: !panel.bluetoothEnabled ? "Desactivado" : panel.bluetoothDevices.filter(device => device.connected).map(device => device.friendlyName).join(", ") || "Sin conexión"
                }
                Tool { icon: "caret-right"; description: "Dispositivos Bluetooth"; onClicked: panel.openPage("bluetooth") }
            }
            NowPlaying { width: parent.width; height: 36; players: panel.audio.mediaPlayers }
            Rectangle { width: parent.width; height: 1; color: Theme.border }
            Column {
                width: parent.width; visible: !!panel.audio.sink
                Row { width: parent.width; height: 36; spacing: 10
                    Tool { icon: panel.audio.sink && panel.audio.sink.muted ? "speaker-slash" : "speaker-high"; description: "Silenciar salida"; onClicked: panel.audio.toggleMute(panel.audio.sink) }
                    SliderControl { width: parent.width - 38; from: 0; to: 100; stepSize: 1; value: panel.audio.percent(panel.audio.sink); enabled: !!panel.audio.sink && panel.audio.sink.volumeWritable; Accessible.name: "Volumen de salida"; onMoved: panel.audio.setVolume(panel.audio.sink, value) }
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
                    width: parent.width; height: 36; spacing: 10
                    Tool { icon: panel.audio.source && panel.audio.source.muted ? "microphone-slash" : "microphone"; description: "Silenciar micrófono"; onClicked: panel.audio.toggleMute(panel.audio.source, true) }
                    SliderControl { width: parent.width - 38; from: 0; to: 100; stepSize: 1; value: panel.audio.percent(panel.audio.source); enabled: !!panel.audio.source && panel.audio.source.volumeWritable; Accessible.name: "Volumen de micrófono"; onMoved: panel.audio.setVolume(panel.audio.source, value, true) }
                }
            }
            Repeater {
                model: brightness.displays
                delegate: Row {
                    id: brightnessDisplay
                    required property var model
                    width: content.width; height: 36; spacing: 10; visible: brightness.isBrightnessAvailable
                    Icon { name: "sun"; width: 28; height: 36; font.pixelSize: 16; Accessible.name: "Brillo" }
                    SliderControl {
                        width: parent.width - 38; from: 0; to: brightnessDisplay.model.maxBrightness; stepSize: 1
                        value: brightnessDisplay.model.brightness; Accessible.name: "Brillo de " + brightnessDisplay.model.label
                        onMoved: brightness.setBrightness(brightnessDisplay.model.displayName, Math.round(value))
                    }
                }
            }
            NightLightRow { width: parent.width; backend: panel.nightLightBackend }
            Item {
                width: parent.width; height: 36
                // Reserve the row when outputs change in the background (P-011).
                ControlRow {
                    objectName: "displayLayoutRow"; anchors.fill: parent; visible: panel.outputCount > 1
                    glyph: "monitor"; text: "Disposición de pantallas"; actionText: "›"
                    onClicked: KCMUtils.KCMLauncher.openSystemSettings("kcm_kscreen")
                    onActionTriggered: KCMUtils.KCMLauncher.openSystemSettings("kcm_kscreen")
                }
            }
            Row { height: 36; width: parent.width; spacing: 10
                Icon { name: "bell-slash"; width: 28; height: 36; Accessible.name: "No molestar" }
                Toggle { width: 34; checked: panel.notifications.inhibited; Accessible.name: "No molestar"; onToggled: panel.notifications.setInhibited(checked) }
            }
            Rectangle { width: parent.width; height: 1; color: Theme.border }
            ControlRow { width: parent.width; glyph: "gear"; text: "Ajustes de Singlr"; onClicked: panel.openSinglrSettings() }
            ControlRow { width: parent.width; glyph: "gear"; text: "Configuración del sistema"; onClicked: panel.openSettings() }
            UiText { width: parent.width; height: visible ? implicitHeight : 0; visible: !!panel.errorText; text: panel.errorText; wrapMode: Text.Wrap; color: Theme.secondary }
            BatteryRow {
                width: parent.width; height: 36
                visible: batteryModel.hasInternalBatteries && batteryModel.hasCumulative
                battery: batteryModel; power: powerProfiles
                charging: batteryModel.state === Battery.BatteryControlModel.Charging
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
                Component.onCompleted: panel.wifiView = wifiList
                Component.onDestruction: if (panel.wifiView === wifiList) panel.wifiView = null
                pageActive: panel.opened && panel.page === "wifi"
                onNetworkUpdated: (key, data) => { if (key === panel.selectedKey || (panel.secretId && data.Ssid === panel.selectedNetwork.Ssid)) panel.selectedNetwork = data; }
                onSecretSubmitted: (requestId, password) => { if (panel.secretId === requestId) panel.secretId = ""; if (panel.secrets) panel.secrets.provide(requestId, password); }
                onPasswordCancelled: panel.cancelSecret()
                onMenuRequested: (data, anchor, px, py) => panel.openNetworkMenu(data, anchor, px, py)
                onSettingsRequested: KCMUtils.KCMLauncher.openSystemSettings("kcm_networkmanagement")
            }
            ControlRow { y: parent.height - 36; width: parent.width; height: 36; text: "Más ajustes de red…"; glyph: "gear"; onClicked: KCMUtils.KCMLauncher.openSystemSettings("kcm_networkmanagement") }
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
                id: bluetoothList; objectName: "bluetoothList"; y: 44; width: parent.width; height: parent.height - 80; clip: true
                reuseItems: false; currentIndex: -1
                model: bluetoothStable.rows
                add: null; remove: null; displaced: null; move: null; populate: null
                StableDeviceModel { id: bluetoothStable; promoteActive: false }
                property var scanningAdapters: []
                function stopDiscovery() {
                    for (const adapter of scanningAdapters) if (adapter) adapter.stopDiscovery();
                    scanningAdapters = [];
                }
                function startDiscovery() {
                    if (!panel.opened || !panel.bluetoothEnabled) return;
                    for (const adapter of Bluetooth.Manager.adapters) {
                        if (adapter.powered && !adapter.discovering && scanningAdapters.indexOf(adapter) < 0) {
                            scanningAdapters = scanningAdapters.concat([adapter]);
                            adapter.startDiscovery();
                        }
                    }
                }
                Component.onCompleted: startDiscovery()
                Component.onDestruction: stopDiscovery()
                Connections {
                    target: panel
                    function onBluetoothEnabledChanged() { if (panel.bluetoothEnabled) bluetoothList.startDiscovery(); else bluetoothList.stopDiscovery(); }
                }
                function refresh() {
                    bluetoothStable.sync(panel.bluetoothDevices.map(device => ({deviceKey: device.address, payload: {name: device.friendlyName, connected: device.connected, device: device}, rank: 0, active: device.connected})));
                }
                Timer { interval: 100; running: panel.opened && bluetoothList.visible; repeat: true; triggeredOnStart: true; onTriggered: bluetoothList.refresh() }
                delegate: ControlRow {
                    required property var payload
                    width: bluetoothList.width; height: 36; glyph: "bluetooth"; text: payload.name; status: panel.deviceOperations[payload.device.address || payload.device.friendlyName || "device"] || (payload.connected ? "Conectado" : "")
                    id: deviceRow
                    objectName: "bluetoothDeviceRow"
                    actionText: "…"
                    secondaryText: payload.device.paired ? "" : "Sin emparejar"
                    onClicked: panel.connectDevice(payload.device)
                    onActionTriggered: panel.openDeviceMenu(payload.device, deviceRow, width - 28, height)
                    TapHandler { acceptedButtons: Qt.RightButton; onTapped: point => panel.openDeviceMenu(deviceRow.payload.device, deviceRow, point.position.x, point.position.y) }
                    Keys.onMenuPressed: panel.openDeviceMenu(payload.device, deviceRow, width - 28, height)
                }
            }
            UiText { y: parent.height - 36; width: parent.width; height: 36; text: panel.errorText; color: Theme.error; Accessible.role: Accessible.AlertMessage }
        }
    }
}
