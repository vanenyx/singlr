pragma ComponentBehavior: Bound
import QtQuick
import org.kde.plasma.private.battery as Battery
import org.kde.plasma.private.volume as Volume
import org.kde.plasma.networkmanagement as Network
import Singlr.Ui
Row {
    id: status
    spacing: 14
    property var sink: Volume.PreferredDevice.sink
    Battery.BatteryControlModel { id: battery }
    Network.NetworkStatus { id: network }
    Tool {
        visible: network.connectivity > 0; width: 24; height: 22; iconSize: 15
        icon: "wifi-high"; description: network.activeConnections
        Accessible.role: Accessible.StaticText
    }
    Tool {
        visible: status.sink !== null; width: 24; height: 22; iconSize: 15
        icon: status.sink && status.sink.muted ? "speaker-slash" : "speaker-high"
        description: status.sink ? (status.sink.muted ? "Silencio" : "Volumen: " + Math.round(status.sink.volume / 65536 * 100) + " %") : ""
        Accessible.role: Accessible.StaticText
    }
    Tool {
        visible: battery.hasInternalBatteries && battery.hasCumulative; height: 22; iconSize: 15
        icon: "battery-high"; label: battery.percent + " %"
        description: "Batería: " + battery.percent + " %" + (battery.pluggedIn ? ", conectada" : "")
        Accessible.role: Accessible.StaticText
    }
}
