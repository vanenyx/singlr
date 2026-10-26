import QtQuick
import QtQuick.Window
import QtCore
Window {
    id: target
    visible: true; width: 600; height: 340; title: "Singlr clipboard test target"
    property bool terminal: Qt.application.arguments.indexOf("--terminal") >= 0
    property bool imageCase: Qt.application.arguments.indexOf("--image") >= 0
    property bool seeded: false
    Settings {
        id: state
        location: StandardPaths.writableLocation(StandardPaths.GenericStateLocation) + (Qt.application.arguments.indexOf("--other") >= 0 ? "/clipboard-target-other.ini" : "/clipboard-target.ini")
        property bool ready: false
        property bool active: target.active
        property string content: field.text
        property bool terminalChord: false
    }
    TextEdit {
        id: field; anchors.fill: parent; focus: true
        onTextChanged: { state.content = text; state.sync(); }
        Keys.onPressed: event => {
            if (!target.terminal && event.key === Qt.Key_V && (event.modifiers & Qt.ControlModifier)) pasteProbe.inspectPaste();
            if (target.terminal && event.key === Qt.Key_V) {
                if ((event.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)) === (Qt.ControlModifier | Qt.ShiftModifier)) {
                    state.terminalChord = true; paste();
                }
                event.accepted = true;
            }
        }
    }
    onActiveChanged: {
        state.active = active; state.sync();
        if (active && !seeded) { seeded = true; first.restart(); }
    }
    Timer {
        id: first; interval: 150
        onTriggered: {
            if (target.imageCase) pasteProbe.seedImage();
            else { field.text = "SINGLR_T258_OLD á\nsegunda línea"; field.selectAll(); field.copy(); field.text = ""; }
            second.restart();
        }
    }
    Timer {
        id: second; interval: 350
        onTriggered: { field.text = "SINGLR_T258_NEW"; field.selectAll(); field.copy(); field.text = ""; state.ready = true; state.sync(); }
    }
    Component.onCompleted: requestActivate()
}
