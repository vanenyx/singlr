import QtQuick
import QtCore
import QtTest
import Singlr.Shell
import Singlr.Ui
Item {
    id: root
    width: 1280; height: 800
    Settings {
        id: options
        location: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/t250.ini"
        property string capturePrefix: ""
    }
    Rectangle { anchors.fill: parent; color: Theme.background }
    ListModel {
        id: commandRows
        property bool querying: false
        function index(row, column) { return row; }
        function run(row) { return true; }
        ListElement { display: "Fondo de escritorio"; subtext: "Singlr"; category: "Configuración"; decoration: "" }
    }
    Launcher { id: launcher; x: 260; y: 129; visible: false; modelOverride: commandRows }
    SessionSplash { id: splash; anchors.fill: parent; stage: 4 }
    TestCase {
        name: "SessionSplash"; when: windowShown
        function test_commandCapture() {
            if (!options.capturePrefix) { skip("Solo captura explícita"); return; }
            splash.visible = false;
            launcher.open(); launcher.query = "fondo";
            tryCompare(launcher, "resultCount", 1);
            launcher.openActions(); wait(100);
            let done = false;
            verify(root.grabToImage(result => { verify(result.saveToFile(options.capturePrefix + "-command.png")); done = true; }));
            tryVerify(() => done);
            launcher.close(); splash.visible = true;
        }
        function test_stagesAndMotion() {
            for (let stage = 0; stage <= 6; ++stage) {
                splash.stage = stage;
                compare(splash.width, 1280); compare(splash.height, 800);
            }
            compare(splash.dark, Theme.dark);
            verify(Motion.enabled ? Motion.duration > 0 : Motion.duration === 0);
        }
        function test_capture() {
            if (!options.capturePrefix) { skip("Solo captura explícita"); return; }
            splash.stage = 4; wait(Motion.duration + 50);
            let done = false;
            verify(splash.grabToImage(result => { verify(result.saveToFile(options.capturePrefix + "-splash.png")); done = true; }));
            tryVerify(() => done);
        }
    }
}
