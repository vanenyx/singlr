pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Singlr.Ui
Item {
    width: 500; height: 400
    Glass { id: surface; width: 200; height: 100; compositorBlur: true }
    TestCase {
        name: "Materials"; when: windowShown
        function cleanup() {
            Appearance.save("reduceTransparency", false);
            Appearance.save("material", "glass");
            Appearance.save("intensity", 65);
        }
        function test_preferencesAndSoftwareFallback() {
            Appearance.save("material", "liquid");
            Appearance.save("intensity", 77);
            compare(Appearance.material, "liquid"); compare(Appearance.intensity, 77);
            Appearance.reload(); compare(Appearance.material, "liquid");
            compare(Appearance.effectiveMaterial, "glass"); // private test bus has no KWin
            // All surfaces, including bar/dock/menu, become opaque with software rendering.
            compare(Theme.surface.a, 1); compare(Theme.dockSurface.a, 1); compare(Theme.barSurface.a, 1);
            verify(!surface.canBlur);
        }
        function test_zeroAndAccessibility() {
            Appearance.save("intensity", 0); compare(Appearance.effectiveMaterial, "solid");
            Appearance.save("intensity", 65); Appearance.save("reduceTransparency", true);
            compare(Appearance.effectiveMaterial, "solid"); verify(!surface.canBlur);
            Appearance.save("reduceTransparency", false); Appearance.save("material", "solid");
            compare(Appearance.effectiveMaterial, "solid");
            Appearance.save("material", "invalid"); compare(Appearance.material, "solid");
        }
    }
}
