pragma ComponentBehavior: Bound
import QtQuick
import org.kde.plasma.private.clipboard as Clipboard
import Singlr.System

Item {
    id: backend
    // Plasma 6.8.1's SystemClipboard assumes XCB outside Wayland and crashes on
    // offscreen (xcb_get_input_focus with a null connection). Tests use doubles.
    readonly property bool supported: Qt.platform.pluginName.startsWith("wayland") || Qt.platform.pluginName === "xcb"
    readonly property var history: native.item ? (native.item as NativeBackend).history : empty
    ListModel { id: empty }
    Loader {
        id: native; active: backend.supported
        sourceComponent: Component { NativeBackend {} }
    }
    component NativeBackend: Item {
        readonly property alias history: history
        // Retain Klipper::self(): observation, persistence and D-Bus.
        Clipboard.KlipperInterface { id: service }
        Clipboard.HistoryModel { id: nativeHistory }
        ClipboardHistoryModel { id: history; sourceModel: nativeHistory }
    }
}
