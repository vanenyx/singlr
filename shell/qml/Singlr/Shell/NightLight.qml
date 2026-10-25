pragma Singleton
import QtQuick
import org.kde.plasma.workspace.dbus as DBus
import org.kde.plasma.private.brightnesscontrolplugin as Brightness

// Same properties and inhibition owner as Plasma's brightness applet (6.8.1).
// The singleton keeps an inhibition alive when the control center is released.
DBus.Properties {
    busType: DBus.BusType.Session
    service: "org.kde.KWin.NightLight"
    path: "/org/kde/KWin/NightLight"
    iface: "org.kde.KWin.NightLight"
    property var state: properties
    readonly property bool available: Boolean(state.available)
    readonly property bool configured: Boolean(state.enabled)
    readonly property bool running: Boolean(state.running)
    readonly property bool inhibited: Boolean(state.inhibited)
    readonly property bool ownedInhibition: Brightness.NightLightInhibitor.inhibited
    readonly property bool togglable: available && configured && (!inhibited || ownedInhibition)
    readonly property int currentTemperature: Number(state.currentTemperature) || 6500
    readonly property int targetTemperature: Number(state.targetTemperature) || 6500
    readonly property bool indicatorVisible: (running && currentTemperature !== 6500)
                                           || (inhibited && targetTemperature !== 6500)
    readonly property string status: !available ? "No disponible" : !configured ? "Sin configurar"
                                    : inhibited ? "Suspendida" : running && currentTemperature !== 6500 ? "Activa" : "Programada"
    function toggle() { if (togglable) Brightness.NightLightInhibitor.toggleInhibition(); }
}
