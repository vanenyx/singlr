import QtQuick
import QtTest
import Singlr.Shell
Item {
    width: 800; height: 600
    ApplicationsModel { id: catalogue }
    ListView { id: apps; width: 800; height: 600; model: catalogue; delegate: Text { required property string display; text: display } }
    Launcher { id: launcher; visible: false }
    TestCase {
        name: "InstalledApplications"; when: windowShown
        function test_nativeLauncher() {
            launcher.open(true);
            tryVerify(() => launcher.resultCount > 0);
            launcher.query = "singlr-no-such-installed-application-203";
            tryCompare(launcher, "resultCount", 0);
            keyClick(Qt.Key_Return); verify(launcher.visible);
            keyClick(Qt.Key_Escape); verify(!launcher.visible);
        }
        function test_nativeCatalogueAndFilter() {
            tryVerify(() => apps.count > 0);
            const total = apps.count;
            const firstName = catalogue.catalogue.labelForRow(0);
            catalogue.query = firstName.toLowerCase();
            tryVerify(() => apps.count > 0);
            catalogue.launchIndex = catalogue.mapToSource(catalogue.index(0, 0));
            compare(catalogue.catalogue.labelForRow(catalogue.launchIndex.row), firstName);
            catalogue.query = "singlr-no-such-installed-application-203";
            tryCompare(apps, "count", 0);
            catalogue.query = "";
            tryCompare(apps, "count", total);
            catalogue.root.refresh();
            tryCompare(apps, "count", total);
        }
    }
}
