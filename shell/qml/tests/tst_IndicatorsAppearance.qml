pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Singlr.Ui
import Singlr.Shell
import "../../../session/shell-package/org.singlr.desktop/contents/lockscreen" as Lock

Item {
    id: fixture
    width: 900; height: 800
    QtObject {
        id: keyboard
        property int layout: 0
        property var layoutsList: []
        function switchToNextLayout() { layout = (layout + 1) % layoutsList.length; }
    }
    QtObject {
        id: night
        property bool configured: true
        property bool inhibited: false
        property bool togglable: true
        property string status: "Activa"
        function toggle() { inhibited = !inhibited; }
    }
    QtObject { id: notices; property bool inhibited: false }
    SystemControls { id: audio; sink: null; source: null }
    Component { id: keyboardFactory; KeyboardIndicator { backend: keyboard } }
    Component { id: nightFactory; NightLightRow { backend: night } }
    Component { id: centerFactory; ControlCenter { audio: audio; notifications: notices; nightLightBackend: night; networkSource: null } }
    TestCase {
        name: "IndicatorsAppearance"; when: windowShown
        function layouts() { return [{shortName: "us", longName: "English (US)"}, {shortName: "es", longName: "Español"}]; }
        function init() { keyboard.layout = 0; keyboard.layoutsList = layouts(); night.inhibited = false; night.togglable = true; }
        function test_keyboardVisibilityCycleAndMenu() {
            const indicator = createTemporaryObject(keyboardFactory, fixture);
            verify(indicator.visible);
            const button = findChild(indicator, "keyboardLayoutButton");
            mouseClick(button); compare(keyboard.layout, 1);
            const width = indicator.width;
            keyboard.layoutsList = [{shortName: "verylong", longName: "Long label"}, layouts()[1]];
            compare(indicator.width, width);
            button.forceActiveFocus(); keyClick(Qt.Key_Space); compare(keyboard.layout, 0);
            mouseClick(button, 10, 10, Qt.RightButton); verify(indicator.opened);
            tryVerify(() => indicator.popup && indicator.popup.opened);
            const height = indicator.menuHeight;
            keyboard.layoutsList = layouts().concat(layouts());
            compare(indicator.entries.length, 2); compare(indicator.menuHeight, height);
            keyClick(Qt.Key_Down); keyClick(Qt.Key_Return); compare(keyboard.layout, 1);
            verify(!indicator.opened);
            keyboard.layoutsList = [layouts()[0]]; verify(!indicator.visible);
            keyboard.layoutsList = []; verify(!indicator.visible);
        }
        function test_nightLightKWinProperties() {
            try {
                NightLight.state = {available: true, enabled: true, running: true,
                    inhibited: false, currentTemperature: 4500, targetTemperature: 4500};
                verify(NightLight.available); verify(NightLight.configured); verify(NightLight.indicatorVisible);
                compare(NightLight.status, "Activa"); verify(NightLight.togglable);
                NightLight.state = Object.assign({}, NightLight.state, {running: false, inhibited: true, currentTemperature: 6500});
                compare(NightLight.status, "Suspendida"); verify(NightLight.indicatorVisible);
                verify(!NightLight.togglable); // Another client's inhibition is never released.
                NightLight.state = Object.assign({}, NightLight.state, {inhibited: false, targetTemperature: 6500});
                compare(NightLight.status, "Programada"); verify(!NightLight.indicatorVisible);
                NightLight.state = Object.assign({}, NightLight.state, {enabled: false});
                compare(NightLight.status, "Sin configurar"); verify(!NightLight.togglable);
                NightLight.state = {available: false}; compare(NightLight.status, "No disponible");
            } finally { NightLight.state = Qt.binding(() => NightLight.properties); }
        }
        function test_nightLightOwnerAndGeometry() {
            const row = createTemporaryObject(nightFactory, fixture);
            const toggle = findChild(row, "nightLightToggle");
            verify(toggle.checked); toggle.forceActiveFocus(); keyClick(Qt.Key_Space); verify(night.inhibited);
            night.status = "Suspendida por otra aplicación"; night.togglable = false;
            verify(!toggle.enabled); compare(row.height, 36); compare(row.width, 308);
            mouseClick(toggle); verify(night.inhibited);
        }
        function test_displayRowReservesSpace() {
            const panel = createTemporaryObject(centerFactory, fixture, {outputCount: 1});
            const row = findChild(panel, "displayLayoutRow"); verify(row); verify(!row.visible);
            const height = panel.height; const y = row.parent.y;
            panel.outputCount = 2; verify(row.visible); compare(row.height, 36);
            panel.outputCount = 0; verify(!row.visible); compare(panel.height, height); compare(row.parent.y, y);
        }
        function luminance(c) {
            function channel(v) { return v <= .04045 ? v / 12.92 : Math.pow((v + .055) / 1.055, 2.4); }
            return .2126 * channel(c.r) + .7152 * channel(c.g) + .0722 * channel(c.b);
        }
        function blend(c, bg) { return Qt.rgba(c.r*c.a+bg.r*(1-c.a), c.g*c.a+bg.g*(1-c.a), c.b*c.a+bg.b*(1-c.a), 1); }
        function contrast(a, b) { const x = luminance(a), y = luminance(b); return (Math.max(x,y)+.05)/(Math.min(x,y)+.05); }
        function test_textContrastAA() {
            const surfaces = [Theme.background, Theme.panel, Theme.raised, Theme.hover,
                blend(Theme.selection, Theme.raised),
                blend(Qt.rgba(Theme.raised.r, Theme.raised.g, Theme.raised.b, Theme.dark ? .90 : .92), Qt.color("black")),
                blend(Qt.rgba(Theme.raised.r, Theme.raised.g, Theme.raised.b, Theme.dark ? .90 : .92), Qt.color("white")), blend(Theme.surface, Qt.color("black")),
                blend(Theme.surface, Qt.color("white")), blend(Theme.barSurface, Qt.color("black")),
                blend(Theme.barSurface, Qt.color("white")), blend(Theme.dockSurface, Qt.color("black")),
                blend(Theme.dockSurface, Qt.color("white"))];
            for (const ink of [Theme.text, Theme.secondary, Theme.muted, Theme.faint])
                for (const surface of surfaces) verify(contrast(ink, surface) >= 4.5, String(ink)+" / "+String(surface)+" = "+contrast(ink,surface));
            compare(Lock.Appearance.dark, Theme.dark);
            compare(Lock.Theme.dark, Theme.dark);
            for (const backdrop of [Qt.color("black"), Qt.color("white")]) {
                const lockBackground = blend(Qt.rgba(Lock.Theme.background.r, Lock.Theme.background.g, Lock.Theme.background.b, .82), backdrop);
                verify(contrast(Lock.Theme.text, lockBackground) >= 4.5);
                verify(contrast(Lock.Theme.error, lockBackground) >= 4.5);
            }
        }
    }
}
