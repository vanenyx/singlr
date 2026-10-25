pragma ComponentBehavior: Bound
import QtQuick
import org.kde.kcmutils as KCMUtils
import Singlr.Ui

Row {
    id: row
    property var backend: NightLight
    width: 308; height: 36; spacing: 10
    Icon { name: "moon"; width: 28; height: 36; Accessible.name: "Luz nocturna" }
    Toggle {
        objectName: "nightLightToggle"; width: 34
        checked: row.backend.configured && !row.backend.inhibited
        enabled: row.backend.togglable
        Accessible.name: "Luz nocturna · " + row.backend.status
        onToggled: row.backend.toggle()
    }
    UiText { width: parent.width - 120; height: 36; text: row.backend.status; color: Theme.secondary; elide: Text.ElideRight }
    Tool { icon: "gear"; description: "Configurar luz nocturna"; onClicked: KCMUtils.KCMLauncher.openSystemSettings("kcm_nightlight") }
}
