pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Singlr.Ui
import "../Singlr/Ui/Theme.js" as Palette
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
        function luminance(c) {
            return .2126*Palette.linear(c.r)+.7152*Palette.linear(c.g)+.0722*Palette.linear(c.b);
        }
        function test_transparencyAndWorstBackdropAA() {
            // Exercise the real material curve independently of the software
            // renderer used by this suite (which must itself stay opaque).
            compare(Palette.materialOpacity(0), 1);
            verify(1-Palette.materialOpacity(.65) >= .25);
            fuzzyCompare(Palette.materialOpacity(1), .15, .001);
            for (let i = 0; i < 4; ++i)
                fuzzyCompare(Palette.materialOpacity(i/4)-Palette.materialOpacity((i+1)/4), .2125, .001);
            let minimum = 100;
            for (const dark of [false, true]) {
                const base = Qt.color(dark ? "#08090a" : "#f8f8f8");
                for (const strength of [0, .01, .25, .50, .65, .75, 1]) {
                    for (const level of [dark ? 2.1 : -1.5, dark ? 6.8 : -3.8]) {
                        const tint = Palette.level(base,level,1);
                        // Production shader's conservative neutral tint envelope.
                        verify(dark ? Math.max(tint.r,tint.g,tint.b) <= .14 : Math.min(tint.r,tint.g,tint.b) >= .90);
                        for (const conditioned of [false, true]) {
                        const a = Palette.materialOpacity(strength, conditioned);
                        for (const backdrop of [0,1]) {
                            // The shader guarantees final material Y <= .115
                            // in dark and >= .42 in light, including Qt's tint.
                            // Test inks directly against that envelope: no plate
                            // or glyph outline is assumed by the AA assertion.
                            const bg = Qt.rgba(a*tint.r+(1-a)*backdrop,a*tint.g+(1-a)*backdrop,a*tint.b+(1-a)*backdrop,1);
                            const backgroundY = conditioned && strength > 0 ? (dark ? .115 : .42) : luminance(bg);
                            for (const role of ["secondary","muted","faint"]) {
                                const fg = Palette.materialInk(base,dark,role,strength,1);
                                const x=luminance(fg), y=backgroundY;
                                const ratio=(Math.max(x,y)+.05)/(Math.min(x,y)+.05);
                                minimum=Math.min(minimum,ratio);
                                verify(ratio >= 4.5, `${dark}/${strength}/${role}: ${ratio}`);
                            }
                            if (strength > 0) {
                                const inks=[dark ? Qt.color("#f7f8f8") : Palette.ink(base,17,1)];
                                for (const accent of ["#5e6ad2","#ff0000","#00ff00","#0000ff","#ffff00","#eb5757"])
                                    inks.push(Palette.accentInk(Qt.color(accent),dark,1,strength));
                                for (const fg of inks) {
                                    const x=luminance(fg),y=backgroundY;
                                    const ratio=(Math.max(x,y)+.05)/(Math.min(x,y)+.05);
                                    minimum=Math.min(minimum,ratio);
                                    verify(ratio>=4.5, `primary/accent ${dark}/${strength}: ${ratio}`);
                                }
                            }
                        }
                        }
                    }
                }
            }
            console.info("Material SDR worst-backdrop AA minimum: " + minimum);
        }
    }
}
