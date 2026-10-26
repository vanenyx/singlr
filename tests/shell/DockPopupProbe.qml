import QtQuick
import QtTest
import Singlr.Ui
import Singlr.Shell
QtObject {
    id: probe
    property QtObject controller: Session { }
    property QtObject finder: TestCase { when: false }
    property int scenario: -1
    property QtObject tooltipDelay: Timer {
        interval: 200
        onTriggered: {
            const dock = probe.finder.findChild(probe.controller, "sessionDock");
            dock.tooltipCenter = dock.width / 2;
            dock.tooltipText = "Dolphin";
        }
    }
    property QtObject surface: QtObject {
        function toggleLauncher() {
            probe.scenario++;
            const dock = probe.finder.findChild(probe.controller, "sessionDock");
            dock.hideTooltip(); dock.closeMenu();
            dock.dockMode = probe.scenario % 2 ? "fixed" : "floating";
            dock.dockHeight = [40, 48, 72][Math.floor(probe.scenario / 2) % 3];
            dock.autoHide = probe.scenario >= 6;
            dock.keyboardHeld = true;
            dock.reveal();
            // Resizing deliberately clears hover text; wait for viewport layout.
            probe.tooltipDelay.restart();
        }
        function showApplications() {
            Theme.dark = false;
        }
        function toggleClipboard() {
            const dock = probe.finder.findChild(probe.controller, "sessionDock");
            dock.hideTooltip();
            dock.openContext(0, { AppName: "Dolphin", IsLauncher: true, LauncherUrlWithoutIcon: "applications:org.kde.dolphin.desktop" });
        }
    }
}
