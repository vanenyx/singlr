pragma Singleton
import QtQuick
import QtCore
Item {
    id: appearance
    readonly property url location: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/singlr/singlr.conf"
    // The greeter has no Singlr.System plugin: follow its live KDE palette.
    SystemPalette { id: kdePalette; colorGroup: SystemPalette.Active }
    readonly property bool dark: kdePalette.window.hslLightness < 0.5
    readonly property string mode: dark ? "dark" : "light"
    readonly property color accent: kdePalette.highlight
    property string wallpaper: "singlr:linear"
    property bool applyToApps: false
    Settings { id: settings; location: appearance.location; category: "Appearance" }
    function reload() {
        settings.sync();
        const savedWallpaper = String(settings.value("wallpaper", "singlr:linear"));
        wallpaper = savedWallpaper.indexOf("file:///") === 0 || ["singlr:linear", "singlr:glow", "singlr:light", "singlr:graphite"].indexOf(savedWallpaper) >= 0 ? savedWallpaper : "singlr:linear";
        const savedApply = settings.value("applyToApps", false);
        applyToApps = savedApply === true || savedApply === "true";
    }
    function save(key, value) {
        settings.setValue(key, value);
        settings.sync();
        reload();
    }
    Component.onCompleted: reload()
}
