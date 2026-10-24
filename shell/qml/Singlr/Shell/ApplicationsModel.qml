pragma ComponentBehavior: Bound
import QtQuick
import org.kde.plasma.private.kicker as Kicker
import org.kde.kitemmodels as ItemModels

// KDE's XDG application catalogue, including user/Flatpak desktop entries.
ItemModels.KSortFilterProxyModel {
    id: applications
    property string query: ""
    property int catalogueRevision: 0
    property Kicker.RootModel root: Kicker.RootModel {
        flat: true
        sorted: true
        showSeparators: false
        autoPopulate: true
        showTopLevelItems: true
        showAllApps: true
        showAllAppsCategorized: false
        showRecentApps: false
        showRecentDocs: false
        showRecentFolders: false
        showPowerSession: false
        showFavoritesPlaceholder: false
        showRootSeparator: false
        onRefreshed: applications.catalogueRevision++
    }
    // RootModel recreates its child after sycoca changes, even when count is unchanged.
    readonly property var catalogue: catalogueRevision >= 0 ? root.modelForRow(0) : null
    sourceModel: catalogue
    filterRoleName: "display"
    filterCaseSensitivity: Qt.CaseInsensitive
    filterString: query
    property var launchIndex
    function run(idx) { launchIndex = mapToSource(idx); return catalogue.trigger(launchIndex.row, "", null); }
}
