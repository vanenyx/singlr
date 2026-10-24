pragma Singleton
import QtQuick
import "Theme.js" as Palette
Item {
    id: theme
    property bool dark: true
    property color base: dark ? "#08090a" : "#f8f8f8"
    property color accent: "#7170ff"
    // Controles (deslizadores, interruptores, barras): blanco neutro por decisión del creador.
    readonly property color control: text
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
