pragma ComponentBehavior: Bound
import QtQuick
import QtCore
import QtTest
import ".." as SettingsApp
import "../../../shell/qml/Singlr/Ui" as Ui
Item {
    id: fixture
    width: 880; height: 600
    Settings { id: external; location: Ui.Appearance.location; category: "Appearance" }
    Component { id: appFactory; SettingsApp.Main { helperBusy: true } }
    Ui.Wallpaper { id: background; width: 100; height: 60 }
    TestCase {
        name: "SettingsAppearance"; when: windowShown
        function cleanup() {
            Ui.Appearance.save("mode", "dark");
            Ui.Appearance.save("accent", "#5e6ad2");
            Ui.Appearance.save("wallpaper", "singlr:linear");
            Ui.Appearance.save("applyToApps", false);
            Ui.Theme.reloadSettings();
        }
        function test_externalReloadAndInvalidValues() {
            external.setValue("mode", "light"); external.setValue("accent", "#eb5ea9"); external.setValue("wallpaper", "singlr:graphite"); external.sync();
            Ui.Theme.reloadSettings();
            verify(!Ui.Theme.dark); compare(Ui.Theme.accent, Qt.color("#eb5ea9")); compare(background.source, "singlr:graphite");
            external.setValue("mode", "invalid"); external.setValue("accent", "invalid"); external.setValue("wallpaper", "https://example.com"); external.sync();
            Ui.Theme.reloadSettings();
            verify(Ui.Theme.dark); compare(Ui.Theme.accent, Qt.color("#5e6ad2")); compare(background.source, "singlr:linear");
        }
        function test_reloadHelperFailureIsVisible() {
            const app = createTemporaryObject(appFactory, null);
            verify(app);
            Ui.Appearance.save("applyToApps", false);
            app.helperBusy = false;
            app.save("mode", "dark");
            tryVerify(() => app.feedback.indexOf("Guardado.") === 0, 5000);
            verify(!app.helperBusy);
            app.close();
        }
        function test_autoBoundariesAndNeutralControl() {
            Ui.Appearance.save("mode", "auto"); Ui.Theme.reloadSettings();
            Ui.Theme.hour = 6; verify(Ui.Theme.dark);
            Ui.Theme.hour = 7; verify(!Ui.Theme.dark);
            compare(Ui.Theme.control, Ui.Theme.text); verify(Ui.Theme.control !== Ui.Theme.accent);
            Ui.Theme.hour = 18; verify(!Ui.Theme.dark);
            Ui.Theme.hour = 19; verify(Ui.Theme.dark);
        }
        function test_imageFailureFallback() {
            Ui.Appearance.save("wallpaper", "file:///tmp/singlr-t228-missing-image.png");
            tryCompare(background, "imageFailed", true);
            compare(background.color, Ui.Theme.wallpaperDefault);
        }
        function test_appControlsPersistAndPreview() {
            const app = createTemporaryObject(appFactory, null);
            verify(app); wait(80);
            mouseClick(findChild(app.contentItem, "mode-light")); compare(Ui.Appearance.mode, "light"); verify(!Ui.Theme.dark);
            mouseClick(findChild(app.contentItem, "accent-Rosa")); compare(Ui.Appearance.accent, "#eb5ea9");
            mouseClick(findChild(app.contentItem, "nav-wallpaper")); compare(app.page, "wallpaper");
            mouseClick(findChild(app.contentItem, "singlr:light")); compare(background.source, "singlr:light"); compare(background.color, Ui.Theme.wallpaperLight);
            external.sync(); compare(external.value("mode"), "light"); compare(external.value("wallpaper"), "singlr:light");
            compare(app.width, 880); compare(app.height, 600);
            app.close();
        }
    }
}
