pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQml.Models
import org.kde.plasma.private.mpris as Mpris
import Singlr.Ui

Item {
    id: row
    required property var players
    readonly property var player: players.currentPlayer
    readonly property bool playing: !!player && player.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property bool canToggle: !!player && player.canControl && (playing ? player.canPause : player.canPlay)
    readonly property alias menu: choices
    onVisibleChanged: if (!visible) choices.close()
    implicitHeight: 36
    function perform(action) {
        if (!player || !player.canControl) return;
        if (action === "previous" && player.canGoPrevious) player.Previous();
        else if (action === "next" && player.canGoNext) player.Next();
        else if (action === "toggle" && canToggle) player.PlayPause();
    }
    function openMenu(anchor, px, py) {
        let entries = [];
        for (let i = 0; i < playerRows.count; ++i) {
            const data = playerRows.objectAt(i) as PlayerRow;
            entries.push({label: data.model.isMultiplexer ? "Automático" : data.model.identity,
                icon: players.currentIndex === i ? "check" : "music-notes", action: i});
        }
        choices.entries = entries;
        choices.showAt(anchor, px, py);
    }
    component PlayerRow: QtObject { required property var model }
    Instantiator {
        id: playerRows; model: row.players
        delegate: PlayerRow {}
        onObjectAdded: choices.close()
        onObjectRemoved: choices.close()
    }
    // The slot always occupies 36 px, even without a player. No progress polling.
    Item {
        anchors.fill: parent; visible: !!row.player
        Image {
            id: art; width: 28; height: 28; anchors.verticalCenter: parent.verticalCenter
            source: row.player ? row.player.artUrl : ""; sourceSize: Qt.size(28 * Screen.devicePixelRatio, 28 * Screen.devicePixelRatio)
            fillMode: Image.PreserveAspectCrop
        }
        Icon { width: 28; height: 28; anchors.verticalCenter: parent.verticalCenter; visible: art.status !== Image.Ready; name: "music-notes" }
        UiText {
            x: 38; height: parent.height; width: Math.max(0, parent.width - x - 112)
            text: row.player ? [row.player.track || row.player.identity, row.player.artist].filter(Boolean).join(" · ") : ""
            Accessible.name: text
        }
        TapHandler { acceptedButtons: Qt.RightButton; onTapped: point => row.openMenu(row, point.position.x, point.position.y) }
        Row {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            Tool { objectName: "mediaPrevious"; icon: "skip-back"; description: "Anterior"; enabled: !!row.player && row.player.canControl && row.player.canGoPrevious; opacity: enabled ? 1 : .4; onClicked: row.perform("previous") }
            Tool { objectName: "mediaToggle"; icon: row.playing ? "pause" : "play"; description: row.playing ? "Pausar" : "Reproducir"; enabled: row.canToggle; opacity: enabled ? 1 : .4; onClicked: row.perform("toggle") }
            Tool { objectName: "mediaNext"; icon: "skip-forward"; description: "Siguiente"; enabled: !!row.player && row.player.canControl && row.player.canGoNext; opacity: enabled ? 1 : .4; onClicked: row.perform("next") }
            Tool { icon: "dots-three"; description: "Reproductores"; onClicked: row.openMenu(row, row.width, row.height) }
        }
    }
    ContextMenu { id: choices; parent: row; onTriggered: entry => row.players.currentIndex = entry.action }
}
