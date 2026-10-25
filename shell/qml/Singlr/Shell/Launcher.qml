pragma ComponentBehavior: Bound
import QtQuick
import org.kde.milou as Milou
import org.kde.kquickcontrolsaddons as Addons
import Singlr.Ui
FocusScope {
    id: launcher
    property var dockController: null
    // qmllint disable unqualified
    property var systemBridge: typeof SinglrSystem !== "undefined" ? SinglrSystem : null
    // qmllint enable unqualified
    Addons.Clipboard { id: clipboard }
    property bool sessionMode: false
    property bool applicationsMode: false
    property Item backdrop
    property var modelOverride: null
    readonly property var resultsModel: modelOverride || (applicationsMode ? appsLoader.item : runnerLoader.item)
    property alias query: input.text
    property alias selectedIndex: list.currentIndex
    readonly property int resultCount: list.count
    readonly property var selectedActions: !applicationsMode && selectedResult ? selectedResult.resultActions : []
    readonly property var selectedResult: list.currentItem
    readonly property bool calculation: selectedResult ? isCalculation(selectedResult.rowData) : false
    readonly property string primaryAction: calculation ? "Copiar" : "Abrir"
    readonly property var contextEntries: makeEntries()
    property bool actionsOpen: false
    property int actionIndex: 0
    readonly property alias actionMenu: resultMenu
    readonly property string emptyMessage: !query ? (applicationsMode ? "No hay aplicaciones disponibles" : "Busca o abre Todas las aplicaciones") : (resultsModel && resultsModel.querying) ? "Buscando…" : "Sin resultados"
    signal closed()
    Keys.onEscapePressed: { if (actionsOpen) resultMenu.close(); else close(); }
    width: 760; height: 542
    Loader {
        id: runnerLoader
        active: launcher.visible && !launcher.applicationsMode && launcher.query.length > 0 && !launcher.modelOverride
        sourceComponent: Component {
            Milou.ResultsModel {
                queryString: launcher.query
                limit: 40
                favoriteIds: ["calculator", "unitconverter"]
                onQueryStringChangeRequested: (queryString, pos) => { launcher.query = queryString; input.cursorPosition = pos; }
            }
        }
    }
    DeferredLoader {
        id: appsLoader
        opened: launcher.visible && launcher.applicationsMode && !launcher.modelOverride
        sourceComponent: Component { ApplicationsModel { query: launcher.query } }
    }
    function showApplications() { applicationsMode = true; query = ""; selectedIndex = 0; actionsOpen = false; input.forceActiveFocus(); }
    function actionArray(value) {
        if (!value) return [];
        if (value.length !== undefined) return value;
        let rows = [];
        for (let i = 0; i < value.count; ++i) rows.push(value.get(i));
        return rows;
    }
    function open(apps = false) { query = ""; applicationsMode = apps; visible = true; selectedIndex = 0; actionsOpen = false; input.forceActiveFocus(); }
    function focusInput() { input.forceActiveFocus(); }
    function close() { resultMenu.close(); actionsOpen = false; visible = false; closed(); }
    function isCalculation(row) { return /^(calculator|unitconverter)(_|$)/.test(String(row?.id || "")); }
    function resultUrls(row) {
        if (!row) return [];
        const value = row.urls || (row.url ? [row.url] : []);
        return actionArray(value).map(url => String(url));
    }
    function appUrl(row) {
        const favorite = String(row?.favoriteId || "");
        if (favorite.startsWith("applications:")) return favorite;
        const url = resultUrls(row).find(u => u.startsWith("applications:") || u.endsWith(".desktop"));
        if (!url) return "";
        return dockController ? dockController.normalizeLauncher(url) : url;
    }
    function makeEntries() {
        if (!selectedResult) return [];
        const row = selectedResult.rowData;
        let entries = selectedActions.map((a, i) => ({label: String(a.text || "").replace(/&/g, ""),
            icon: "dots-three", enabled: a.enabled !== false, action: "runner", runnerAction: i}));
        const urls = resultUrls(row);
        if (!appUrl(row) && urls.length && urls.every(u => u.startsWith("file:")) && systemBridge) {
            entries.push({label: "Mostrar en carpeta", icon: "folder", action: "folder"});
        }
        const url = appUrl(row);
        if (url && dockController) entries.push({label: dockController.isPinned(url) ? "Quitar del dock" : "Mantener en el dock",
            icon: "push-pin", action: "pin", url: url, keep: !dockController.isPinned(url)});
        return entries;
    }
    function move(delta) {
        const count = actionsOpen ? contextEntries.length : list.count;
        if (!count) return;
        if (actionsOpen) { resultMenu.move(delta); actionIndex = resultMenu.currentIndex; }
        else selectedIndex = (Math.max(0, selectedIndex) + delta + count) % count;
    }
    function openActions(anchor = input, px = input.width, py = input.height) {
        if (!contextEntries.length) return;
        if (actionsOpen) { resultMenu.close(); return; }
        actionsOpen = true; actionIndex = 0;
        resultMenu.showAt(anchor, px, py);
    }
    function triggerAction(entry) {
        if (!entry || selectedIndex < 0) return;
        const idx = resultsModel.index(selectedIndex, 0);
        if (entry.action === "pin") dockController.setPinned(entry.url, entry.keep);
        else if (entry.action === "folder") { systemBridge.showInFolder(resultUrls(selectedResult.rowData)); close(); }
        else if (resultsModel.runAction(idx, entry.runnerAction)) close();
    }
    function run() {
        if (selectedIndex < 0 || selectedIndex >= list.count) return;
        if (actionsOpen) { triggerAction(contextEntries[actionIndex]); resultMenu.close(); return; }
        if (calculation) { clipboard.content = selectedResult.title; close(); return; }
        if (resultsModel.run(resultsModel.index(selectedIndex, 0))) close();
        else input.forceActiveFocus();
    }
    onQueryChanged: { resultMenu.close(); selectedIndex = 0; actionsOpen = false; }
    Glass { anchors.fill: parent; backdrop: launcher.backdrop; visible: !launcher.sessionMode }
    Rectangle { anchors.fill: parent; visible: launcher.sessionMode; radius: 12; color: Theme.surface; border.color: Theme.focusBorder }
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; onPressed: launcher.focusInput() }
    Icon { x: 24; y: 25; width: 20; height: 20; font.pixelSize: 20; name: "magnifying-glass" }
    TextInput {
        id: input; objectName: "launcherInput"
        x: 62; y: 18; width: parent.width-124; height: 40
        color: Theme.text; selectionColor: Theme.selection; selectedTextColor: Theme.text
        font.family: Theme.family; font.pixelSize: 13; clip: true; focus: true
        verticalAlignment: TextInput.AlignVCenter
        Accessible.name: launcher.applicationsMode ? "Buscar en todas las aplicaciones" : "Buscar aplicaciones, archivos y comandos"
        Keys.onUpPressed: launcher.move(-1)
        Keys.onDownPressed: launcher.move(1)
        Keys.onReturnPressed: launcher.run()
        Keys.onEnterPressed: launcher.run()
        Keys.onEscapePressed: { if (launcher.actionsOpen) resultMenu.close(); else launcher.close(); }
        Keys.onPressed: event => {
            if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_K) { launcher.openActions(); event.accepted = true; }
        }
        UiText { anchors.fill: parent; text: launcher.applicationsMode ? "Buscar en todas las aplicaciones…" : "Buscar aplicaciones, archivos, comandos…"; font.pixelSize: 13; color: Theme.faint; visible: !input.text }
    }
    ShortcutHint { x: parent.width-47; y: 27; text: "esc" }
    Rectangle { y: 76; width: parent.width; height: 1; color: Theme.border }
    ListView {
        id: list; x: 10; y: 88; width: parent.width-20; height: parent.height-146
        model: launcher.resultsModel; clip: true; currentIndex: 0
        highlightMoveDuration: 0; boundsBehavior: Flickable.StopAtBounds
        onCountChanged: { if (count && currentIndex < 0) currentIndex = 0; }
        onCurrentIndexChanged: { resultMenu.close(); launcher.actionsOpen = false; positionViewAtIndex(currentIndex, ListView.Contain); }
        section.property: launcher.applicationsMode ? "" : "category"
        section.criteria: ViewSection.FullString
        section.delegate: UiText {
            required property string section
            width: list.width; height: 26; leftPadding: 14
            text: section; color: Theme.muted; font.pixelSize: 11
        }
        delegate: ListItem {
            id: result
            required property var model
            required property int index
            readonly property var rowData: model
            resultActions: launcher.actionArray(model.actions)
            width: ListView.view.width
            title: String(model.display || "")
            subtitle: launcher.applicationsMode ? "" : String(model.subtext || "")
            iconSource: model.decoration
            selected: launcher.selectedIndex === index
            onClicked: { launcher.selectedIndex = index; launcher.run(); }
            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: point => { launcher.selectedIndex = result.index; launcher.openActions(result, point.position.x, point.position.y); }
            }
            Keys.onMenuPressed: { launcher.selectedIndex = index; launcher.openActions(result, width - 12, height); }
        }
        UiText {
            anchors.centerIn: parent; visible: list.count === 0
            text: launcher.emptyMessage
            color: Theme.muted
        }
    }
    Rectangle { y: parent.height-42; width: parent.width; height: 1; color: Theme.border }
    Tool { x: 18; y: parent.height-35; icon: launcher.applicationsMode ? "arrow-left" : "squares-four"; label: launcher.applicationsMode ? "Búsqueda general" : "Todas las aplicaciones"; onClicked: { if (launcher.applicationsMode) launcher.open(); else launcher.showApplications(); } }
    Row { anchors.right: parent.right; anchors.rightMargin: 16; y: parent.height-35; spacing: 12
        Tool { icon: "key-return"; label: launcher.primaryAction; onClicked: launcher.run() }
        Tool { visible: launcher.contextEntries.length > 0; icon: "dots-three"; label: "Ctrl K"; description: "Acciones (Ctrl+K)"; onClicked: launcher.openActions() }
    }
    ContextMenu {
        id: resultMenu; objectName: "launcherActions"
        parent: launcher
        entries: launcher.contextEntries
        onCurrentIndexChanged: launcher.actionIndex = currentIndex
        onClosed: launcher.actionsOpen = false
        onTriggered: entry => launcher.triggerAction(entry)
    }
}
