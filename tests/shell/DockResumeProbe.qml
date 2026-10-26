import QtQuick
import QtTest
import Singlr.Shell
QtObject {
    id: probe
    property QtObject controller: Session {}
    property QtObject finder: TestCase { when: false }
    property QtObject surface: QtObject {
        function toggleLauncher() {
            const dock = probe.finder.findChild(probe.controller, "sessionDock");
            dock.dockMode = Qt.application.arguments.indexOf("--fixed") >= 0 ? "fixed" : "floating";
            dock.dockHeight = 48;
            dock.autoHide = Qt.application.arguments.indexOf("--autohide") >= 0;
            dock.keyboardHeld = true;
            dock.reveal();
        }
        function showApplications() {
            probe.finder.findChild(probe.controller, "sessionDock").keyboardHeld = false;
        }
        function toggleClipboard() {
            probe.finder.findChild(probe.controller, "sessionDock").reveal();
        }
    }
}
