import QtQuick

// Cache content briefly, never keep a native surface alive for the cache.
Loader {
    id: loader
    property bool opened: false
    property int releaseDelay: 2500
    active: opened || release.running
    focus: true
    visible: opened
    onOpenedChanged: {
        if (opened) release.stop();
        else if (item) release.restart();
    }
    Timer { id: release; interval: loader.releaseDelay }
    // Tras liberar el contenido: recolección de QML y devolución de memoria al sistema (P-016).
    onActiveChanged: if (!active) trim.restart()
    Timer {
        id: trim; interval: 500
        onTriggered: {
            gc();
            // qmllint disable unqualified
            if (typeof SinglrSystem !== "undefined" && SinglrSystem.trimMemory) SinglrSystem.trimMemory();
            // qmllint enable unqualified
        }
    }
}
