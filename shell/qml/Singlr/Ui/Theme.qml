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
    readonly property color error: dark ? "#ef9a9a" : "#ae3535"
    readonly property color powerSaver: "#4ea7fc"
    readonly property color powerPerformance: "#eb5757"
    readonly property color surface: Palette.alpha(raised, .93)
    readonly property color barSurface: Palette.alpha(panel, .90)
    readonly property color dockSurface: Palette.alpha(panel, .80)
    readonly property color sheen: Palette.alpha(text, .04)
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
    readonly property color secondary: dark ? "#d0d6e0" : Palette.ink(base,35,contrast)
    readonly property color muted: Palette.ink(base,dark?58.5:46,contrast)
    readonly property color faint: Palette.ink(base,dark?43:56,contrast)
    readonly property color selection: Palette.alpha(accent,(dark?.14:.11)*contrast)
    readonly property color accentText: Palette.accentInk(accent,dark,contrast)
    readonly property string family: inter.name
    readonly property string icons: phosphor.name
    readonly property bool ready: inter.status === FontLoader.Ready && phosphor.status === FontLoader.Ready
    readonly property int radius: 12
    FontLoader { id: inter; source: "../../../../third_party/inter/InterVariable.ttf" }
    FontLoader { id: phosphor; source: "../../../../third_party/phosphor/Phosphor.ttf" }
}
