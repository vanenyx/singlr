pragma Singleton
import QtQuick
import "Theme.js" as Palette
Item {
    id: theme
    property string mode: Appearance.mode
    property bool dark: Appearance.dark
    property color base: dark ? "#08090a" : "#f8f8f8"
    property color accent: Appearance.accent
    // Controles (deslizadores, interruptores, barras): blanco neutro por decisión del creador.
    readonly property color control: text
    readonly property color onControl: dark ? "#16171a" : "#f7f8f8"
    readonly property color track: Palette.alpha(dark ? Qt.color("white") : Qt.color("black"), 31/255)
    readonly property color toolHover: Palette.alpha(text, .05)
    readonly property color shadow: "#59000000"
    readonly property color softShadow: "#10000000"
    readonly property color scrim: "#38000000"
    readonly property color error: materialStrength > 0 ? Palette.accentInk(Qt.color("#eb5757"),dark,contrast,materialStrength) : dark ? "#ef9a9a" : "#8f2727"
    readonly property color powerSaver: "#4ea7fc"
    readonly property color powerPerformance: "#eb5757"
    readonly property bool softwareRendering: Appearance.softwareRendering
    readonly property bool translucent: Appearance.effectiveMaterial !== "solid" && !softwareRendering
    readonly property real materialStrength: translucent ? Appearance.intensity / 100 : 0
    readonly property real blurRadius: materialStrength * 64
    readonly property color surface: Palette.alpha(raised, Palette.materialOpacity(materialStrength, Appearance.liquidAvailable))
    readonly property color barSurface: Palette.alpha(panel, Palette.materialOpacity(materialStrength, Appearance.liquidAvailable))
    readonly property color dockSurface: Palette.alpha(panel, Palette.materialOpacity(materialStrength, Appearance.liquidAvailable))
    readonly property color sheen: Palette.alpha(text, .04)
    // Flat floating surfaces (P-020): one faint hairline when translucent, never a bright rim.
    readonly property color surfaceBorder: translucent ? faintBorder : border
    readonly property color wallpaperDefault: "#08090a"
    readonly property color wallpaperGlow: "#17191d"
    readonly property color wallpaperLight: "#e8e7e4"
    readonly property color wallpaperGraphite: "#292b2e"
    function reloadSettings() {
        Appearance.reload();
        mode = Qt.binding(() => Appearance.mode);
        accent = Qt.binding(() => Appearance.accent);
        dark = Qt.binding(() => Appearance.dark);
    }
    property real contrast: 1.0
    readonly property color background: Palette.level(base,0,contrast)
    readonly property color panel: Palette.level(base,dark?2.1:-1.5,contrast)
    readonly property color content: Palette.level(base,dark?4.3:2.5,contrast)
    readonly property color raised: Palette.level(base,dark?6.8:-3.8,contrast)
    readonly property color hover: Palette.level(base,dark?9:-6,contrast)
    readonly property color border: Palette.alpha(dark?Qt.color("white"):Qt.color("black"),(dark?.08:.09)*contrast)
    readonly property color faintBorder: Palette.alpha(dark?Qt.color("white"):Qt.color("black"),.05*contrast)
    readonly property color focusBorder: Palette.alpha(dark?Qt.color("white"):Qt.color("black"),.20*contrast)
    readonly property color text: dark ? "#f7f8f8" : Palette.ink(base,17,contrast)
    readonly property color secondary: Palette.materialInk(base,dark,"secondary",materialStrength,contrast)
    // Small text, placeholders and shortcuts retain AA on translucent surfaces.
    readonly property color muted: Palette.materialInk(base,dark,"muted",materialStrength,contrast)
    readonly property color faint: Palette.materialInk(base,dark,"faint",materialStrength,contrast)
    readonly property color selection: Palette.alpha(accent,(dark?.14:.11)*contrast)
    readonly property color accentText: Palette.accentInk(accent,dark,contrast,materialStrength)
    readonly property string family: inter.name
    readonly property string icons: phosphor.name
    readonly property bool ready: inter.status === FontLoader.Ready && phosphor.status === FontLoader.Ready
    readonly property int radius: 12
    FontLoader { id: inter; source: "../../../../third_party/inter/InterVariable.ttf" }
    FontLoader { id: phosphor; source: "../../../../third_party/phosphor/Phosphor.ttf" }
}
