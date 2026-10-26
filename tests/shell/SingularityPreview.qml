pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import Singlr.Ui

Window {
    id: window
    width: 1280; height: 800; visible: true; color: "black"
    title: "Singularidad · vista previa aislada"
    Item {
        id: scene; anchors.fill: parent; focus: true
        Wallpaper { anchors.fill: parent; source: "singlr:singularity"; liveAllowed: true }
        Keys.onSpacePressed: Appearance.wallpaperAnimated = !Appearance.wallpaperAnimated
        Keys.onEscapePressed: Qt.quit()
        Text {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 24; anchors.horizontalCenter: parent.horizontalCenter
            text: "SINGULARIDAD   ·   Espacio para pausar   ·   Esc para cerrar"
            color: "#888888"; font.pixelSize: 12
        }
    }
}
