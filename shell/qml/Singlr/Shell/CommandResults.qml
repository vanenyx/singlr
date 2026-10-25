pragma ComponentBehavior: Bound
import QtQuick
import QtQml.Models
import Singlr.Command

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
        const seen = new Set();
        function collect(objects, sourceKind) {
            for (let i = 0; i < objects.count; ++i) {
                const object = objects.objectAt(i);
                if (!object) continue;
                const row = object.row;
                const runnerId = String(row.runnerId || "");
                // Plasma 6.8 installed C++ plugins use the krunner_ prefix;
                // DBus plugins and calculator/unitconverter do not.
                const runner = runnerId.replace(/^krunner_/, "");
                // singleRunner may fall back to general results (e.g. unavailable
                // plugin). Never infer origin from the model or translated text.
                if (sourceKind === "settings" && runner !== "systemsettings") continue;
                const id = String(row.id || "");
                const urls = copyUrls(row.urls);
                const identity = id || (urls.length ? runner + ":" + urls.join("\n") : "");
                if (identity && seen.has(identity)) continue;
                if (identity) seen.add(identity);
                const store = ["appstream", "Discover", "discover"].includes(runner);
                const category = runner === "systemsettings" ? "Configuración"
                    : store ? "Instalar aplicaciones" : String(row.category || "Resultados");
                const priority = store ? 3 : ["calculator", "unitconverter"].includes(runner) ? 0
                    : ["services", "systemsettings"].includes(runner) ? 1 : 2;
                rows.push({display:String(row.display || ""), subtext:String(row.subtext || ""),
                    decoration:row.decoration || "", id:id, runnerId:runnerId, category:category,
                    relevance:Number(row.relevance || 0), categoryRelevance:Number(row.categoryRelevance || 0),
                    priority:priority, actions:copyActions(row.actions), urls:urls, sourceRow:object.sourceRow,
                    sourceKind:sourceKind, page:""});
            }
        }
        collect(generalRows, "general");
        collect(settingsRows, "settings");
        const q = normalized(queryString);
        const pages = bridge ? bridge.commandSettingsPages() : [];
        if (q) for (const page of pages) {
            if (!normalized(page.label + " " + page.keywords + " ajustes settings configuracion singlr").includes(q)) continue;
            rows.push({display:page.label, subtext:"Singlr", decoration:"", id:"singlr-settings-" + page.page,
                runnerId:"singlr", category:"Configuración", relevance:normalized(page.label) === q ? 1 : 0.6,
                categoryRelevance:70, priority:1, actions:[], urls:[], sourceRow:-1, sourceKind:"singlr", page:page.page});
        }
        // Keep sections contiguous, ranked by their best match rather than their
        // translated names. Installed apps/settings always precede install offers.
        const groups = new Map();
        for (const row of rows) {
            const group = groups.get(row.category) || {priority:row.priority, relevance:0, categoryRelevance:0};
            group.priority = Math.min(group.priority, row.priority);
            group.relevance = Math.max(group.relevance, row.relevance);
            group.categoryRelevance = Math.max(group.categoryRelevance, row.categoryRelevance);
            groups.set(row.category, group);
        }
        rows.sort((a, b) => {
            const ga = groups.get(a.category), gb = groups.get(b.category);
            if (a.category !== b.category) return ga.priority - gb.priority || gb.relevance - ga.relevance
                || gb.categoryRelevance - ga.categoryRelevance || a.category.localeCompare(b.category);
            return b.relevance - a.relevance || b.categoryRelevance - a.categoryRelevance
                || a.id.localeCompare(b.id);
        });
        merged.clear();
        let installCount = 0;
        for (const row of rows) {
            if (row.priority === 3 && ++installCount > 3) continue;
            merged.append(row);
        }
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
            CommandSourceModel {
                queryString: root.queryString; limit: 40; favoriteIds: ["calculator", "unitconverter"]
                onQueryStringChangeRequested: (query, pos) => root.queryStringChangeRequested(query, pos)
            }
        }
    }
    Loader {
        id: settingsLoader; active: !root.settingsModelOverride
        sourceComponent: Component { CommandSourceModel { singleRunner: "krunner_systemsettings"; queryString: root.settingsQuery(root.queryString); limit: 20 } }
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
            property var observed: [model.display, model.subtext, model.actions, model.decoration, model.category, model.urls, model.id, model.runnerId, model.relevance, model.categoryRelevance]
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
            property var observed: [model.display, model.subtext, model.actions, model.decoration, model.urls, model.id, model.runnerId, model.relevance, model.categoryRelevance]
            onObservedChanged: root.schedule()
            onSourceRowChanged: root.schedule()
        }
    }
}
