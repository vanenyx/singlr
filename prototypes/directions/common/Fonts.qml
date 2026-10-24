import QtQuick
Item {
    property alias inter: interLoader.name
    property alias regular: regularLoader.name
    property alias light: lightLoader.name
    property alias fill: fillLoader.name
    readonly property bool ready: interLoader.status === FontLoader.Ready && regularLoader.status === FontLoader.Ready && lightLoader.status === FontLoader.Ready && fillLoader.status === FontLoader.Ready
    FontLoader { id: interLoader; source: "../../../third_party/inter/InterVariable.ttf" }
    FontLoader { id: regularLoader; source: "../../../third_party/phosphor/Phosphor.ttf" }
    FontLoader { id: lightLoader; source: "../../../third_party/phosphor/Phosphor-Light.ttf" }
    FontLoader { id: fillLoader; source: "../../../third_party/phosphor/Phosphor-Fill.ttf" }
}
