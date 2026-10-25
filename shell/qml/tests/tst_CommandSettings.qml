import QtQuick
import QtTest
import Singlr.Shell
Item {
    width: 900; height: 650
    QtObject {
        id: bridge
        property string opened: ""
        function commandSettingsPages() { return [
            {label:"Apariencia", page:"appearance", keywords:"oscuro dark claro light appearance"},
            {label:"Fondo", page:"wallpaper", keywords:"fondo wallpaper background"},
            {label:"Material", page:"material", keywords:"material glass vidrio"}]; }
        function openCommandSettings(page) { opened = page; return true; }
    }
    ListModel {
        id: general
        property int lastRow: -1
        function index(row, column) { return row; }
        function run(row) { lastRow = row; return true; }
        function runAction(row, action) { return true; }
    }
    ListModel {
        id: kcms
        property int lastRow: -1
        function index(row, column) { return row; }
        function run(row) { lastRow = row; return true; }
        function runAction(row, action) { return true; }
    }
    CommandResults { id: results; bridge: bridge; generalModelOverride: general; settingsModelOverride: kcms }
    TestCase {
        name: "CommandSettings"; when: windowShown
        function cleanup() { general.lastRow = -1; kcms.lastRow = -1; results.queryString = ""; bridge.opened = ""; general.clear(); kcms.clear(); }
        function findPage(page) {
            for (let i = 0; i < results.model.count; ++i) if (results.model.get(i).page === page) return i;
            return -1;
        }
        function test_pages_data() { return [
            {tag:"es", query:"oscuro", page:"appearance"}, {tag:"en", query:"dark", page:"appearance"},
            {tag:"fondo", query:"wallpaper", page:"wallpaper"}, {tag:"material", query:"glass", page:"material"}]; }
        function test_pages(data) {
            results.queryString = data.query;
            tryVerify(() => findPage(data.page) >= 0);
            const row = findPage(data.page);
            compare(results.model.get(row).category, "Configuración");
            verify(results.run(results.index(row, 0)));
            compare(bridge.opened, data.page);
        }
        function test_unknownHasNoInventedPages() {
            results.queryString = "t250-no-such-setting-unknown";
            wait(100);
            compare(findPage("appearance"), -1); compare(findPage("wallpaper"), -1); compare(findPage("material"), -1);
        }
        function loadFixture() {
            const request = new XMLHttpRequest();
            request.open("GET", Qt.resolvedUrl("../../../tests/shell/fixtures/command-contract.json"), false);
            request.send();
            return JSON.parse(request.responseText);
        }
        function test_runnerContracts_data() {
            return loadFixture().queries.map(q => ({tag:q.query, fixture:q}));
        }
        function test_runnerContracts(data) {
            const fixture = data.fixture;
            results.queryString = fixture.query;
            for (const row of fixture.general) general.append(row);
            for (const row of fixture.settings) kcms.append(row);
            tryVerify(() => results.model.count > 0);
            wait(30);
            const seen = new Set();
            let storeSeen = false;
            let storeCount = 0;
            for (let i = 0; i < results.model.count; ++i) {
                const row = results.model.get(i);
                verify(!seen.has(row.id), "Duplicate " + row.id); seen.add(row.id);
                verify(row.category !== "Preferencias del sistema");
                if (row.runnerId === "krunner_appstream") {
                    compare(row.category, "Instalar aplicaciones");
                    storeSeen = true; ++storeCount;
                } else verify(!storeSeen, "Installed/local result after store suggestion");
                if (row.runnerId === "krunner_systemsettings") compare(row.category, "Configuración");
            }
            verify(storeCount <= 3);
            if (fixture.query === "bluetooth") {
                compare(results.model.get(0).display, "Bluetooth");
                verify(results.run(0)); compare(general.lastRow, 3);
            } else if (fixture.query === "firefox") compare(results.model.get(0).display, "Firefox");
            else if (fixture.query === "2+2") compare(results.model.get(0).display, "4");
            else if (fixture.query === "fondo") verify(findPage("wallpaper") >= 0);
        }
        function test_originNotTextAndCap() {
            results.queryString = "bluetooth";
            // A translated or misleading label cannot change the runner's origin.
            for (let i = 0; i < 6; ++i) general.append({display:"Bluetooth Configuración", subtext:"",
                id:"krunner_appstream_" + i, runnerId:"krunner_appstream", category:"Preferencias del sistema",
                relevance:1 - i / 10, categoryRelevance:100, decoration:"", actions:[], urls:[]});
            kcms.append({display:"Bluetooth", subtext:"", id:"kcm_bluetooth", runnerId:"krunner_systemsettings",
                category:"Another locale", relevance:0.8, categoryRelevance:70, decoration:"", actions:[], urls:[]});
            tryCompare(results.model, "count", 4);
            compare(results.model.get(0).category, "Configuración");
            compare(results.model.get(1).id, "krunner_appstream_0");
            compare(results.model.get(3).id, "krunner_appstream_2");
            verify(results.run(0)); compare(kcms.lastRow, 0);
            verify(results.run(1)); compare(general.lastRow, 0);
        }
        function test_mergeDispatchAndNoDuplicateKcm() {
            const fixture = loadFixture().queries[0];
            const row = fixture.general[3];
            general.append(row); kcms.append(row);
            results.queryString = "bluetooth";
            tryCompare(results.model, "count", 1);
            compare(results.model.get(0).category, "Configuración");
            verify(results.run(0)); compare(general.lastRow, 0);
            general.clear(); tryVerify(() => results.model.count === 1 && results.model.get(0).sourceKind === "settings");
            verify(results.run(0)); compare(kcms.lastRow, 0);
            kcms.insert(0, fixture.general[4]); tryCompare(results.model, "count", 2);
            verify(results.run(0)); compare(kcms.lastRow, 1);
            kcms.remove(0); tryCompare(results.model, "count", 1);
            verify(results.run(0)); compare(kcms.lastRow, 0);
            // Late relevance changes must reorder existing results, too.
            kcms.append(fixture.general[4]); tryCompare(results.model, "count", 2);
            kcms.setProperty(0, "relevance", 0.2);
            kcms.setProperty(1, "relevance", 0.9);
            tryCompare(results.model, "count", 2);
            tryVerify(() => results.model.get(0).id === fixture.general[4].id);
            verify(results.run(0)); compare(kcms.lastRow, 1);
        }
        function test_synonyms() {
            compare(results.settingsQuery("wifi"), "network"); compare(results.settingsQuery("pantalla"), "display");
            compare(results.settingsQuery("sonido"), "audio"); compare(results.settingsQuery("teclado"), "keyboard");
            compare(results.settingsQuery("Bluetooth"), "Bluetooth");
        }
    }
}
