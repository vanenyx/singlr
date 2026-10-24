pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Singlr.Shell
Item {
    id: root
    width: 800; height: 700
    Component {
        id: fakeBackend
        Item {
            property var entries: []
            property bool inhibited: false
            property bool serverValid: true
            property string ownerName: "Test"
            property var calls: []
            function markRead() { calls.push("read"); }
            function setInhibited(value) { inhibited = value; }
            function dispatch(id, action) { calls.push([id, action]); }
        }
    }
    NotificationCenter { id: center; backendOverride: fakeBackend }
    property var testedCard: null
    SignalSpy { id: invoked; target: root.testedCard; signalName: "invoked" }
    SignalSpy { id: dismissed; target: root.testedCard; signalName: "dismissed" }
    Component { id: cardComponent; NotificationCard {} }
    TestCase {
        name: "Notifications"; when: windowShown
        function entry(id, timeout = -1, critical = false, app = "Singlr") {
            return {id:id, app:app, icon:"dialog-information", title:"Título", body:"Mensaje", time:new Date(2026,9,24,12,0,id), timeout:timeout, critical:critical, expired:false, dismissed:false, suppressed:false, defaultAction:true, actionNames:["open"], actionLabels:["Abrir"]};
        }
        function init() {
            center.historyOpen = false; center.popups = []; center.seen = ({}); center.hovered = ({});
            center.backendObject.entries = []; center.backendObject.calls = []; center.backendObject.inhibited = false; center.unread = false;
        }
        function test_defaultTimeoutAndHistory() {
            center.backendObject.entries = [entry(1)];
            compare(center.popups[0].remaining, 5000); verify(center.unread);
            center.toggle(); verify(!center.unread); compare(center.backendObject.calls[0], "read");
            center.clearAll(); compare(center.backendObject.calls[1][1], "close"); compare(center.popups.length, 0);
        }
        function test_timeoutAndHoverPause() {
            center.backendObject.entries = [entry(1, 300)];
            center.hovered[1] = true; wait(450); compare(center.popups.length, 1); compare(center.popups[0].remaining, 300);
            center.hovered[1] = false;
            tryCompare(center, "visiblePopupCount", 0, 1000);
            compare(center.backendObject.calls[0][1], "expire");
        }
        function test_criticalAndPersistent() {
            center.backendObject.entries = [entry(1, 100, true), entry(2, 0)];
            wait(350); compare(center.popups.length, 2);
            compare(center.popups[0].remaining, -1); compare(center.popups[1].remaining, -1);
        }
        function test_limitQueueAndReplacement() {
            center.backendObject.entries = [entry(1),entry(2),entry(3),entry(4)];
            compare(center.visiblePopupCount, 3); compare(center.popups.length, 4);
            center.dispatch(1, "close"); compare(center.visiblePopupCount, 3); compare(center.popups[0].entry.id, 2);
            const replacement = entry(2); replacement.time = new Date(2026,9,24,13); replacement.title = "Actualizada";
            center.backendObject.entries = [replacement,entry(3),entry(4)];
            compare(center.popups.length, 3); compare(center.popups[2].entry.title, "Actualizada");
        }
        function test_inhibitionAndGrouping() {
            center.setInhibited(true); verify(center.inhibited);
            center.backendObject.entries = [entry(1, 1000, false, "Zeta"),entry(2, 1000, true, "Alfa")];
            compare(center.popups.length, 1); compare(center.popups[0].entry.id, 2);
            compare(center.grouped[0].app, "Alfa"); compare(center.grouped[1].app, "Zeta");
            center.setInhibited(false); compare(center.popups.length, 1);
        }
        function test_removedAndExpiredDoNotReappear() {
            center.backendObject.entries = [entry(1)]; compare(center.popups.length, 1);
            const expired = entry(1); expired.expired = true;
            center.backendObject.entries = [expired]; compare(center.popups.length, 0); compare(center.entries.length, 1);
            center.backendObject.entries = []; compare(center.popups.length, 0);
        }
        function test_cardActions() {
            const card = createTemporaryObject(cardComponent, root, {entry:entry(1)});
            root.testedCard = card; invoked.clear(); dismissed.clear();
            mouseClick(card, 100, 52); compare(invoked.count, 1); compare(invoked.signalArguments[0][0], "default");
            mouseClick(card, 45, card.height - 26); compare(invoked.count, 2); compare(invoked.signalArguments[1][0], "open");
            mouseClick(card, 330, 22); compare(dismissed.count, 1); compare(invoked.count, 2);
            root.testedCard = null;
        }
    }
}
