pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic as Controls
import Singlr.Ui

Item {
    id: tray
    readonly property var popup: popupLoader.item
    // Context property is deliberately absent in --windowed.
    // qmllint disable unqualified
    property var backend: typeof SinglrTray !== "undefined" ? SinglrTray : null
    // qmllint enable unqualified
    property Item menuHost: null
    property bool opened: false
    property real menuX: 0
    readonly property int menuHeight: 344
    property string tooltipText: ""
    property real tooltipX: 0
    property var selected: null
    property var pages: []
    property var entries: []
    property int revision: 0
    readonly property int itemCount: icons.count
    width: backend && itemCount ? Math.min(6, itemCount) * 28 - 12 + (itemCount > 6 ? 28 : 0) : 0
    height: 28
    visible: width > 0

    function close() { ++revision; opened = false; selected = null; tooltipText = ""; }
    function present(anchor, x) {
        tooltipText = "";
        menuX = anchor.mapToGlobal(x, 0).x;
        opened = true;
        popup.currentIndex = 0;
    }
    function normalize(nodes) {
        return nodes.filter(e => e.visible !== false).map(e => Object.assign({}, e, {
            separatorOnly: e.type === "separator", keepOpen: !!(e.children && e.children.length),
            shortcut: e.children && e.children.length ? "›" : ""
        }));
    }
    function page(nodes) {
        const back = pages.length ? [{label: "Atrás", icon: "caret-left", back: true, keepOpen: true}] : [];
        entries = back.concat(normalize(nodes));
        if (!entries.length) entries = [{label: "Sin opciones", enabled: false}];
        popup.currentIndex = entries.findIndex(e => e.enabled !== false && !e.separatorOnly);
        if (popup.contentItem) popup.contentItem.contentY = 0;
    }
    function loadMenu() {
        if (!opened || !selected || !backend) return;
        const ticket = ++revision;
        const item = selected;
        Qt.callLater(function() {
            if (!tray.opened || tray.revision !== ticket) return;
            let nodes = [];
            try {
                if (typeof tray.backend.requestMenu === "function") {
                    tray.backend.requestMenu(item.service, item.menuPath);
                    return;
                }
                nodes = tray.backend.menu(item.service, item.menuPath);
            }
            catch (error) { console.warn("SystemTray menu:", error); }
            if (!tray.opened || tray.revision !== ticket) return;
            tray.pages = [];
            tray.page(nodes || []);
        });
    }
    function openMenu(item, anchor, x) {
        ++revision;
        selected = item;
        pages = [];
        entries = [{label: "…", enabled: false}];
        present(anchor, x);
        // Map the surface before requesting data; retain compatibility with the live binary.
        deferredLoad.restart();
    }
    Timer { id: deferredLoad; interval: 50; onTriggered: tray.loadMenu() }
    function overflow(anchor) {
        ++revision; selected = null; pages = [];
        let rest = [];
        for (let i = 6; i < icons.count; ++i) {
            const icon = icons.itemAt(i);
            if (icon) rest.push({label: icon.model.toolTipTitle || icon.model.title || icon.model.id,
                iconName: icon.model.iconName, imageSource: icon.model.iconSource,
                trayItem: icon.model, keepOpen: true, shortcut: "›"});
        }
        entries = rest.length ? rest : [{label: "Sin opciones", enabled: false}];
        present(anchor, 0);
    }
    function run(entry) {
        if (entry.trayItem) {
            if (entry.trayItem.itemIsMenu) openMenu(entry.trayItem, tray, 0);
            else {
                backend.activate(entry.trayItem.service, entry.trayItem.path, popup.actionPosition.x, popup.actionPosition.y);
                close();
            }
            return;
        }
        if (entry.back) { const previous = pages[pages.length - 1]; pages = pages.slice(0, -1); page(previous); return; }
        if (entry.children && entry.children.length) {
            pages = pages.concat([entries.filter(e => !e.back)]);
            page(entry.children); return;
        }
        if (selected && backend) backend.activateMenuItem(selected.service, selected.menuPath, entry.id);
    }
    function click(item, button, anchor, x, y) {
        const point = anchor.mapToGlobal(x, y);
        if (button === Qt.RightButton || (button === Qt.LeftButton && item.itemIsMenu)) openMenu(item, anchor, x);
        else {
            close();
            if (button === Qt.MiddleButton) backend.secondaryActivate(item.service, item.path, point.x, point.y);
            else backend.activate(item.service, item.path, point.x, point.y);
        }
    }
    Connections {
        target: tray.backend
        ignoreUnknownSignals: true // Previous live binary has no async menu signals.
        function onMenuReady(service, menuPath, items) {
            if (!tray.opened || !tray.selected || tray.selected.service !== service || tray.selected.menuPath !== menuPath) return;
            tray.pages = [];
            tray.page(items || []);
        }
        function onMenuFailed(service, menuPath, error) {
            if (!tray.opened || !tray.selected || tray.selected.service !== service || tray.selected.menuPath !== menuPath) return;
            tray.pages = [];
            tray.entries = [{label: "No se pudo cargar el menú", enabled: false}];
        }
        function onMenuChanged(service) {
            if (tray.opened && tray.selected && tray.selected.service === service) deferredLoad.restart();
        }
    }
    Connections {
        target: tray.backend ? tray.backend.items : null
        // Removed rows can invalidate both a selected menu and overflow entries.
        function onRowsRemoved() { tray.close(); }
        function onModelReset() { tray.close(); }
    }
    Row {
        spacing: 12; height: 28
        Repeater {
            id: icons
            model: tray.backend ? tray.backend.items : null
            delegate: Rectangle {
                id: app
                required property var model
                required property int index
                objectName: "trayIcon" + index
                visible: index < 6
                width: 16; height: 28; radius: 3
                color: pointer.containsMouse ? Theme.hover : "transparent"
                border.color: activeFocus ? Theme.accentText : "transparent"
                activeFocusOnTab: visible
                Accessible.role: Accessible.Button
                Accessible.name: model.toolTipTitle || model.title
                Accessible.onPressAction: tray.click(model, Qt.LeftButton, app, 8, 14)
                Keys.onEnterPressed: tray.click(model, Qt.LeftButton, app, 8, 14)
                Keys.onReturnPressed: tray.click(model, Qt.LeftButton, app, 8, 14)
                Keys.onSpacePressed: tray.click(model, Qt.LeftButton, app, 8, 14)
                Keys.onMenuPressed: tray.openMenu(model, app, 8)
                Image {
                    sourceSize: Qt.size(Math.max(1, Math.ceil(width * Screen.devicePixelRatio)), Math.max(1, Math.ceil(height * Screen.devicePixelRatio)))
                    id: pixmap
                    x: 0; y: 6; width: 16; height: 16
                    source: app.model.iconSource || ""; fillMode: Image.PreserveAspectFit
                    visible: !!String(source) && status !== Image.Error
                }
                AppIcon { x: 0; y: 6; width: 16; height: 16; name: app.model.iconName || ""; visible: !String(pixmap.source) || pixmap.status === Image.Error }
                // Older live backends omit hasAttentionIcon and keep the fallback dot.
                Rectangle { x: 6; y: 23; width: 4; height: 4; radius: 2; color: Theme.accent; visible: app.model.status === "NeedsAttention" && app.model.hasAttentionIcon !== true }
                MouseArea {
                    id: pointer; anchors.fill: parent; hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onEntered: { tray.tooltipX = app.mapToGlobal(8, 0).x; tray.tooltipText = app.model.toolTipTitle || app.model.title; }
                    onExited: tray.tooltipText = ""
                    onClicked: mouse => tray.click(app.model, mouse.button, app, mouse.x, mouse.y)
                    onWheel: wheel => {
                        if (wheel.angleDelta.y) tray.backend.scroll(app.model.service, app.model.path, wheel.angleDelta.y, "vertical");
                        if (wheel.angleDelta.x) tray.backend.scroll(app.model.service, app.model.path, wheel.angleDelta.x, "horizontal");
                    }
                }
            }
        }
        Tool { visible: icons.count > 6; width: 16; height: 28; icon: "caret-right"; description: "Más aplicaciones"; onClicked: tray.overflow(this) }
    }
    DeferredLoader {
        id: popupLoader; objectName: "SystemTrayMenuLoader"; opened: tray.opened
        sourceComponent: Component {
            ContextMenu {
                id: popup
                objectName: "trayMenu"
                parent: tray.menuHost || tray
                visible: tray.opened
                x: tray.menuHost ? 0 : Math.max(-tray.x, Math.min(0, tray.parent.width - tray.x - width))
                y: tray.menuHost ? 0 : 32
                margins: 0; fixedHeight: tray.menuHeight
                entries: tray.entries
                onTriggered: entry => tray.run(entry)
                onAuxiliaryTriggered: (entry, button) => {
                    if (button === Qt.RightButton) tray.openMenu(entry.trayItem, tray, 0);
                    else {
                        tray.backend.secondaryActivate(entry.trayItem.service, entry.trayItem.path, popup.actionPosition.x, popup.actionPosition.y);
                        tray.close();
                    }
                }
                onScrolled: (entry, delta, orientation) => tray.backend.scroll(entry.trayItem.service, entry.trayItem.path, delta, orientation)
                onClosed: tray.close()
            }
        }
    }
    DeferredLoader {
        opened: !tray.menuHost && !!tray.tooltipText && !tray.opened
        sourceComponent: Component {
            Controls.ToolTip {
                visible: !tray.menuHost && !!tray.tooltipText && !tray.opened
                text: tray.tooltipText; y: 32
            }
        }
    }
}
