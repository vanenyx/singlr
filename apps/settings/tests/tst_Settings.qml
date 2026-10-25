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
    Settings { id: kde; location: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/kdeglobals"; category: "KDE" }
    Component { id: appFactory; SettingsApp.Main {} }
    Ui.Wallpaper { id: background; width: 100; height: 60 }
    TestCase {
        name: "SettingsAppearance"; when: windowShown
        function cleanup() {
            tryCompare(Ui.Appearance, "busy", false);
            Ui.Appearance.save("wallpaper", "singlr:linear");
            Ui.Theme.reloadSettings();
        }
        function test_dockControlsApplyAndPersist() {
            const app = createTemporaryObject(appFactory, fixture); verify(app);
            mouseClick(findChild(app.contentItem, "nav-dock")); compare(app.page, "dock");
            mouseClick(findChild(app.contentItem, "dock-mode-fixed")); compare(Ui.DockSettings.mode, "fixed");
            const slider = findChild(app.contentItem, "dockHeight");
            mouseClick(slider, slider.width - 8, slider.height / 2); compare(Ui.DockSettings.height, 72);
            mouseClick(slider, slider.width * 0.75, slider.height / 2); compare(Ui.DockSettings.height, 64);
            mouseClick(findChild(app.contentItem, "dockAutoHide")); verify(Ui.DockSettings.autoHide);
            const store = Qt.createQmlObject('import QtCore; Settings { category: "Dock" }', fixture);
            store.location = Ui.Appearance.location; store.sync();
            compare(store.value("mode"), "fixed"); compare(Number(store.value("height")), 64);
            compare(String(store.value("autoHide")), "true"); store.destroy();
            mouseClick(findChild(app.contentItem, "dock-mode-floating")); compare(Ui.DockSettings.mode, "floating");
            Ui.DockSettings.setHeight(48); Ui.DockSettings.setAutoHide(false); app.close();
        }
        function test_materialControlsKeepGeometry() {
            const app = createTemporaryObject(appFactory, fixture); verify(app);
            mouseClick(findChild(app.contentItem, "material-glass")); compare(Ui.Appearance.material, "glass");
            const slider = findChild(app.contentItem, "materialIntensity"); verify(slider.enabled);
            mouseClick(slider, slider.width * 0.8, slider.height / 2);
            tryVerify(() => Ui.Appearance.intensity > 65);
            mouseClick(findChild(app.contentItem, "reduceTransparency")); verify(Ui.Appearance.reduceTransparency);
            verify(!slider.enabled); compare(Ui.Appearance.effectiveMaterial, "solid");
            compare(app.width, 880); compare(app.height, 600);
            Ui.Appearance.save("reduceTransparency", false); Ui.Appearance.save("material", "glass");
            Ui.Appearance.save("intensity", 65); app.close();
        }
        function test_externalWallpaperAndLegacyPreferences() {
            const dark = Ui.Appearance.dark;
            const accent = Ui.Appearance.accent;
            external.setValue("mode", "invalid"); external.setValue("accent", "invalid");
            external.setValue("wallpaper", "singlr:graphite"); external.sync();
            Ui.Theme.reloadSettings();
            compare(Ui.Theme.dark, dark); compare(Ui.Theme.accent, Qt.color(accent));
            compare(background.source, "singlr:graphite");
            external.setValue("wallpaper", "https://example.com"); external.sync();
            Ui.Theme.reloadSettings(); compare(background.source, "singlr:linear");
        }
        function test_reloadFailureIsVisible() {
            const app = createTemporaryObject(appFactory, null); verify(app);
            app.save("wallpaper", "singlr:graphite");
            tryVerify(() => app.feedback.indexOf("Guardado.") === 0, 5000);
            app.close();
        }
        function test_autoUsesKDEAndEffectivePalette() {
            Ui.Appearance.save("mode", "auto");
            kde.sync(); compare(String(kde.value("AutomaticLookAndFeel")), "true");
            compare(Ui.Appearance.mode, "auto");
            compare(Ui.Theme.dark, Ui.Appearance.dark);
            compare(Ui.Theme.control, Ui.Theme.text);
            verify(Ui.Theme.control !== Ui.Theme.accent);
        }
        function test_imageFailureFallback() {
            Ui.Appearance.save("wallpaper", "file:///tmp/singlr-t228-missing-image.png");
            tryCompare(background, "imageFailed", true);
            compare(background.color, Ui.Theme.wallpaperDefault);
        }
        function test_appControlsWriteKDEAndPreview() {
            const app = createTemporaryObject(appFactory, null); verify(app); wait(80);
            mouseClick(findChild(app.contentItem, "mode-dark"));
            tryCompare(Ui.Appearance, "busy", false, 5000);
            kde.sync(); compare(String(kde.value("AutomaticLookAndFeel")), "false");
            mouseClick(findChild(app.contentItem, "accent-Rosa"));
            tryCompare(Ui.Appearance, "busy", false, 5000);
            compare(Ui.Appearance.selectedAccent, "#eb5ea9");
            mouseClick(findChild(app.contentItem, "nav-wallpaper")); compare(app.page, "wallpaper");
            mouseClick(findChild(app.contentItem, "singlr:light"));
            compare(background.source, "singlr:light"); compare(background.color, Ui.Theme.wallpaperLight);
            external.sync(); compare(external.value("wallpaper"), "singlr:light");
            compare(app.width, 880); compare(app.height, 600); app.close();
        }
    }
}
