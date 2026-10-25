import QtQuick
import org.kde.kwin as KWin

Item {
    id: gestures
    // Latch at gesture start: the effect may finish closing before onActivated.
    property bool trackingDesktopSwipe: false
    property bool overviewAtStart: false
    function trackDesktopSwipe() {
        if (trackingDesktopSwipe) return;
        trackingDesktopSwipe = true;
        overviewAtStart = KWin.Workspace.isEffectActive("singlr-overview");
    }
    KWin.SwipeGestureHandler {
        direction: KWin.SwipeGestureHandler.Direction.Down
        deviceType: KWin.SwipeGestureHandler.Device.Touchpad
        fingerCount: 3
        onProgressChanged: if (progress > 0) gestures.trackDesktopSwipe()
        onActivated: {
            gestures.trackDesktopSwipe();
            // Workspace.showingDesktop is not exported in KWin 6.8.1.
            if (!gestures.overviewAtStart) KWin.Workspace.slotToggleShowDesktop();
            gestures.trackingDesktopSwipe = false;
        }
        onCancelled: gestures.trackingDesktopSwipe = false
    }
    KWin.PinchGestureHandler {
        direction: KWin.PinchGestureHandler.Direction.Contracting
        fingerCount: 4
        onActivated: applications.call()
    }
    KWin.DBusCall {
        id: applications
        service: "org.kde.plasmashell"
        path: "/PlasmaShell"
        dbusInterface: "org.kde.PlasmaShell"
        method: "singlrShowApplications"
        onFailed: console.warn("Singlr: no se pudo mostrar todas las aplicaciones por D-Bus")
    }
}
