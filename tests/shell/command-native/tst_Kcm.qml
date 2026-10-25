import QtQuick
import QtTest
import Singlr.Shell
Item {
    width: 900; height: 650
    ListModel { id: noGeneral }
    CommandResults { id: results; generalModelOverride: noGeneral }
    TestCase {
        name: "InstalledKcmRunner"; when: windowShown
        function test_realInstalledModules_data() { return [
            {tag:"bluetooth", query:"bluetooth"}, {tag:"wifi", query:"wifi"},
            {tag:"pantalla", query:"pantalla"}, {tag:"sonido", query:"sonido"}, {tag:"teclado", query:"teclado"}]; }
        function test_realInstalledModules(data) {
            results.queryString = data.query;
            tryVerify(() => results.model.count > 0 && !results.querying, 5000);
            for (let i = 0; i < results.model.count; ++i) {
                const row = results.model.get(i);
                compare(row.category, "Configuración");
                console.log(data.query, row.id, row.display);
            }
        }
    }
}
