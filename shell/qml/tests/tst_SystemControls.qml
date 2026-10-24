pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Singlr.Shell

Item {
    id: fixture
    readonly property var controls: audio
    readonly property var notificationState: notifications
    width: 400; height: 800
    QtObject {
        id: output
        property int volume: 32768
        property bool muted: false
        property bool volumeWritable: true
        property string description: "Salida de prueba"
    }
    QtObject {
        id: input
        property int volume: 32768
        property bool muted: false
        property bool volumeWritable: true
    }
    QtObject {
        id: mediaPlayer
        property var stub: ({
            canControl: true, canPlay: true, canPause: true, canStop: true,
            canGoNext: true, canGoPrevious: true, canSeek: true, playbackStatus: 0,
            volume: .5, lastAction: "", offset: 0,
            PlayPause: function() { mediaPlayer.stub.lastAction = "toggle"; },
            Play: function() { mediaPlayer.stub.lastAction = "play"; },
            Pause: function() { mediaPlayer.stub.lastAction = "pause"; },
            Stop: function() { mediaPlayer.stub.lastAction = "stop"; },
            Next: function() { mediaPlayer.stub.lastAction = "next"; },
            Previous: function() { mediaPlayer.stub.lastAction = "previous"; },
            Seek: function(value) { mediaPlayer.stub.offset = value; }
        })
    }
    QtObject {
        id: notifications
        property bool inhibited: false
        function setInhibited(value) { inhibited = value; }
    }
    SystemControls { id: audio; sink: output; source: input; player: mediaPlayer.stub }
    OnScreenDisplay { id: osd; width: 240; height: 44 }
    Component { id: panelComponent; ControlCenter { width: 340; audio: fixture.controls; notifications: fixture.notificationState } }
    TestCase {
        name: "SystemControls"; when: windowShown
        SignalSpy { id: panelClosed; signalName: "closed" }
        SignalSpy { id: feedback; target: audio; signalName: "feedback" }
        function init() {
            output.volume = 32768; input.volume = 32768; output.muted = false; input.muted = false;
            output.volumeWritable = true; mediaPlayer.stub.canControl = true; mediaPlayer.stub.canGoNext = true;
            mediaPlayer.stub.lastAction = ""; mediaPlayer.stub.volume = .5; feedback.clear();
        }
        function test_volumeStepsLimitsAndMute() {
            audio.globalAction("kmix", "increase_volume"); compare(audio.percent(output), 55);
            audio.globalAction("kmix", "decrease_volume_small"); compare(audio.percent(output), 54);
            audio.setVolume(output, 150); compare(output.volume, 65536);
            audio.globalAction("kmix", "increase_volume"); compare(output.volume, 65536);
            audio.setVolume(output, -2); compare(output.volume, 0);
            audio.globalAction("kmix", "mute"); verify(output.muted); compare(feedback.signalArguments[feedback.count - 1][0], "speaker-slash");
            audio.globalAction("kmix", "increase_volume"); verify(!output.muted); compare(audio.percent(output), 5);
            output.volumeWritable = false;
            audio.globalAction("kmix", "increase_volume"); compare(audio.percent(output), 5);
        }
        function test_microphoneAndUnknownActions() {
            audio.globalAction("kmix", "increase_microphone_volume"); compare(audio.percent(input), 55); compare(audio.percent(output), 50);
            audio.globalAction("kmix", "decrease_microphone_volume"); compare(audio.percent(input), 50);
            audio.globalAction("kmix", "mic_mute"); verify(input.muted); verify(!output.muted);
            const count = feedback.count;
            audio.globalAction("unknown", "mute"); audio.globalAction("kmix", "unknown");
            compare(feedback.count, count);
        }
        function test_mprisCapabilitiesAndSeek() {
            audio.globalAction("mediacontrol", "playpausemedia"); compare(mediaPlayer.stub.lastAction, "toggle");
            audio.globalAction("mediacontrol", "nextmedia"); compare(mediaPlayer.stub.lastAction, "next");
            mediaPlayer.stub.canGoNext = false; mediaPlayer.stub.lastAction = "";
            audio.globalAction("mediacontrol", "nextmedia"); compare(mediaPlayer.stub.lastAction, "");
            audio.globalAction("mediacontrol", "seekforwardmedia"); compare(mediaPlayer.stub.offset, 5000000);
            audio.globalAction("mediacontrol", "seekbackwardmedia"); compare(mediaPlayer.stub.offset, -5000000);
            mediaPlayer.stub.volume = .99; audio.globalAction("mediacontrol", "mediavolumeup"); compare(mediaPlayer.stub.volume, 1);
            mediaPlayer.stub.canControl = false;
            audio.globalAction("mediacontrol", "stopmedia"); compare(mediaPlayer.stub.lastAction, "");
        }
        function test_osdRequestsRestartAndIgnore() {
            osd.request("brightnessChanged", [65]); verify(osd.showing); compare(osd.percent, 65); compare(osd.icon, "sun");
            wait(900); osd.request("volumeChanged", [0]); compare(osd.icon, "speaker-slash");
            wait(700); verify(osd.showing);
            osd.request("unknown", []); osd.request("unknown", [42]); compare(osd.icon, "speaker-slash");
            tryCompare(osd, "showing", false, 1200);
            tryCompare(osd, "surfaceVisible", false, 500);
            osd.request("showText", ["input-keyboard", "Español"]); compare(osd.message, "Español"); compare(osd.percent, -1);
        }
        function test_controlCenterLoadAndEscape() {
            const panel = createTemporaryObject(panelComponent, parent);
            verify(panel !== null);
            panelClosed.target = panel; panelClosed.clear();
            panel.forceActiveFocus(); keyClick(Qt.Key_Escape); compare(panelClosed.count, 1);
        }
    }
}
