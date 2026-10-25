pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import org.kde.kitemmodels as KItemModels
import org.kde.plasma.private.mpris as Mpris
import Singlr.Shell

Item {
    id: fixture
    width: 800; height: 700
    ListModel {
        id: clipboard
    }
    KItemModels.KSortFilterProxyModel {
        id: historyDouble
        sourceModel: clipboard
        property string copied: ""
        property string removed: ""
        property int clears: 0
        function moveToTop(uuid) { copied = uuid; }
        function remove(uuid) {
            removed = uuid;
            for (let i = 0; i < clipboard.count; ++i) if (clipboard.get(i).uuid === uuid) { clipboard.remove(i); return; }
        }
        function removeRows(first, count) {
            if (first !== 0 || count !== clipboard.count) return false;
            clears++; clipboard.clear(); return true;
        }
    }
    Component { id: clipboardFactory; ClipboardPanel { history: historyDouble } }
    property var player: ({
        track: "Tema", artist: "Artista", identity: "mpv", artUrl: "",
        playbackStatus: Mpris.PlaybackStatus.Playing,
        canControl: true, canGoPrevious: true, canGoNext: true, canPlay: true, canPause: true, lastAction: "",
        Previous: function() { fixture.player.lastAction = "previous"; },
        Next: function() { fixture.player.lastAction = "next"; },
        PlayPause: function() { fixture.player.lastAction = "toggle"; }
    })
    function refreshPlayer() { playerModel.currentPlayer = null; playerModel.currentPlayer = fixture.player; }
    ListModel {
        id: playerModel
        property var currentPlayer: fixture.player
        property int currentIndex: 0
    }
    Component { id: mediaFactory; NowPlaying { width: 308; height: 36; players: playerModel } }
    Component { id: sessionFactory; Session {} }
    TestCase {
        name: "ClipboardMedia"; when: windowShown
        SignalSpy { id: closed; signalName: "closed" }
        function init() {
            clipboard.clear(); historyDouble.copied = ""; historyDouble.clears = 0;
            clipboard.append({uuid: "a", display: "Alpha [test]", type: 2, starred: false, decoration: ""});
            clipboard.append({uuid: "b", display: "https://example.org", type: 8, starred: false, decoration: ""});
            clipboard.append({uuid: "c", display: "Imagen", type: 4, starred: true, decoration: ""});
            playerModel.clear(); playerModel.append({identity: "Automático", isMultiplexer: true}); playerModel.append({identity: "mpv", isMultiplexer: false});
            playerModel.currentPlayer = fixture.player; playerModel.currentIndex = 0;
            fixture.player.canControl = true; fixture.player.canGoNext = true; fixture.player.canPause = true; fixture.player.playbackStatus = Mpris.PlaybackStatus.Playing; fixture.player.lastAction = ""; fixture.player.track = "Tema";
        }
        function test_searchKeyboardCopyAndFixedSize() {
            const panel = createTemporaryObject(clipboardFactory, fixture);
            closed.target = panel; closed.clear(); panel.open();
            tryCompare(panel, "resultCount", 3);
            const input = findChild(panel, "clipboardSearch"); verify(input.activeFocus);
            keyClick(Qt.Key_Down); compare(panel.selectedIndex, 1);
            keyClick(Qt.Key_Up); compare(panel.selectedIndex, 0);
            panel.query = "[test]"; tryCompare(panel, "resultCount", 1);
            compare(panel.width, 760); compare(panel.height, 542);
            keyClick(Qt.Key_Return); compare(historyDouble.copied, "a"); compare(closed.count, 1);
            panel.query = "no match"; tryCompare(panel, "resultCount", 0);
            keyClick(Qt.Key_Return); compare(closed.count, 1);
            keyClick(Qt.Key_Escape); compare(closed.count, 2);
        }
        function test_imageAndUrlRepresentations() {
            const panel = createTemporaryObject(clipboardFactory, fixture); panel.open();
            panel.query = "Imagen"; tryCompare(panel, "resultCount", 1);
            tryVerify(() => panel.currentEntry !== null);
            compare(panel.currentEntry.type, 4);
            verify(findChild(panel.currentEntry, "clipboardThumbnail").visible);
            verify(!findChild(panel.currentEntry, "clipboardTypeIcon").visible);
            panel.query = "example"; tryCompare(panel, "resultCount", 1);
            tryVerify(() => panel.currentEntry !== null && panel.currentEntry.type === 8);
            compare(findChild(panel.currentEntry, "clipboardTypeIcon").name, "link");
            verify(!findChild(panel.currentEntry, "clipboardThumbnail").visible);
        }
        function test_contextPinAndClearConfirmation() {
            const panel = createTemporaryObject(clipboardFactory, fixture); panel.open();
            tryVerify(() => panel.currentEntry !== null);
            mouseClick(panel.currentEntry, 80, 20, Qt.RightButton);
            tryCompare(panel.menu, "opened", true);
            panel.menu.activate(0); compare(clipboard.get(0).starred, true);
            panel.openMenu(panel.currentEntry.model, panel, 100, 100);
            compare(panel.menu.entries[0].label, "Desfijar"); panel.menu.activate(0);
            compare(clipboard.get(0).starred, false);
            panel.openMenu(panel.currentEntry.model, panel, 100, 100);
            panel.menu.activate(2); compare(historyDouble.clears, 0); verify(panel.menu.opened);
            panel.menu.activate(2); compare(historyDouble.clears, 1); tryCompare(panel, "resultCount", 0);
            compare(panel.height, 542);
        }
        function test_removeFilteredUuidAndOverflow() {
            const panel = createTemporaryObject(clipboardFactory, fixture); panel.open();
            panel.query = "example"; tryCompare(panel, "resultCount", 1);
            tryVerify(() => panel.currentEntry !== null);
            const more = findChild(panel.currentEntry, "clipboardMore"); verify(more);
            mouseClick(more, 14, 14); tryCompare(panel.menu, "opened", true);
            panel.menu.activate(1); compare(historyDouble.removed, "b");
            compare(clipboard.count, 2); compare(clipboard.get(0).uuid, "a");
            tryCompare(panel, "resultCount", 0); compare(panel.height, 542);
        }
        function test_contextInvalidationAndFocus() {
            const panel = createTemporaryObject(clipboardFactory, fixture); panel.open();
            tryVerify(() => panel.currentEntry !== null);
            panel.openMenu(panel.currentEntry.model, panel, 100, 100);
            clipboard.remove(0); tryCompare(panel.menu, "opened", false);
            verify(findChild(panel, "clipboardSearch").activeFocus || panel.activeFocus);
        }
        function test_mediaControlsCapabilitiesAndMenu() {
            const row = createTemporaryObject(mediaFactory, fixture);
            verify(row.playing); row.perform("previous"); compare(fixture.player.lastAction, "previous");
            row.perform("toggle"); compare(fixture.player.lastAction, "toggle");
            fixture.player.canGoNext = false; fixture.refreshPlayer(); row.perform("next"); compare(fixture.player.lastAction, "toggle");
            verify(!findChild(row, "mediaNext").enabled);
            fixture.player.canPause = false; fixture.refreshPlayer(); verify(!row.canToggle);
            fixture.player.playbackStatus = Mpris.PlaybackStatus.Paused; fixture.refreshPlayer(); verify(row.canToggle);
            row.openMenu(row, 100, 20); compare(row.menu.entries.length, 2);
            row.menu.activate(1); compare(playerModel.currentIndex, 1);
            playerModel.currentPlayer = null; compare(row.height, 36); verify(!row.canToggle);
            playerModel.currentPlayer = fixture.player; compare(row.height, 36);
            row.openMenu(row, 100, 20); playerModel.remove(1); tryCompare(row.menu, "opened", false);
        }
        function test_mediaRowHiddenWhenPlayerHasNoMedia() {
            const row = createTemporaryObject(mediaFactory, fixture);
            verify(row.hasMedia);
            // Chrome keeps its MPRIS player after the tab with music is closed.
            fixture.player.track = ""; refreshPlayer();
            verify(!row.hasMedia);
            fixture.player.track = "Tema"; fixture.player.playbackStatus = Mpris.PlaybackStatus.Stopped; refreshPlayer();
            verify(!row.hasMedia);
            fixture.player.playbackStatus = Mpris.PlaybackStatus.Paused; refreshPlayer();
            verify(row.hasMedia);
            compare(row.implicitHeight, 36); // the slot never changes size (P-011)
        }
        function test_clipboardLifecycleAndExclusivity() {
            const session = createTemporaryObject(sessionFactory, fixture);
            const backend = findChild(session, "clipboardBackend"); verify(backend);
            const content = findChild(session, "clipboardLoader"); content.releaseDelay = 30;
            const surface = findChild(session, "clipboardSurface");
            verify(!content.active); verify(!surface.active);
            session.toggleClipboard(); verify(content.item); verify(surface.item);
            session.toggleClipboard(); verify(!surface.active);
            tryCompare(content, "active", false, 600); compare(content.item, null);
            compare(findChild(session, "clipboardBackend"), backend);
            session.toggleClipboard(); session.showApplications(); verify(!session.clipboardOpen);
            session.toggleClipboard(); verify(!session.launcherOpen);
            session.toggleControlCenter(); verify(!session.clipboardOpen);
        }
    }
}
