pragma Singleton
import QtQuick
import Singlr.System
QtObject {
    readonly property string mode: KDEAppearance.dockMode
    readonly property int height: KDEAppearance.dockHeight
    readonly property bool autoHide: KDEAppearance.dockAutoHide
    function setMode(value) { KDEAppearance.setDockMode(value); }
    function setHeight(value) { KDEAppearance.setDockHeight(value); }
    function setAutoHide(value) { KDEAppearance.setDockAutoHide(value); }
}
