// Sin «pragma ComponentBehavior: Bound»: KWin instancia el delegado de la escena desde otro
// contexto y esa directiva provoca «Cannot instantiate bound component outside its creation context».

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWin

KWin.SceneEffect {
    id: effect

    property bool activated: false
    property real reveal: 0
    Behavior on reveal { NumberAnimation { duration: 120 } }

    function toggle() {
        if (activated) {
            deactivate();
        } else {
            hideTimer.stop();
            visible = true;
            activated = true;
            Qt.callLater(() => { if (effect.activated) effect.reveal = 1; });
        }
    }
    function deactivate() {
        activated = false;
        reveal = 0;
        hideTimer.restart();
    }

    KWin.ShortcutHandler {
        name: "Singlr Overview"
        text: "Singlr Overview"
        sequence: "Meta+Tab"
        onActivated: effect.toggle()
    }
    Timer {
        id: hideTimer
        interval: 120
        onTriggered: effect.visible = false
    }

    delegate: Item {
        id: view
        focus: true
        opacity: effect.reveal
        readonly property KWin.Output targetScreen: KWin.SceneView.screen
        property KWin.VirtualDesktop currentDesktop: KWin.Workspace.currentDesktopForScreen(targetScreen)
        property int selectedIndex: 0
        property KWin.VirtualDesktop menuDesktop: null
        property KWin.Window draggedWindow: null
        readonly property int gap: 24
        readonly property int columns: Math.max(1, Math.min(windows.count,
            Math.ceil(Math.sqrt(windows.count * gridArea.width / Math.max(1, gridArea.height) * 0.65))))
        readonly property int rows: Math.ceil(windows.count / columns)
        readonly property real cellWidth: Math.max(1, Math.min(480, (gridArea.width - (columns - 1) * gap) / columns))
        readonly property real cellHeight: Math.max(1, Math.min(320, (gridArea.height - (rows - 1) * gap) / Math.max(1, rows)))

        function switchDesktop(desktop) {
            menuDesktop = null;
            KWin.Workspace.setCurrentDesktopForScreen(desktop, targetScreen);
            selectedIndex = 0;
            forceActiveFocus();
        }
        function removeDesktop(desktop) {
            menuDesktop = null;
            if (desktop && KWin.Workspace.desktops.length > 1)
                KWin.Workspace.removeDesktop(desktop);
            forceActiveFocus();
        }
        function activateSelected() {
            const card = windows.itemAt(selectedIndex);
            if (card) card.activate();
        }
        function navigate(delta) {
            menuDesktop = null;
            selectedIndex = Math.max(0, Math.min(windows.count - 1, selectedIndex + delta));
        }

        Connections {
            target: KWin.Workspace
            function onCurrentDesktopChanged(previous, current, screen) {
                if (screen === view.targetScreen) {
                    view.currentDesktop = current;
                    view.selectedIndex = 0;
                }
            }
        }

        KWin.WindowModel { id: allWindows }

        // Real desktop surface behind the tint; no blur or captured bitmaps.
        Repeater {
            model: KWin.WindowFilterModel {
                windowModel: allWindows
                desktop: view.currentDesktop
                screenName: view.targetScreen.name
                activity: KWin.Workspace.currentActivity
                windowType: KWin.WindowFilterModel.Desktop
            }
            KWin.WindowThumbnail {
                required property KWin.Window window
                anchors.fill: parent
                client: window
            }
        }
        Rectangle { anchors.fill: parent; color: "#08090a"; opacity: 0.85 }
        MouseArea {
            anchors.fill: parent
            onClicked: { view.menuDesktop = null; view.forceActiveFocus(); }
        }

        Flickable {
            id: desktopStrip
            x: 32
            y: 32
            width: parent.width - 64
            height: 130
            contentWidth: desktopRow.width
            contentHeight: height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: desktopRow
                spacing: 16
                x: Math.max(0, (desktopStrip.width - width) / 2)
                Repeater {
                    model: KWin.Workspace.desktops
                    Item {
                        id: desktopCard
                        required property KWin.VirtualDesktop modelData
                        width: 160
                        height: 126
                        Rectangle {
                            id: desktopPreview
                            width: 160
                            height: 100
                            color: "#141516"
                            radius: 4
                            clip: true
                            Item {
                                width: view.targetScreen.geometry.width
                                height: view.targetScreen.geometry.height
                                scale: Math.min(160 / width, 100 / height)
                                transformOrigin: Item.TopLeft
                                x: (160 - width * scale) / 2
                                y: (100 - height * scale) / 2
                                Repeater {
                                    model: KWin.WindowFilterModel {
                                        windowModel: allWindows
                                        desktop: desktopCard.modelData
                                        screenName: view.targetScreen.name
                                        activity: KWin.Workspace.currentActivity
                                        windowType: KWin.WindowFilterModel.Desktop | KWin.WindowFilterModel.Normal | KWin.WindowFilterModel.Dialog
                                        minimizedWindows: false
                                    }
                                    KWin.WindowThumbnail {
                                        required property KWin.Window window
                                        client: window
                                        x: window.x - view.targetScreen.geometry.x
                                        y: window.y - view.targetScreen.geometry.y
                                        width: window.width
                                        height: window.height
                                        z: window.stackingOrder
                                    }
                                }
                            }
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                radius: 4
                                border.width: desktopCard.modelData === view.currentDesktop ? 1.5 : (drop.containsDrag ? 1 : 0)
                                border.color: "#f7f8f8"
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    view.forceActiveFocus();
                                    if (mouse.button === Qt.RightButton) {
                                        view.menuDesktop = desktopCard.modelData;
                                        const p = mapToItem(view, mouse.x, mouse.y);
                                        desktopMenu.x = Math.min(p.x, view.width - desktopMenu.width - 8);
                                        desktopMenu.y = p.y;
                                    } else view.switchDesktop(desktopCard.modelData);
                                }
                            }
                            DropArea {
                                id: drop
                                anchors.fill: parent
                                keys: ["singlr-window"]
                                onDropped: event => {
                                    if (view.draggedWindow) {
                                        const movedWindow = view.draggedWindow;
                                        const destination = desktopCard.modelData;
                                        Qt.callLater(() => { if (movedWindow) movedWindow.desktops = [destination]; });
                                        event.acceptProposedAction();
                                    }
                                }
                            }
                        }
                        Text {
                            y: 108
                            width: parent.width
                            text: desktopCard.modelData.name
                            color: "#d0d6e0"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
                Rectangle {
                    width: 48
                    height: 100
                    radius: 4
                    color: addHover.hovered ? "#191a1b" : "#0f1011"
                    Text { anchors.centerIn: parent; text: "+"; color: "#d0d6e0"; font.pixelSize: 24 }
                    HoverHandler { id: addHover }
                    TapHandler { onTapped: KWin.Workspace.createDesktop(KWin.Workspace.desktops.length, "") }
                    Accessible.role: Accessible.Button
                    Accessible.name: "Añadir escritorio"
                }
            }
        }

        Item {
            id: gridArea
            x: 48
            y: 202
            width: parent.width - 96
            height: Math.max(1, parent.height - y - 48)
            Grid {
                anchors.centerIn: parent
                columns: view.columns
                spacing: view.gap
                Repeater {
                    id: windows
                    model: KWin.WindowFilterModel {
                        windowModel: allWindows
                        desktop: view.currentDesktop
                        screenName: view.targetScreen.name
                        activity: KWin.Workspace.currentActivity
                        windowType: KWin.WindowFilterModel.Normal | KWin.WindowFilterModel.Dialog
                        minimizedWindows: true
                    }
                    onCountChanged: view.selectedIndex = Math.max(0, Math.min(view.selectedIndex, count - 1))
                    Item {
                        id: card
                        required property KWin.Window window
                        required property int index
                        width: view.cellWidth
                        height: view.cellHeight
                        function activate() {
                            KWin.Workspace.activeWindow = window;
                            effect.deactivate();
                        }
                        Item {
                            id: picture
                            width: Math.min(card.width, Math.max(1, card.height - 28) * card.window.width / Math.max(1, card.window.height))
                            height: Math.min(Math.max(1, card.height - 28), card.width * card.window.height / Math.max(1, card.window.width))
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: (card.height - 28 - height) / 2
                            KWin.WindowThumbnail { anchors.fill: parent; client: card.window }
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                radius: 4
                                border.width: 1
                                // QML uses #AARRGGBB, not CSS #RRGGBBAA.
                                border.color: view.selectedIndex === card.index ? "#f7f8f8" : (cardHover.hovered ? "#26ffffff" : "transparent")
                            }
                            MouseArea {
                                id: windowMouse
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                drag.target: dragToken
                                onPressed: mouse => {
                                    view.menuDesktop = null;
                                    view.selectedIndex = card.index;
                                    view.forceActiveFocus();
                                    if (mouse.button === Qt.LeftButton) {
                                        view.draggedWindow = card.window;
                                        dragToken.x = mouse.x;
                                        dragToken.y = mouse.y;
                                    }
                                }
                                onReleased: {
                                    if (drag.active) dragToken.Drag.drop();
                                    view.draggedWindow = null;
                                    dragToken.x = 0;
                                    dragToken.y = 0;
                                }
                                onCanceled: { view.draggedWindow = null; dragToken.x = 0; dragToken.y = 0; }
                                onClicked: mouse => {
                                    if (mouse.button === Qt.MiddleButton) {
                                        if (card.window.closeable) card.window.closeWindow();
                                    } else card.activate();
                                }
                            }
                            Item {
                                id: dragToken
                                width: 1
                                height: 1
                                Drag.active: windowMouse.drag.active
                                Drag.keys: ["singlr-window"]
                                Drag.source: card
                                Drag.hotSpot.x: 0
                                Drag.hotSpot.y: 0
                            }
                            Rectangle {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 6
                                width: 24
                                height: 24
                                radius: 4
                                color: "#191a1b"
                                visible: cardHover.hovered && card.window.closeable
                                Text { anchors.centerIn: parent; text: "×"; color: "#f7f8f8"; font.pixelSize: 18 }
                                TapHandler { onTapped: card.window.closeWindow() }
                                Accessible.role: Accessible.Button
                                Accessible.name: "Cerrar " + card.window.caption
                            }
                        }
                        HoverHandler { id: cardHover }
                        Row {
                            x: picture.x
                            y: card.height - 20
                            spacing: 6
                            Kirigami.Icon { width: 16; height: 16; source: card.window.icon }
                            Text {
                                width: Math.max(0, picture.width - 22)
                                text: card.window.caption
                                color: "#d0d6e0"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }
                        Accessible.role: Accessible.Button
                        Accessible.name: card.window.caption
                        Accessible.onPressAction: activate()
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: windows.count === 0
                text: "No hay ventanas en este escritorio"
                color: "#8a8f98"
                font.pixelSize: 12
            }
        }
        // Internal drag feedback stays in the effect's scene (no native drag window).
        Rectangle {
            visible: view.draggedWindow !== null
            x: view.mapFromGlobal(KWin.Workspace.cursorPos).x + 12
            y: view.mapFromGlobal(KWin.Workspace.cursorPos).y + 12
            width: 160
            height: 26
            radius: 4
            color: "#191a1b"
            z: 20
            Text {
                anchors.fill: parent
                anchors.margins: 5
                text: view.draggedWindow ? view.draggedWindow.caption : ""
                color: "#f7f8f8"
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
        Rectangle {
            id: desktopMenu
            visible: view.menuDesktop !== null
            z: 30
            width: 176
            height: 36
            radius: 4
            color: "#191a1b"
            Text {
                anchors.centerIn: parent
                text: "Eliminar escritorio"
                font.pixelSize: 12
                color: KWin.Workspace.desktops.length > 1 ? "#f7f8f8" : "#62666d"
            }
            TapHandler { onTapped: view.removeDesktop(view.menuDesktop) }
            Accessible.role: Accessible.MenuItem
            Accessible.name: "Eliminar escritorio"
        }

        Keys.onPressed: event => {
            event.accepted = true;
            if (event.key === Qt.Key_Escape) {
                if (view.menuDesktop) view.menuDesktop = null;
                else effect.deactivate();
            } else if (event.key === Qt.Key_Delete) view.removeDesktop(view.menuDesktop || view.currentDesktop);
            else if (event.key === Qt.Key_Left) view.navigate(-1);
            else if (event.key === Qt.Key_Right) view.navigate(1);
            else if (event.key === Qt.Key_Up) view.navigate(-view.columns);
            else if (event.key === Qt.Key_Down) view.navigate(view.columns);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (view.menuDesktop) view.removeDesktop(view.menuDesktop);
                else view.activateSelected();
            } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                const desktop = KWin.Workspace.desktops[event.key - Qt.Key_1];
                if (desktop) view.switchDesktop(desktop);
            } else event.accepted = false;
        }
    }
}
