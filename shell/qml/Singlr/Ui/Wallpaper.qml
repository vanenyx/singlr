pragma ComponentBehavior: Bound
import QtQuick
Rectangle {
    id: wallpaper
    property string source: Appearance.wallpaper
    readonly property bool imageFailed: picture.status === Image.Error
    color: source === "singlr:light" ? Theme.wallpaperLight : source === "singlr:graphite" ? Theme.wallpaperGraphite : Theme.wallpaperDefault
    clip: true
    Rectangle {
        anchors.fill: parent
        visible: wallpaper.source === "singlr:glow"
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.wallpaperDefault }
            GradientStop { position: 0.55; color: Theme.wallpaperGlow }
            GradientStop { position: 1; color: Theme.wallpaperDefault }
        }
    }
    Image {
        id: picture; anchors.fill: parent
        source: wallpaper.source.indexOf("file:///") === 0 ? wallpaper.source : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true; autoTransform: true
        visible: status === Image.Ready
    }
}
