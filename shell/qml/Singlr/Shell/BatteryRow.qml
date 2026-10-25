pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
import Singlr.Ui

Item {
    id: row
    required property var battery
    required property var power
    property bool charging: false
    implicitHeight: 36
    Icon { x: 8; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; font.pixelSize: 16; name: row.charging ? "battery-charging" : "battery-high"; Accessible.name: row.charging ? "Cargando" : "Batería" }
    UiText { objectName: "batteryPercent"; x: 34; height: 36; text: row.battery.percent + " %"; font.pixelSize: 13; weight: 590 }
    UiText {
        x: 90; width: Math.max(0, profiles.x - x - 8); height: 36; color: Theme.muted; font.pixelSize: 11; elide: Text.ElideRight
        text: { const minutes = Math.floor(row.battery.smoothedRemainingMsec / 60000); return minutes > 0 ? Math.floor(minutes / 60) + " h " + String(minutes % 60).padStart(2, "0") : ""; }
    }
    Row {
        id: profiles; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        Repeater {
            model: [{key: "power-saver", title: "Ahorro", tint: Theme.powerSaver}, {key: "balanced", title: "Equilibrado", tint: Theme.control}, {key: "performance", title: "Rendimiento", tint: Theme.powerPerformance}]
            delegate: Controls.AbstractButton {
                id: profile
                required property var modelData
                objectName: "profile-" + modelData.key
                width: 28; height: 36
                enabled: row.power.profiles.indexOf(modelData.key) >= 0
                Accessible.name: modelData.title
                Accessible.checkable: true; Accessible.checked: row.power.activeProfile === modelData.key
                Controls.ToolTip.visible: hovered
                Controls.ToolTip.text: modelData.title + (row.power.profileError ? " · " + row.power.profileError : "")
                background: Rectangle { radius: 5; color: profile.visualFocus ? Theme.hover : "transparent" }
                contentItem: Item {
                    Rectangle {
                        objectName: "profileCircle"; anchors.centerIn: parent; width: 12; height: 12; radius: 6
                        border.width: 1.5; border.color: profile.modelData.tint
                        color: row.power.activeProfile === profile.modelData.key ? profile.modelData.tint : "transparent"
                        opacity: profile.enabled ? 1 : 0.4
                    }
                }
                onClicked: row.power.setProfile(modelData.key)
            }
        }
    }
}
