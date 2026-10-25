pragma Singleton
import QtQuick
import QtCore
import Singlr.System
Item {
    id: appearance
    readonly property url location: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/singlr/singlr.conf"
    readonly property string mode: KDEAppearance.mode
    readonly property bool dark: KDEAppearance.dark
    readonly property string accent: String(KDEAppearance.accent)
    readonly property string selectedAccent: String(KDEAppearance.selectedAccent)
    readonly property bool busy: KDEAppearance.busy
    readonly property string error: KDEAppearance.error
    property string wallpaper: "singlr:linear"
    Settings { id: settings; location: appearance.location; category: "Appearance" }
    function reload() {
        settings.sync();
        const savedWallpaper = String(settings.value("wallpaper", "singlr:linear"));
        wallpaper = savedWallpaper.indexOf("file:///") === 0 || ["singlr:linear", "singlr:glow", "singlr:light", "singlr:graphite"].indexOf(savedWallpaper) >= 0 ? savedWallpaper : "singlr:linear";
    }
    function save(key, value) {
        if (key === "mode") { KDEAppearance.setMode(value); return; }
        if (key === "accent") { KDEAppearance.setAccent(value); return; }
        if (key !== "wallpaper") return;
        settings.setValue(key, value);
        settings.sync();
        reload();
        KDEAppearance.reloadShell();
    }
    Component.onCompleted: reload()
}
