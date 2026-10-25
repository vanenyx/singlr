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
        function cleanup() { results.queryString = ""; bridge.opened = ""; general.clear(); kcms.clear(); }
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
        function test_mergeDispatchAndNoDuplicateKcm() {
            const row = {display:"Bluetooth", subtext:"Dispositivos", id:"systemsettings_kcm_bluetooth", decoration:"preferences-system-bluetooth", category:"System Settings", actions:[], urls:[]};
            general.append(row); kcms.append(row);
            results.queryString = "bluetooth";
            tryCompare(results.model, "count", 1);
            compare(results.model.get(0).category, "Configuración");
            verify(results.run(0)); compare(kcms.lastRow, 0); compare(general.lastRow, -1);
            // Source rows can move while runners complete; action dispatch follows current indices.
            kcms.insert(0, {display:"Audio", subtext:"", id:"systemsettings_kcm_pulseaudio", decoration:"", category:"Settings", actions:[], urls:[]});
            tryCompare(results.model, "count", 2);
            verify(results.run(1)); compare(kcms.lastRow, 1);
            kcms.remove(0); tryCompare(results.model, "count", 1);
            verify(results.run(0)); compare(kcms.lastRow, 0);
        }
        function test_synonyms() {
            compare(results.settingsQuery("wifi"), "network"); compare(results.settingsQuery("pantalla"), "display");
            compare(results.settingsQuery("sonido"), "audio"); compare(results.settingsQuery("teclado"), "keyboard");
            compare(results.settingsQuery("Bluetooth"), "Bluetooth");
        }
    }
}
