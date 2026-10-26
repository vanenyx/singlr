pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic as Controls
import QtQuick.Dialogs
import QtCore
import "../../shell/qml/Singlr/Ui" as Ui

Window {
    id: window
    width: 880; height: 600; minimumWidth: 880; minimumHeight: 600
    visible: true; title: "Ajustes de Singlr"; color: Ui.Theme.background
    property string page: Qt.application.arguments.indexOf("--wallpaper") >= 0 ? "wallpaper" : "appearance"
    readonly property string feedback: Ui.Appearance.error
    readonly property var accents: [
        {label: "Índigo", color: "#5e6ad2"}, {label: "Azul", color: "#4ea7fc"},
        {label: "Verde", color: "#4cb782"}, {label: "Ámbar", color: "#f2c94c"},
        {label: "Naranja", color: "#f2994a"}, {label: "Rosa", color: "#eb5ea9"}, {label: "Gris", color: "#8a8f98"}]
    readonly property var presets: [
        {label: "Linear", key: "singlr:linear"}, {label: "Brillo tenue", key: "singlr:glow"},
        {label: "Neutro claro", key: "singlr:light"}, {label: "Grafito", key: "singlr:graphite"}]
    function save(key, value) {
        Ui.Appearance.save(key, value);
    }
    FileDialog {
        id: fileDialog; objectName: "wallpaperFileDialog"; title: "Elegir fondo de escritorio"
        currentFolder: StandardPaths.standardLocations(StandardPaths.PicturesLocation)[0]
        nameFilters: ["Imágenes (*.png *.jpg *.jpeg *.webp *.avif *.bmp)"]
        onAccepted: window.save("wallpaper", selectedFile.toString())
    }
    Rectangle {
        id: canvas; anchors.fill: parent; color: Ui.Theme.background
        Rectangle {
            width: 200; height: parent.height; color: Ui.Theme.panel
            Rectangle { anchors.right: parent.right; height: parent.height; width: 1; color: Ui.Theme.faintBorder }
            Ui.UiText { x: 24; y: 28; height: 28; text: "Singlr"; weight: 650; font.pixelSize: 15 }
            Column {
                x: 12; y: 88; width: 176; spacing: 4
                Repeater {
                    model: [{label: "Apariencia", icon: "sun", key: "appearance"}, {label: "Fondo", icon: "image", key: "wallpaper"}, {label: "Dock", icon: "squares-four", key: "dock"}]
                    delegate: Controls.AbstractButton {
                        id: nav; required property var modelData
                        width: 176; height: 36
                        objectName: "nav-" + modelData.key
                        Accessible.name: modelData.label
                        onClicked: window.page = modelData.key
                        background: Rectangle { radius: 6; color: window.page === nav.modelData.key ? Ui.Theme.hover : nav.hovered ? Ui.Theme.content : "transparent"; border.color: nav.visualFocus ? Ui.Theme.control : "transparent" }
                        contentItem: Row {
                            leftPadding: 12; spacing: 10
                            Ui.Icon { name: nav.modelData.icon; width: 16; height: 36; font.pixelSize: 16 }
                            Ui.UiText { text: nav.modelData.label; height: 36; color: window.page === nav.modelData.key ? Ui.Theme.text : Ui.Theme.secondary }
                        }
                    }
                }
            }
        }
        Item {
            x: 240; y: 32; width: parent.width - 280; height: parent.height - 64
            Ui.UiText { height: 32; text: window.page === "appearance" ? "Apariencia" : window.page === "dock" ? "Dock" : "Fondo"; font.pixelSize: 20; weight: 620 }
            Column {
                y: 72; width: parent.width; spacing: 20; visible: window.page === "appearance"
                Item {
                    width: parent.width; height: 40
                    Ui.UiText { height: 40; text: "Modo"; color: Ui.Theme.secondary }
                    Rectangle {
                        anchors.right: parent.right; width: 276; height: 36; y: 2; radius: 7; color: Ui.Theme.panel; border.color: Ui.Theme.border
                        Row {
                            x: 3; y: 3
                            Repeater {
                                model: [{label: "Claro", key: "light"}, {label: "Oscuro", key: "dark"}, {label: "Automático", key: "auto"}]
                                delegate: Controls.AbstractButton {
                                    id: mode; required property var modelData
                                    objectName: "mode-" + modelData.key
                                    width: 90; height: 30
                                    Accessible.name: modelData.label; Accessible.role: Accessible.RadioButton; Accessible.checked: Ui.Appearance.mode === modelData.key
                                    enabled: !Ui.Appearance.busy
                                    onClicked: window.save("mode", modelData.key)
                                    background: Rectangle { radius: 5; color: Ui.Appearance.mode === mode.modelData.key ? Ui.Theme.raised : "transparent"; border.color: mode.visualFocus ? Ui.Theme.control : "transparent" }
                                    contentItem: Ui.UiText { text: mode.modelData.label; color: Ui.Appearance.mode === mode.modelData.key ? Ui.Theme.text : Ui.Theme.muted; horizontalAlignment: Text.AlignHCenter }
                                }
                            }
                        }
                    }
                }
                Rectangle { width: parent.width; height: 1; color: Ui.Theme.faintBorder }
                Item {
                    width: parent.width; height: 40
                    Ui.UiText { height: 40; text: "Color de acento"; color: Ui.Theme.secondary }
                    Row {
                        anchors.right: parent.right; height: 40; spacing: 10
                        Repeater {
                            model: window.accents
                            delegate: Controls.AbstractButton {
                                id: swatch; required property var modelData
                                objectName: "accent-" + modelData.label
                                width: 28; height: 40
                                Accessible.name: modelData.label; Accessible.role: Accessible.RadioButton; Accessible.checked: Ui.Appearance.selectedAccent === modelData.color
                                enabled: !Ui.Appearance.busy
                                onClicked: window.save("accent", modelData.color)
                                background: Item {
                                    Rectangle { anchors.centerIn: parent; width: 28; height: 28; radius: 14; color: "transparent"; border.width: 1; border.color: Ui.Appearance.selectedAccent === swatch.modelData.color || swatch.visualFocus ? Ui.Theme.control : "transparent" }
                                    Rectangle { anchors.centerIn: parent; width: 20; height: 20; radius: 10; color: swatch.modelData.color }
                                }
                            }
                        }
                    }
                }
                Rectangle { width: parent.width; height: 1; color: Ui.Theme.faintBorder }
                Item {
                    width: parent.width; height: 40
                    Ui.UiText { height: 40; text: "Material"; color: Ui.Theme.secondary }
                    Rectangle {
                        anchors.right: parent.right; width: 306; height: 36; y: 2
                        radius: 7; color: Ui.Theme.panel; border.color: Ui.Theme.border
                        Row {
                            x: 3; y: 3
                            Repeater {
                                model: [{label: "Sólido", key: "solid"}, {label: "Vidrio", key: "glass"}]
                                delegate: Controls.AbstractButton {
                                    id: materialButton; required property var modelData
                                    objectName: "material-" + modelData.key
                                    width: 100; height: 30
                                    Accessible.name: modelData.label; Accessible.role: Accessible.RadioButton
                                    Accessible.checked: Ui.Appearance.material === modelData.key
                                    onClicked: window.save("material", modelData.key)
                                    background: Rectangle {
                                        radius: 5; color: Ui.Appearance.material === materialButton.modelData.key ? Ui.Theme.raised : "transparent"
                                        border.color: materialButton.visualFocus ? Ui.Theme.control : "transparent"
                                    }
                                    contentItem: Ui.UiText {
                                        text: materialButton.modelData.label; horizontalAlignment: Text.AlignHCenter
                                        color: Ui.Appearance.material === materialButton.modelData.key ? Ui.Theme.text : Ui.Theme.muted
                                    }
                                }
                            }
                        }
                    }
                }
                Item {
                    width: parent.width; height: 36
                    Ui.UiText { height: 36; text: "Intensidad"; color: Ui.Theme.secondary }
                    Ui.SliderControl {
                        id: materialIntensity; objectName: "materialIntensity"
                        anchors.right: parent.right; width: 306; height: 36
                        from: 0; to: 100; stepSize: 1
                        value: Ui.Appearance.intensity
                        enabled: Ui.Appearance.material !== "solid" && !Ui.Appearance.reduceTransparency
                        Accessible.name: "Intensidad del material"
                        // Persist once at release; keyboard changes are committed immediately.
                        onMoved: if (!pressed) commitIntensity.restart()
                        onPressedChanged: if (!pressed) commitIntensity.restart()
                        Timer {
                            id: commitIntensity; interval: 0
                            onTriggered: if (!materialIntensity.pressed) window.save("intensity", Math.round(materialIntensity.value))
                        }
                    }
                }
                Item {
                    width: parent.width; height: 36
                    Ui.UiText { height: 36; text: "Reducir transparencia"; color: Ui.Theme.secondary }
                    Ui.Toggle {
                        objectName: "reduceTransparency"; anchors.right: parent.right; width: 34; height: 36
                        Accessible.name: "Reducir transparencia"; checked: Ui.Appearance.reduceTransparency
                        onToggled: window.save("reduceTransparency", checked)
                    }
                }
                Ui.UiText {
                    width: parent.width; height: 36; font.pixelSize: 12; color: Ui.Theme.muted
                    text: Ui.Appearance.reduceTransparency ? "Superficies sólidas para facilitar la lectura."
                        : ""
                }
                Ui.UiText { width: parent.width; height: 36; text: Ui.Appearance.mode === "auto" ? "Sigue el horario automático de KDE y Luz nocturna." : ""; color: Ui.Theme.muted; font.pixelSize: 12 }
            }
            Column {
                y: 72; width: parent.width; spacing: 20; visible: window.page === "dock"
                Item {
                    width: parent.width; height: 40
                    Ui.UiText { height: 40; text: "Modo"; color: Ui.Theme.secondary }
                    Rectangle {
                        anchors.right: parent.right; width: 246; height: 36; y: 2
                        radius: 7; color: Ui.Theme.panel; border.color: Ui.Theme.border
                        Row {
                            x: 3; y: 3
                            Repeater {
                                model: [{label: "Flotante", key: "floating"}, {label: "Fijo", key: "fixed"}]
                                delegate: Controls.AbstractButton {
                                    id: dockMode; required property var modelData
                                    objectName: "dock-mode-" + modelData.key
                                    width: 120; height: 30
                                    Accessible.name: modelData.label; Accessible.role: Accessible.RadioButton
                                    Accessible.checked: Ui.DockSettings.mode === modelData.key
                                    onClicked: Ui.DockSettings.setMode(modelData.key)
                                    background: Rectangle {
                                        radius: 5; color: Ui.DockSettings.mode === dockMode.modelData.key ? Ui.Theme.raised : "transparent"
                                        border.color: dockMode.visualFocus ? Ui.Theme.control : "transparent"
                                    }
                                    contentItem: Ui.UiText { text: dockMode.modelData.label; horizontalAlignment: Text.AlignHCenter }
                                }
                            }
                        }
                    }
                }
                Rectangle { width: parent.width; height: 1; color: Ui.Theme.faintBorder }
                Item {
                    width: parent.width; height: 36
                    Ui.UiText { height: 36; text: "Altura"; color: Ui.Theme.secondary }
                    Ui.SliderControl {
                        id: dockHeight; objectName: "dockHeight"
                        anchors.right: heightLabel.left; anchors.rightMargin: 16; width: 230; height: 36
                        from: 40; to: 72; stepSize: 8; snapMode: Controls.Slider.SnapAlways
                        value: Ui.DockSettings.height
                        Accessible.name: "Altura del dock"
                        onMoved: Ui.DockSettings.setHeight(Math.round(value))
                    }
                    Ui.UiText { id: heightLabel; anchors.right: parent.right; width: 48; height: 36; text: Ui.DockSettings.height + " px"; horizontalAlignment: Text.AlignRight; color: Ui.Theme.secondary }
                }
                Rectangle { width: parent.width; height: 1; color: Ui.Theme.faintBorder }
                Item {
                    width: parent.width; height: 36
                    Ui.UiText { height: 36; text: "Ocultar automáticamente"; color: Ui.Theme.secondary }
                    Ui.Toggle {
                        objectName: "dockAutoHide"; anchors.right: parent.right; width: 34; height: 36
                        Accessible.name: "Ocultar automáticamente"; checked: Ui.DockSettings.autoHide
                        onToggled: Ui.DockSettings.setAutoHide(checked)
                    }
                }
            }
            Column {
                y: 72; width: parent.width; spacing: 20; visible: window.page === "wallpaper"
                Row {
                    spacing: 12
                    Repeater {
                        model: window.presets
                        delegate: Controls.AbstractButton {
                            id: preset; required property var modelData
                            objectName: modelData.key
                            width: (window.width - 316) / 4; height: 106
                            Accessible.name: modelData.label; Accessible.role: Accessible.RadioButton; Accessible.checked: Ui.Appearance.wallpaper === modelData.key
                            onClicked: window.save("wallpaper", modelData.key)
                            background: Item {
                                Rectangle { width: parent.width; height: 80; radius: 6; color: "transparent"; border.width: 2; border.color: Ui.Appearance.wallpaper === preset.modelData.key || preset.visualFocus ? Ui.Theme.control : Ui.Theme.border }
                                Ui.Wallpaper { x: 4; y: 4; width: parent.width - 8; height: 72; radius: 3; source: preset.modelData.key }
                                Ui.UiText { y: 84; height: 22; text: preset.modelData.label; font.pixelSize: 12; color: Ui.Theme.secondary }
                            }
                        }
                    }
                }
                Item {
                    width: parent.width; height: 36
                    Ui.UiText { height: 36; text: "Imagen personalizada"; color: Ui.Theme.secondary }
                    Ui.Button { anchors.right: parent.right; height: 36; width: 142; icon: "image"; label: "Elegir imagen…"; onClicked: fileDialog.open() }
                }
                Ui.Wallpaper { id: preview; width: parent.width; height: 228; radius: 6 }
                Ui.UiText { width: parent.width; height: 24; text: preview.imageFailed ? "Imagen no disponible. Se muestra el fondo predeterminado." : "Vista previa"; color: preview.imageFailed ? Ui.Theme.error : Ui.Theme.muted; font.pixelSize: 12 }
            }
            Ui.UiText { anchors.bottom: parent.bottom; width: parent.width; height: 36; text: window.feedback; color: Ui.Theme.error; wrapMode: Text.WordWrap; font.pixelSize: 12; Accessible.role: Accessible.AlertMessage }
        }
    }
    Component.onCompleted: Ui.Theme.reloadSettings()
    // Captura explícita para revisión: no modifica preferencias.
    Timer {
        interval: 1200; running: Qt.application.arguments.some(arg => arg.indexOf("--capture=") === 0)
        onTriggered: {
            const arg = Qt.application.arguments.find(value => value.indexOf("--capture=") === 0);
            canvas.grabToImage(result => {
                const path = arg.slice(10);
                if (!result.saveToFile(path)) { Qt.exit(1); return; }
                console.log("CAPTURE_OK " + path); Qt.quit();
            });
        }
    }
}
