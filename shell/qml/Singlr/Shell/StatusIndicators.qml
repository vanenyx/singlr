pragma ComponentBehavior: Bound
import QtQuick
import org.kde.plasma.private.battery as Battery
import org.kde.plasma.private.volume as Volume
import org.kde.plasma.networkmanagement as Network
import Singlr.Ui
Row {
    id: status
    spacing: 14
    signal controlCenterRequested()
    property var sink: Volume.PreferredDevice.sink
    property var nightLightBackend: NightLight
    property alias keyboard: keyboardIndicator
    property Item menuHost: null
    KeyboardIndicator { id: keyboardIndicator; menuHost: status.menuHost }
    Tool {
        width: 24; height: 22; iconSize: 15; visible: status.nightLightBackend.indicatorVisible
        icon: "moon"; description: "Luz nocturna · " + status.nightLightBackend.status
        onClicked: status.controlCenterRequested()
    }
    Battery.BatteryControlModel { id: battery }
    Network.NetworkStatus { id: network }
    Tool {
        visible: network.connectivity > 0; width: 24; height: 22; iconSize: 15
        icon: "wifi-high"; description: network.activeConnections || "Wi-Fi"
        onClicked: status.controlCenterRequested()
    }
    Tool {
        visible: status.sink !== null; width: 24; height: 22; iconSize: 15
        icon: status.sink && status.sink.muted ? "speaker-slash" : "speaker-high"
        description: status.sink ? (status.sink.muted ? "Silencio" : "Volumen: " + Math.round(status.sink.volume / 65536 * 100) + " %") : ""
        onClicked: status.controlCenterRequested()
    }
    Tool {
        visible: battery.hasInternalBatteries && battery.hasCumulative; height: 22; iconSize: 15
        icon: battery.state === Battery.BatteryControlModel.Charging ? "battery-charging" : "battery-high"; label: battery.percent + " %"
        description: "Batería: " + battery.percent + " %" + (battery.pluggedIn ? ", conectada" : "")
        onClicked: status.controlCenterRequested()
    }
}
