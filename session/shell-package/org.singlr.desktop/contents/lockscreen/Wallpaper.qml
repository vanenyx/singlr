pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
Rectangle {
    id: wallpaper
    property string source: Appearance.wallpaper
    // Session surfaces supply the output size before the compositor configures
    // the window. Do not decode intermediate 1x1/default-window-sized copies.
    property size pixelSize: Qt.size(Math.ceil(width * Screen.devicePixelRatio), Math.ceil(height * Screen.devicePixelRatio))
    readonly property bool imageFailed: picture.status === Image.Error
    // qmltestrunner and standalone previews can also load this component.
    // qmllint disable unqualified
    readonly property bool nativeProvider: typeof SinglrWallpaperProvider !== "undefined" && SinglrWallpaperProvider
    // qmllint enable unqualified
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
        objectName: "wallpaperImage"
        sourceSize: wallpaper.pixelSize
        id: picture; anchors.fill: parent
        source: wallpaper.pixelSize.width > 0 && wallpaper.pixelSize.height > 0 && wallpaper.source.indexOf("file:///") === 0
            ? (wallpaper.nativeProvider ? "image://singlrwallpaper/" + encodeURIComponent(wallpaper.source) : wallpaper.source) : ""
        // Large, screen-specific images must not retain obsolete decoded sizes
        // after output reconfiguration or a wallpaper change.
        cache: false
        fillMode: Image.PreserveAspectCrop
        asynchronous: true; autoTransform: true
        visible: status === Image.Ready
    }
}
