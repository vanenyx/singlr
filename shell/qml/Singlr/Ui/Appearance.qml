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
    readonly property bool glassAvailable: KDEAppearance.glassAvailable
    readonly property string effectiveMaterial: reduceTransparency || intensity === 0 || material === "solid" ? "solid" : "glass"
    property string wallpaper: "singlr:linear"
    property bool wallpaperAnimated: true
    property bool wallpaperReactive: true
    property int wallpaperQuality: 1
    Settings { id: settings; location: appearance.location; category: "Appearance" }
    function reload() {
        settings.sync();
        KDEAppearance.refreshMaterials();
        const savedWallpaper = String(settings.value("wallpaper", "singlr:linear"));
        wallpaper = savedWallpaper.indexOf("file:///") === 0 || ["singlr:linear", "singlr:glow", "singlr:light", "singlr:graphite", "singlr:singularity"].indexOf(savedWallpaper) >= 0 ? savedWallpaper : "singlr:linear";
        wallpaperAnimated = String(settings.value("wallpaperAnimated", true)) === "true";
        wallpaperReactive = String(settings.value("wallpaperReactive", true)) === "true";
        const quality = Number(settings.value("wallpaperQuality", 1));
        wallpaperQuality = Number.isInteger(quality) && quality >= 0 && quality <= 2 ? quality : 1;
    }
    function save(key, value) {
        if (key === "mode") { KDEAppearance.setMode(value); return; }
        if (key === "accent") { KDEAppearance.setAccent(value); return; }
        if (key === "material") { KDEAppearance.setMaterial(value); return; }
        if (key === "intensity") { KDEAppearance.setIntensity(value); return; }
        if (key === "reduceTransparency") { KDEAppearance.setReduceTransparency(value); return; }
        if (["wallpaper", "wallpaperAnimated", "wallpaperReactive", "wallpaperQuality"].indexOf(key) < 0) return;
        if (key === "wallpaperQuality" && (!Number.isInteger(value) || value < 0 || value > 2)) return;
        if ((key === "wallpaperAnimated" || key === "wallpaperReactive") && typeof value !== "boolean") return;
        settings.setValue(key, value);
        settings.sync();
        reload();
        KDEAppearance.reloadShell();
    }
    Component.onCompleted: reload()
}
