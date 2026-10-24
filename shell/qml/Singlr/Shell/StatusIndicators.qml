pragma ComponentBehavior: Bound
import QtQuick
import org.kde.plasma.private.battery as Battery
import org.kde.plasma.private.volume as Volume
import org.kde.plasma.networkmanagement as Network
import Singlr.Ui

Row {
    id: status
    spacing: 16
    property var sink: Volume.PreferredDevice.sink
    Battery.BatteryControlModel { id: battery }
    Network.NetworkStatus { id: network }
    Network.ConnectionIcon { id: connection }
    Row {
        visible: network.connectivity > 0
        spacing: 6
        Accessible.role: Accessible.StaticText
        Accessible.name: network.activeConnections
        AppIcon { width: 16; height: 16; source: connection.connectionIcon }
    }
    Row {
        visible: status.sink !== null
        spacing: 6
        Accessible.role: Accessible.StaticText
        Accessible.name: "Volumen: " + volumeLabel.text
        Icon { name: status.sink && status.sink.muted ? "speaker-slash" : "speaker-high"; width: 16; height: 16 }
        // PulseAudio PA_VOLUME_NORM = 65536; also used by PipeWire's Pulse server.
        UiText { id: volumeLabel; text: status.sink ? (status.sink.muted ? "Silencio" : Math.round(status.sink.volume / 65536 * 100) + " %") : ""; font.pixelSize: 12; color: Theme.muted }
    }
    Row {
        visible: battery.hasInternalBatteries && battery.hasCumulative
        spacing: 6
        Accessible.role: Accessible.StaticText
        Accessible.name: "Batería: " + battery.percent + " %" + (battery.pluggedIn ? ", conectada" : "")
        Icon { name: "battery-high"; width: 16; height: 16 }
        UiText { text: battery.percent + " %" + (battery.pluggedIn ? " · CA" : ""); font.pixelSize: 12; color: Theme.muted }
    }
}
