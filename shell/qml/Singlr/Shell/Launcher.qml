pragma ComponentBehavior: Bound
import QtQuick
import org.kde.milou as Milou
import Singlr.Ui
FocusScope {
    id: launcher
    property Item backdrop
    property var modelOverride: null
    readonly property var resultsModel: modelOverride || runnerLoader.item
    property alias query: input.text
    property alias selectedIndex: list.currentIndex
    readonly property int resultCount: list.count
    readonly property var selectedActions: selectedResult ? selectedResult.resultActions : []
    readonly property ListItem selectedResult: list.currentItem as ListItem
    property bool actionsOpen: false
    property int actionIndex: 0
    signal closed()
    width: 760; height: 542
    Loader {
        id: runnerLoader
        active: launcher.visible && launcher.query.length > 0 && !launcher.modelOverride
        sourceComponent: Component {
            Milou.ResultsModel {
                queryString: launcher.query
                limit: 40
                onQueryStringChangeRequested: (queryString, pos) => { launcher.query = queryString; input.cursorPosition = pos; }
            }
        }
    }
    function actionArray(value) {
        if (!value) return [];
        if (value.length !== undefined) return value;
        let rows = [];
        for (let i = 0; i < value.count; ++i) rows.push(value.get(i));
        return rows;
    }
    function open() { visible = true; query = ""; selectedIndex = 0; actionsOpen = false; input.forceActiveFocus(); }
    function close() { actionsOpen = false; visible = false; closed(); }
    function move(delta) {
        const count = actionsOpen ? selectedActions.length : list.count;
        if (!count) return;
        if (actionsOpen) actionIndex = (actionIndex + delta + count) % count;
        else selectedIndex = (Math.max(0, selectedIndex) + delta + count) % count;
    }
    function openActions() {
        if (selectedActions.length) { actionsOpen = !actionsOpen; actionIndex = 0; input.forceActiveFocus(); }
    }
    function run() {
        if (selectedIndex < 0 || selectedIndex >= list.count) return;
        const idx = resultsModel.index(selectedIndex, 0);
        const done = actionsOpen ? resultsModel.runAction(idx, actionIndex) : resultsModel.run(idx);
        if (done) close();
        else input.forceActiveFocus();
    }
    onQueryChanged: { selectedIndex = 0; actionsOpen = false; }
    Glass { anchors.fill: parent; backdrop: launcher.backdrop }
    Icon { x: 24; y: 25; width: 24; height: 24; font.pixelSize: 24; name: "magnifying-glass" }
    TextInput {
        id: input; objectName: "launcherInput"
        x: 62; y: 18; width: parent.width-124; height: 40
        color: Theme.text; selectionColor: Theme.selection; selectedTextColor: Theme.text
        font.family: Theme.family; font.pixelSize: 21; clip: true; focus: true
        verticalAlignment: TextInput.AlignVCenter
        Accessible.name: "Buscar aplicaciones, archivos y comandos"
        Keys.onUpPressed: launcher.move(-1)
        Keys.onDownPressed: launcher.move(1)
        Keys.onReturnPressed: launcher.run()
        Keys.onEnterPressed: launcher.run()
        Keys.onEscapePressed: { if (launcher.actionsOpen) launcher.actionsOpen = false; else launcher.close(); }
        Keys.onPressed: event => {
            if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_K) { launcher.openActions(); event.accepted = true; }
        }
        UiText { anchors.fill: parent; text: "Buscar aplicaciones, archivos, comandos…"; font.pixelSize: 21; color: Theme.faint; visible: !input.text }
    }
    ShortcutHint { x: parent.width-47; y: 27; text: "esc" }
    Rectangle { y: 76; width: parent.width; height: 1; color: Theme.border }
    ListView {
        id: list; x: 10; y: 88; width: parent.width-20; height: parent.height-146
        model: launcher.resultsModel; clip: true; currentIndex: 0
        highlightMoveDuration: 0; boundsBehavior: Flickable.StopAtBounds
        onCountChanged: { if (count && currentIndex < 0) currentIndex = 0; }
        onCurrentIndexChanged: { launcher.actionsOpen = false; positionViewAtIndex(currentIndex, ListView.Contain); }
        delegate: ListItem {
            id: result
            required property var model
            required property int index
            resultActions: launcher.actionArray(model.actions)
            width: ListView.view.width
            title: String(model.display || "")
            subtitle: String(model.subtext || "")
            iconSource: model.decoration
            selected: launcher.selectedIndex === index
            onClicked: { launcher.selectedIndex = index; launcher.run(); }
        }
        UiText {
            anchors.centerIn: parent; visible: list.count === 0
            text: !launcher.query ? "Aplicaciones, archivos y acciones de KRunner" : (launcher.resultsModel && launcher.resultsModel.querying) ? "Buscando…" : "Sin resultados"
            color: Theme.muted
        }
    }
    Rectangle { y: parent.height-42; width: parent.width; height: 1; color: Theme.border }
    UiText { x: 24; y: parent.height-30; text: "Singlr"; height: 16; font.pixelSize: 11; color: Theme.faint }
    Row { anchors.right: parent.right; anchors.rightMargin: 16; y: parent.height-35; spacing: 12
        Tool { icon: "key-return"; label: "Abrir"; onClicked: launcher.run() }
        Tool { visible: launcher.selectedActions.length > 0; icon: "command"; label: "Acciones  Ctrl K"; onClicked: launcher.openActions() }
    }
    Rectangle {
        visible: launcher.actionsOpen; x: parent.width-width-14; y: parent.height-height-54
        width: 300; height: Math.min(320, actionList.contentHeight+16); radius: 8
        color: Theme.raised; border.color: Theme.focusBorder
        ListView {
            id: actionList; anchors.fill: parent; anchors.margins: 8; clip: true
            model: launcher.selectedActions; currentIndex: launcher.actionIndex
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            delegate: ListItem {
                required property var modelData
                required property int index
                width: ListView.view.width; title: String(modelData.text || "").replace(/&/g, "")
                iconSource: modelData.iconSource || ""; selected: index === launcher.actionIndex
                onClicked: { launcher.actionIndex = index; launcher.run(); }
            }
        }
    }
}
