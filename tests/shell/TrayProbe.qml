// Read-only live protocol probe by default. Optional actions need explicit CLI args.
import QtQuick
import QtQml.Models

QtObject {
    id: root
    function argument(name, fallback) {
        const prefix = "--" + name + "=";
        for (const arg of Qt.application.arguments)
            if (arg.startsWith(prefix)) return arg.slice(prefix.length);
        return fallback;
    }
    // qmllint disable unqualified
    readonly property var backend: typeof SinglrTray === "undefined" ? null : SinglrTray
    // qmllint enable unqualified
    readonly property bool available: backend !== null
    property var seen: ({})
    property bool actionSent: false
    property int samples: 0
    property Instantiator rows: Instantiator {
        model: root.available ? root.backend.items : null
        delegate: TrayRow {}
    }
    component TrayRow: QtObject {
        required property string service
        required property string path
        required property string title
        required property string category
        required property string status
        required property string iconName
        required property url iconSource
        required property string toolTipTitle
        required property bool itemIsMenu
        required property string menuPath
        property Image pixmap: Image {
            source: iconSource
            onStatusChanged: {
                if (status === Image.Ready) console.log("TRAY_IMAGE_READY", source, sourceSize);
                if (status === Image.Error) console.error("TRAY_IMAGE_ERROR", source);
            }
        }
        function snapshot() {
            return {service, path, title, category, status, iconName, iconSource: String(iconSource), toolTipTitle, itemIsMenu, menuPath};
        }
    }
    property Connections changes: Connections {
        target: root.backend
        function onMenuChanged(service) { console.log("TRAY_MENU_CHANGED", service); }
    }
    property Timer sampling: Timer {
        interval: 1000
        running: root.available
        repeat: true
        onTriggered: {
            root.samples++;
            for (let i = 0; i < root.rows.count; i++) {
                const row = root.rows.objectAt(i) as TrayRow;
                if (!row) continue;
                const data = row.snapshot();
                const key = row.service + row.path;
                const snapshot = JSON.stringify(data);
                if (root.seen[key] !== snapshot) {
                    console.log("TRAY_ITEM", snapshot);
                    if (row.menuPath && row.menuPath !== "/")
                        console.log("TRAY_MENU", row.service, JSON.stringify(root.backend.menu(row.service, row.menuPath)));
                    root.seen[key] = snapshot;
                }
                if (!root.actionSent && row.service === root.argument("tray-service", "")) {
                    const action = root.argument("tray-action", "");
                    if (action === "activate") root.backend.activate(row.service, row.path, 0, 0);
                    else if (action === "secondary") root.backend.secondaryActivate(row.service, row.path, 0, 0);
                    else if (action === "scroll") root.backend.scroll(row.service, row.path, 120, "vertical");
                    else if (action === "menu") root.backend.activateMenuItem(row.service, row.menuPath, Number(root.argument("tray-menu-id", "0")));
                    root.actionSent = true;
                    if (action) console.log("TRAY_ACTION_SENT", action, row.service);
                }
            }
            if (root.samples >= Number(root.argument("tray-seconds", "20"))) {
                console.log("TRAY_PROBE_DONE", root.rows.count);
                Qt.exit(root.rows.count > 0 ? 0 : 1);
            }
        }
    }
    Component.onCompleted: {
        if (Qt.application.arguments.includes("--windowed")) {
            console.log("TRAY_WINDOWED_UNDEFINED", !available);
            console.log("SYSTEM_WINDOWED_UNDEFINED", typeof SinglrSystem === "undefined");
            Qt.callLater(() => Qt.exit(available ? 1 : 0));
        } else if (!available) {
            console.error("TRAY_PROBE_ERROR: launcher must own org.kde.plasmashell");
            Qt.callLater(() => Qt.exit(2));
        }
    }
}
