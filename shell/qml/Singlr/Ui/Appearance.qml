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
    readonly property bool softwareRendering: KDEAppearance.softwareRendering
    readonly property string material: KDEAppearance.material
    readonly property int intensity: KDEAppearance.intensity
    readonly property bool reduceTransparency: KDEAppearance.reduceTransparency
    readonly property bool liquidAvailable: KDEAppearance.liquidAvailable
    readonly property string effectiveMaterial: reduceTransparency || intensity === 0 || material === "solid" ? "solid" : material === "liquid" && liquidAvailable ? "liquid" : "glass"
    property string wallpaper: "singlr:linear"
    Settings { id: settings; location: appearance.location; category: "Appearance" }
    function reload() {
        settings.sync();
        KDEAppearance.refreshMaterials();
        const savedWallpaper = String(settings.value("wallpaper", "singlr:linear"));
        wallpaper = savedWallpaper.indexOf("file:///") === 0 || ["singlr:linear", "singlr:glow", "singlr:light", "singlr:graphite"].indexOf(savedWallpaper) >= 0 ? savedWallpaper : "singlr:linear";
    }
    function save(key, value) {
        if (key === "mode") { KDEAppearance.setMode(value); return; }
        if (key === "accent") { KDEAppearance.setAccent(value); return; }
        if (key === "material") { KDEAppearance.setMaterial(value); return; }
        if (key === "intensity") { KDEAppearance.setIntensity(value); return; }
        if (key === "reduceTransparency") { KDEAppearance.setReduceTransparency(value); return; }
        if (key !== "wallpaper") return;
        settings.setValue(key, value);
        settings.sync();
        reload();
        KDEAppearance.reloadShell();
    }
    Component.onCompleted: reload()
}
