import QtQuick
import QtTest
import ".." as Desktop
TestCase {
    id: test
    name:"DesktopInteraction"
    when:windowShown
    Desktop.Main { id: shell }
    function initTestCase() { failOnWarning(/.*/); }
    function init() {
        shell.requestActivate();
        tryCompare(shell,"active",true);
        shell.launcher.query="";
        shell.setState("desktop");
        Desktop.Theme.dark=true;
    }
    function type(text) { for(var c of text) keyClick(c); }
    function search() {
        keyClick(Qt.Key_2);
        tryCompare(shell,"desktopState","search");
        verify(shell.launcher.activeFocus);
    }
    function test_filterAndLaunch() {
        search();type("term");
        compare(shell.launcher.query,"term");
        compare(shell.launcher.results.length,1);
        compare(shell.launcher.selected.title,"Terminal");
        keyClick(Qt.Key_Return);
        compare(shell.desktopState,"desktop");
        compare(shell.activeApp,"terminal");
    }
    function test_arrowsAndActions() {
        search();
        keyClick(Qt.Key_Down);compare(shell.launcher.selectedIndex,1);
        keyClick(Qt.Key_Up);compare(shell.launcher.selectedIndex,0);
        keyClick(Qt.Key_Up);compare(shell.launcher.selectedIndex,6);
        keyClick(Qt.Key_Down);compare(shell.launcher.selectedIndex,0);
        keyClick(Qt.Key_K,Qt.ControlModifier);compare(shell.launcher.actionsOpen,true);
        keyClick(Qt.Key_Down);compare(shell.launcher.actionIndex,1);
        keyClick(Qt.Key_Escape);compare(shell.launcher.actionsOpen,false);
        compare(shell.desktopState,"search");
        keyClick(Qt.Key_Escape);compare(shell.desktopState,"desktop");
    }
    function test_emptyAndNumericalQuery() {
        search();type("12345L");
        compare(shell.launcher.query,"12345L");
        compare(shell.launcher.results.length,0);
        keyClick(Qt.Key_Down);keyClick(Qt.Key_Return);
        compare(shell.desktopState,"search");
        keyClick(Qt.Key_K,Qt.ControlModifier);compare(shell.launcher.actionsOpen,false);
        keyClick(Qt.Key_A,Qt.ControlModifier);keyClick(Qt.Key_Backspace);
        compare(shell.launcher.results.length,7);
    }
    function test_modesAndStateShortcuts() {
        keyClick(Qt.Key_3);compare(shell.desktopState,"actions");compare(shell.launcher.actionsOpen,true);
        keyClick(Qt.Key_Escape);keyClick(Qt.Key_Escape);
        keyClick(Qt.Key_4);compare(shell.desktopState,"multitask");
        keyClick(Qt.Key_5);compare(shell.desktopState,"controls");
        keyClick(Qt.Key_L);compare(Desktop.Theme.dark,false);
        keyClick(Qt.Key_1);compare(shell.desktopState,"desktop");
        keyClick(Qt.Key_Space,Qt.ControlModifier);compare(shell.desktopState,"search");
        keyClick(Qt.Key_Space,Qt.ControlModifier);compare(shell.desktopState,"desktop");
    }
    function test_commandsAndAccentIsolation() {
        search();type("molestar");compare(shell.launcher.results.length,1);
        var previous=shell.systemPanel.dnd;
        keyClick(Qt.Key_Return);compare(shell.desktopState,"controls");
        compare(shell.systemPanel.dnd,!previous);
        var surface=Desktop.Theme.content.toString();
        Desktop.Theme.accent="#dd7755";
        compare(Desktop.Theme.content.toString(),surface);
        Desktop.Theme.accent="#7170ff";
    }
}
