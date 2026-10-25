import QtQuick
import org.kde.kwin as KWin
import org.kde.plasma.core as PlasmaCore

// KWin owns Alt/Shift+Tab, modifier release, cancellation and window activation.
KWin.TabBoxSwitcher {
    id: switcher
    Instantiator {
        active: switcher.visible
        delegate: PlasmaCore.Dialog {
            location: PlasmaCore.Types.Floating
            backgroundHints: PlasmaCore.Types.NoBackground
            flags: Qt.ToolTip | Qt.X11BypassWindowManagerHint
            visible: true
            x: switcher.screenGeometry.x + (switcher.screenGeometry.width - frame.width) / 2
            y: switcher.screenGeometry.y + (switcher.screenGeometry.height - frame.height) / 2
            mainItem: SwitcherView {
                id: frame
                windowModel: switcher.model
                selectedIndex: switcher.currentIndex
                screenGeometry: switcher.screenGeometry
                onSelectionRequested: index => switcher.currentIndex = index
                onActivated: index => switcher.model.activate(index)
                thumbnailComponent: Component {
                    KWin.WindowThumbnail { wId: parent.windowId }
                }
            }
            onSceneGraphError: () => {}
        }
    }
}
