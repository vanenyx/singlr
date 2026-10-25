pragma Singleton
import QtQuick
import QtCore
Item {
    id: appearance
    readonly property url location: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/singlr/singlr.conf"
    property string mode: "dark"
    property string accent: "#5e6ad2"
    property string wallpaper: "singlr:linear"
    property bool applyToApps: false
    Settings { id: settings; location: appearance.location; category: "Appearance" }
    function reload() {
        settings.sync();
        const savedMode = String(settings.value("mode", "dark"));
        mode = ["dark", "light", "auto"].indexOf(savedMode) >= 0 ? savedMode : "dark";
        const savedAccent = String(settings.value("accent", "#5e6ad2"));
        accent = /^#[0-9a-f]{6}$/i.test(savedAccent) ? savedAccent : "#5e6ad2";
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
