import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtTest
import "@LOCKSCREEN@" as Lock

TestCase {
    id: testCase
    name: "LockscreenLayout"
    width: 1280
    height: 900
    when: windowShown
    Lock.SinglrSessionScreen {
        id: screen
        anchors.fill: parent
        // No real user image or authentication service in this geometry test.
        userListModel: ListModel {}
        TextField {
            id: input
            Layout.fillWidth: true
            implicitHeight: 44
        }
        Item { id: media; Layout.fillWidth: true; Layout.preferredHeight: 54 }
    }
    function test_error_and_media_keep_field_still() {
        wait(50);
        const before = input.mapToItem(screen, 0, 0);
        const width = input.width;
        screen.notificationMessage = "PAM error\n".repeat(40);
        media.visible = false;
        wait(50);
        const after = input.mapToItem(screen, 0, 0);
        compare(before.x, after.x);
        compare(before.y, after.y);
        compare(input.width, width);
        verify(input.width > 300);
        screen.notificationMessage = "";
    }
    function test_small_output_remains_scrollable() {
        testCase.width = 360;
        testCase.height = 480;
        wait(50);
        verify(input.width > 200 && input.width <= 328);
        const position = input.mapToItem(screen, 0, 0);
        verify(position.x >= 0 && position.x + input.width <= 360);
        testCase.width = 1280;
        testCase.height = 900;
    }
}
