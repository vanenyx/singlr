import QtQuick
import QtQuick.Controls
import QtTest
import "@LOCKSCREEN@" as Lock

// Boundary double, never a PAM service. The real greeter load is checked separately.
TestCase {
    id: root
    name: "LockscreenPassword"
    width: 1280
    height: 900
    when: windowShown
    function i18ndc(domain, context, text) { return text; }
    signal clearPassword()
    signal notificationRepeated()
    property QtObject authenticator: QtObject {
        property int authenticatorTypes: 0
        property bool inPasswordDelay: false
        signal noninteractiveError(int kind, var authenticator)
    }
    Lock.MainBlock {
        id: block
        anchors.fill: parent
        lockScreenUiVisible: true
        authenticationBlocked: root.authenticator.inPasswordDelay
        userListModel: ListModel {}
    }
    SignalSpy { id: submitted; target: block; signalName: "passwordResult" }
    function init() {
        root.authenticator.inPasswordDelay = false;
        root.clearPassword();
        submitted.clear();
    }
    function test_empty_response() {
        block.startLogin();
        compare(submitted.count, 1);
        compare(submitted.signalArguments[0][0], "");
    }
    function test_delay_blocks_and_allows_retry() {
        root.authenticator.inPasswordDelay = true;
        block.startLogin();
        compare(submitted.count, 0);
        root.authenticator.inPasswordDelay = false;
        block.startLogin();
        compare(submitted.count, 1);
    }
    function test_masking_clear_and_keyboard_submit() {
        block.mainPasswordBox.text = "synthetic-test-value";
        compare(block.mainPasswordBox.showPassword, false);
        root.clearPassword();
        compare(block.mainPasswordBox.text, "");
        block.mainPasswordBox.forceActiveFocus();
        keyClick(Qt.Key_Return);
        compare(submitted.count, 1);
        compare(submitted.signalArguments[0][0], "");
    }
}
