pragma ComponentBehavior: Bound
import QtQuick
import Singlr.Ui
import Singlr.Shell
QtObject {
    id: shell
    readonly property bool windowed: Qt.application.arguments.indexOf("--windowed") >= 0
    function argument(name, fallback) {
        const prefix = "--" + name + "=";
        for (const arg of Qt.application.arguments) if (arg.indexOf(prefix) === 0) return arg.slice(prefix.length);
        return fallback;
    }
    property QtObject surface: windowed ? desktop.createObject(null) : session.createObject(null)
    property Component desktop: Component {
        Desktop {
            capturePath: shell.argument("capture", Qt.application.arguments.indexOf("--capture") >= 0 ? decodeURIComponent(Qt.resolvedUrl("captures/desktop-dark.png").toString().replace(/^file:\/\//, "")) : "")
            captureLauncherPath: Qt.application.arguments.indexOf("--capture") >= 0 ? decodeURIComponent(Qt.resolvedUrl("captures/launcher-dark.png").toString().replace(/^file:\/\//, "")) : ""
            captureSearch: Qt.application.arguments.indexOf("--search") >= 0
            captureQuery: shell.argument("query", "konsole")
        }
    }
    property Component session: Component { Session {} }
    Component.onCompleted: {
        Theme.dark = argument("mode", "dark") !== "light";
        if (!windowed && (argument("capture", "") || Qt.application.arguments.indexOf("--capture") >= 0)) { console.error("--capture requiere --windowed"); Qt.exit(2); }
    }
}
