pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtCore
import QtTest
import Singlr.Ui
import Singlr.Shell
import "../../../session/shell-package/org.singlr.desktop/contents/lockscreen" as Lock

Item {
    id: root
    function i18ndc(domain, context, text) { return text; }
    signal clearPassword()
    signal notificationRepeated()
    property QtObject authenticator: QtObject {
        property int authenticatorTypes: 0
        signal noninteractiveError(int kind, var authenticator)
    }
    width: 1440; height: 1000
    Settings {
        id: options
        location: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/t244.ini"
        property string capturePrefix: ""
    }
    Rectangle { anchors.fill: parent; color: Theme.background }
    TopBar { id: topBar; width: parent.width; now: new Date(2026, 9, 25, 21, 30); activeAppName: "Singlr" }
    ListModel {
        id: results
        property bool querying: false
        ListElement { display: "Configuración del sistema"; subtext: "Aplicación"; decoration: "preferences-system" }
        ListElement { display: "Archivos"; subtext: "Aplicación"; decoration: "system-file-manager" }
    }
    Launcher { id: launcher; x: 20; y: 55; modelOverride: results }
    SystemControls { id: audioBackend; sink: null; source: null }
    QtObject { id: notices; property bool inhibited: false; function setInhibited(value) { inhibited = value; } }
    ControlCenter { id: center; x: 1080; y: 55; audio: audioBackend; notifications: notices; networkSource: null }
    QtObject {
        id: keyboardDouble
        property int layout: 0
        property var layoutsList: [{shortName: "us", longName: "English (US)"}, {shortName: "es", longName: "Español"}]
    }
    QtObject {
        id: nightDouble
        property bool configured: true
        property bool inhibited: false
        property bool togglable: true
        property bool indicatorVisible: true
        property string status: "Activa"
    }
    ListModel { id: clipboardHistory }
    ClipboardPanel { x: 20; y: 620; width: 760; height: 270; history: clipboardHistory }
    NotificationCard {
        x: 800; y: 640; width: 350
        entry: ({id: 1, app: "Singlr", title: "Todo listo", body: "El escritorio sigue la apariencia de KDE.", time: new Date(2026,9,25,21,30), icon: "preferences-system", defaultAction: false, actionNames: [], actionLabels: []})
    }
    OnScreenDisplay { x: 810; y: 820; width: 240; height: 44; showing: true; percent: 65 }
    ListModel { id: tasks; ListElement { AppName: "Archivos"; IsLauncher: true; IsWindow: false; IsActive: false; decoration: "system-file-manager" } }
    Dock { x: 620; y: 930; modelOverride: tasks; settingsLocation: options.location + ".dock" }
    ContextMenu { id: menu; parent: root; entries: [{label: "Abrir", icon: "arrow-up-right", shortcut: "↵"}, {label: "Ajustes…", icon: "gear", shortcut: "⌘ ,"}] }
    Item {
        id: lockPreview; visible: false; width: 1000; height: 700
        Lock.SinglrBackdrop { anchors.fill: parent; softwareRendering: true }
        Lock.SinglrClock { anchors.horizontalCenter: parent.horizontalCenter; y: 80 }
        Lock.MainBlock { anchors.fill: parent; showUserList: false; userListModel: ListModel {} lockScreenUiVisible: true }
    }
    TestCase {
        name: "AppearanceCapture"; when: windowShown
        function capture(item, suffix) {
            let done = false;
            verify(item.grabToImage(result => { verify(result.saveToFile(options.capturePrefix + suffix)); done = true; }));
            tryVerify(() => done);
        }
        function test_capture() {
            if (!options.capturePrefix) skip("Capturas opcionales: tools/test-qml.sh --capture before|after");
            // Before captures also run against HEAD, where these additions do not exist.
            if ("keyboard" in topBar) topBar.keyboard.backend = keyboardDouble;
            if ("nightLightBackend" in topBar) topBar.nightLightBackend = nightDouble;
            if ("outputCount" in center) center.outputCount = 2;
            if ("nightLightBackend" in center) center.nightLightBackend = nightDouble;
            launcher.open(); wait(100);
            menu.showAt(root, 810, 520); wait(50);
            capture(root.Window.window.contentItem, "-surfaces.png");
            menu.close(); lockPreview.visible = true; wait(50);
            capture(lockPreview, "-lock.png");
            lockPreview.visible = false;
            const component = Qt.createComponent("../../../apps/settings/Main.qml");
            compare(component.status, Component.Ready, component.errorString());
            const settings = component.createObject(null) as Window;
            verify(settings); wait(100);
            capture(settings.contentItem, "-settings.png");
            settings.destroy();
        }
    }
}
