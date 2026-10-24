pragma ComponentBehavior: Bound
import QtQuick
import org.kde.plasma.private.volume as Volume
import org.kde.plasma.private.mpris as Mpris

Item {
    id: controls
    property var sink: Volume.PreferredDevice.sink
    property var source: Volume.PreferredDevice.source
    property var player: players.currentPlayer
    signal feedback(string icon, real percent, string text)
    Mpris.Mpris2Model { id: players }
    function percent(device) { return device ? Math.round(device.volume / 65536 * 100) : 0; }
    function setVolume(device, value, microphone = false) {
        if (!device || !device.volumeWritable) return;
        const bounded = Math.max(0, Math.min(100, value));
        device.volume = Math.round(bounded / 100 * 65536);
        device.muted = false;
        feedback(microphone ? "microphone" : "speaker-high", bounded, "");
    }
    function toggleMute(device, microphone = false) {
        if (!device) return;
        const muted = !device.muted;
        device.muted = muted;
        feedback(microphone ? (muted ? "microphone-slash" : "microphone") : (muted ? "speaker-slash" : "speaker-high"),
                 muted ? 0 : percent(device), "");
    }
    function globalAction(component, name) {
        if (component === "kmix") {
            const microphone = name.indexOf("microphone") >= 0 || name === "mic_mute";
            const device = microphone ? source : sink;
            if (name === "mute" || name === "mic_mute") toggleMute(device, microphone);
            else if (/^(increase|decrease)_(volume|microphone_volume)(_small)?$/.test(name)) {
                const step = name.endsWith("_small") ? 1 : 5;
                setVolume(device, percent(device) + (name.startsWith("increase") ? step : -step), microphone);
            }
            return;
        }
        if (component !== "mediacontrol" || !player || !player.canControl) return;
        switch (name) {
        case "playpausemedia":
            if ((player.playbackStatus === Mpris.PlaybackStatus.Playing && player.canPause)
                    || (player.playbackStatus !== Mpris.PlaybackStatus.Playing && player.canPlay)) player.PlayPause();
            break;
        case "playmedia": if (player.canPlay) player.Play(); break;
        case "pausemedia": if (player.canPause) player.Pause(); break;
        case "stopmedia": if (player.canStop) player.Stop(); break;
        case "nextmedia": if (player.canGoNext) player.Next(); break;
        case "previousmedia": if (player.canGoPrevious) player.Previous(); break;
        case "seekforwardmedia": if (player.canSeek) player.Seek(5000000); break;
        case "seekbackwardmedia": if (player.canSeek) player.Seek(-5000000); break;
        case "mediavolumeup":
        case "mediavolumedown": {
            const value = Math.max(0, Math.min(1, player.volume + (name === "mediavolumeup" ? .05 : -.05)));
            player.volume = value;
            feedback("speaker-high", Math.round(value * 100), "");
            break;
        }
        }
    }
}
