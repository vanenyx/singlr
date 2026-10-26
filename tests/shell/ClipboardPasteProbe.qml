import QtQuick
import QtCore
import Singlr.Shell
import Singlr.System
QtObject {
    id: probe
    property QtObject controller: Session { }
    property QtObject state: Settings {
        location: StandardPaths.writableLocation(StandardPaths.GenericStateLocation) + "/clipboard-probe.ini"
        property bool sent: false
        property bool failed: false
        property bool canPaste: ClipboardPasteBridge.canPaste
        property int count: probe.controller.clipboardPanel ? probe.controller.clipboardPanel.resultCount : -1
    }
    property QtObject events: Connections {
        target: ClipboardPasteBridge
        function onShortcutSent() { probe.state.sent = true; probe.state.sync(); }
        function onFailed() { probe.state.failed = true; probe.state.sync(); }
    }
    // Test adapter behind the stock native launcher bridge; never installed.
    property QtObject surface: QtObject {
        function toggleClipboard() { probe.controller.toggleClipboard(); probe.state.sync(); }
        function toggleLauncher() {
            probe.controller.clipboardPanel.selectedIndex = 1;
            probe.controller.clipboardPanel.run();
        }
        function showApplications() { probe.controller.clipboardPanel.selectedIndex = 1; probe.controller.clipboardPanel.run(true); }
        function focusDock() { probe.controller.clipboardPanel.selectedIndex = 0; probe.controller.clipboardPanel.run(); }
    }
}
