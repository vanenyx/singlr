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
        property string historyOrder: ""
    }
    property QtObject orderSnapshot: Timer {
        interval: 100
        onTriggered: {
            const history = probe.controller.clipboardPanel.history;
            const ids = [];
            // KDE 6.8.1 UuidRole; test-only metadata, never clipboard payload.
            for (let row = 0; row < history.rowCount(); ++row) ids.push(history.data(history.index(row, 0), Qt.UserRole + 1));
            probe.state.historyOrder = JSON.stringify(ids);
            probe.state.sync();
        }
    }
    property QtObject events: Connections {
        target: ClipboardPasteBridge
        function onShortcutSent() { probe.state.sent = true; probe.state.sync(); }
        function onFailed() { probe.state.failed = true; probe.state.sync(); }
    }
    // Test adapter behind the stock native launcher bridge; never installed.
    property QtObject surface: QtObject {
        function toggleClipboard() { probe.controller.toggleClipboard(); probe.state.sync(); probe.orderSnapshot.restart(); }
        function toggleLauncher() {
            probe.controller.clipboardPanel.selectedIndex = 1;
            probe.controller.clipboardPanel.run();
            probe.orderSnapshot.restart();
        }
        function showApplications() { probe.controller.clipboardPanel.selectedIndex = 1; probe.controller.clipboardPanel.run(true); probe.orderSnapshot.restart(); }
        function focusDock() { probe.controller.clipboardPanel.selectedIndex = 0; probe.controller.clipboardPanel.run(); probe.orderSnapshot.restart(); }
    }
}
