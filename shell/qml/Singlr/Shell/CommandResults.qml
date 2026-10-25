pragma ComponentBehavior: Bound
import QtQuick
import QtQml.Models
import org.kde.milou as Milou

// Keep KRunner's real matches and dispatch; only Singlr's existing pages are local.
Item {
    id: root
    property string queryString: ""
    property var bridge: null
    property var generalModelOverride: null
    property var settingsModelOverride: null
    readonly property var general: generalModelOverride || generalLoader.item
    readonly property var settings: settingsModelOverride || settingsLoader.item
    readonly property bool querying: !!general?.querying || !!settings?.querying
    property alias model: merged
    signal queryStringChangeRequested(string queryString, int pos)
    function normalized(value) { return value.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").trim(); }
    function settingsQuery(value) {
        const q = normalized(value);
        const aliases = {wifi: "network", "wi-fi": "network", red: "network", redes: "network", internet: "network",
            pantalla: "display", monitor: "display", sonido: "audio", sound: "audio", volumen: "audio", volume: "audio",
            teclado: "keyboard", raton: "mouse", oscuro: "colors", dark: "colors", claro: "colors", light: "colors"};
        return aliases[q] || value;
    }
    function copyActions(value) {
        if (!value) return [];
        const count = value.length !== undefined ? value.length : value.count;
        const rows = [];
        for (let i = 0; i < count; ++i) {
            const action = value.length !== undefined ? value[i] : value.get(i);
            rows.push({text:String(action.text || ""), enabled:action.enabled !== false});
        }
        return rows;
    }
    function copyUrls(value) {
        if (!value || value.length === undefined) return [];
        return Array.from(value, url => String(url));
    }
    function schedule() { Qt.callLater(rebuild); }
    function rebuild() {
        const rows = [];
        function collect(objects, configuration) {
            for (let i = 0; i < objects.count; ++i) {
                const object = objects.objectAt(i);
                if (!object) continue;
                const row = object.row;
                // The dedicated standard runner owns all KCM results, once.
                if (!configuration && String(row.id || "").startsWith("systemsettings")) continue;
                rows.push({display:String(row.display || ""), subtext:String(row.subtext || ""),
                    decoration:row.decoration || "", id:String(row.id || ""),
                    category:configuration ? "Configuración" : String(row.category || ""),
                    actions:copyActions(row.actions), urls:copyUrls(row.urls), sourceRow:object.sourceRow,
                    sourceKind:configuration ? "settings" : "general", page:""});
            }
        }
        collect(generalRows, false);
        collect(settingsRows, true);
        const q = normalized(queryString);
        const pages = bridge ? bridge.commandSettingsPages() : [];
        if (q) for (const page of pages) {
            if (!normalized(page.label + " " + page.keywords + " ajustes settings configuracion singlr").includes(q)) continue;
            rows.push({display:page.label, subtext:"Singlr", decoration:"", id:"singlr-settings-" + page.page,
                category:"Configuración", actions:[], urls:[], sourceRow:-1, sourceKind:"singlr", page:page.page});
        }
        // Categories stay contiguous even as independent runners finish.
        rows.sort((a, b) => a.category.localeCompare(b.category));
        merged.clear();
        for (const row of rows) merged.append(row);
    }
    function index(row, column) { return row; }
    function run(row) {
        const item = merged.get(row);
        if (!item) return false;
        if (item.sourceKind === "singlr") return bridge.openCommandSettings(item.page);
        const source = item.sourceKind === "settings" ? settings : general;
        return source.run(source.index(item.sourceRow, 0));
    }
    function runAction(row, action) {
        const item = merged.get(row);
        if (!item || item.sourceKind === "singlr") return false;
        const source = item.sourceKind === "settings" ? settings : general;
        return source.runAction(source.index(item.sourceRow, 0), action);
    }
    onQueryStringChanged: schedule()
    onBridgeChanged: schedule()
    ListModel { id: merged; dynamicRoles: true }
    Loader {
        id: generalLoader; active: !root.generalModelOverride
        sourceComponent: Component {
            Milou.ResultsModel {
                queryString: root.queryString; limit: 40; favoriteIds: ["calculator", "unitconverter"]
                onQueryStringChangeRequested: (query, pos) => root.queryStringChangeRequested(query, pos)
            }
        }
    }
    Loader {
        id: settingsLoader; active: !root.settingsModelOverride
        sourceComponent: Component { Milou.ResultsModel { singleRunner: "systemsettings"; queryString: root.settingsQuery(root.queryString); limit: 20 } }
    }
    Instantiator {
        id: generalRows; model: root.general
        onObjectAdded: root.schedule()
        onObjectRemoved: root.schedule()
        delegate: QtObject {
            required property var model
            required property int index
            readonly property var row: model
            readonly property int sourceRow: index
            // Track data changes as well as insertion/removal.
            property var observed: [model.display, model.subtext, model.actions, model.decoration, model.category, model.urls, model.id]
            onObservedChanged: root.schedule()
            onSourceRowChanged: root.schedule()
        }
    }
    Instantiator {
        id: settingsRows; model: root.settings
        onObjectAdded: root.schedule()
        onObjectRemoved: root.schedule()
        delegate: QtObject {
            required property var model
            required property int index
            readonly property var row: model
            readonly property int sourceRow: index
            property var observed: [model.display, model.subtext, model.actions, model.decoration, model.urls, model.id]
            onObservedChanged: root.schedule()
            onSourceRowChanged: root.schedule()
        }
    }
}
