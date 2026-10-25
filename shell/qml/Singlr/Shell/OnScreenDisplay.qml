pragma ComponentBehavior: Bound
import QtQuick
import Singlr.Ui

Item {
    id: osd
    implicitWidth: 240; implicitHeight: 44
    property bool showing: false
    property string icon: "speaker-high"
    property real percent: -1
    property string message: ""
    readonly property bool surfaceVisible: showing || opacity > 0
    opacity: showing ? 1 : 0
    function show(symbol, value, text = "") {
        icon = symbol; percent = value; message = text; showing = true; timeout.restart();
    }
    function request(method, args) {
        if (!args || !args.length) return;
        const progress = {brightnessChanged: "sun", screenBrightnessChanged: "sun",
            keyboardBrightnessChanged: "keyboard", volumeChanged: "speaker-high",
            microphoneVolumeChanged: "microphone", mediaPlayerVolumeChanged: "speaker-high"};
        if (progress[method] !== undefined) {
            const value = Number(args[0]);
            if (!isFinite(value)) return;
            let symbol = progress[method];
            if (value <= 0 && method === "volumeChanged") symbol = "speaker-slash";
            if (value <= 0 && method === "microphoneVolumeChanged") symbol = "microphone-slash";
            show(symbol, Math.max(0, Math.min(100, value)));
            return;
        }
        const toggles = {touchpadEnabledChanged: ["sliders-horizontal", "Panel táctil"],
            wifiEnabledChanged: ["wifi-high", "Wi-Fi"], bluetoothEnabledChanged: ["bluetooth", "Bluetooth"],
            wwanEnabledChanged: ["wifi-high", "Red móvil"],
            powerManagementInhibitedChanged: ["moon", "Suspensión inhibida"]};
        if (toggles[method] !== undefined) {
            show(toggles[method][0], -1, toggles[method][1] + (args[0] ? " activado" : " desactivado"));
        } else if (method === "kbdLayoutChanged") show("keyboard", -1, String(args[0]));
        else if (method === "virtualDesktopChanged") show("squares-four", -1, String(args[0]));
        else if (method === "powerProfileChanged") show("battery-high", -1, String(args[0]));
        else if (method === "showText" && args.length > 1) show("sliders-horizontal", -1, String(args[1]));
    }
    Timer { id: timeout; interval: 1500; onTriggered: osd.showing = false }
    Rectangle { anchors.fill: parent; radius: 12; color: "#e6191a1b"; border.color: Theme.focusBorder }
    Icon { x: 16; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20; name: osd.icon }
    Rectangle {
        x: 50; anchors.verticalCenter: parent.verticalCenter; width: 120; height: 4; radius: 2
        visible: osd.percent >= 0; color: Theme.hover
        Rectangle { width: parent.width * Math.max(0, Math.min(100, osd.percent)) / 100; height: 4; radius: 2; color: Theme.control }
    }
    UiText {
        x: osd.percent >= 0 ? 178 : 50; width: osd.percent >= 0 ? 50 : 174; height: parent.height
        text: osd.percent >= 0 ? Math.round(osd.percent) + " %" : osd.message
        font.pixelSize: 13; elide: Text.ElideRight
    }
}
