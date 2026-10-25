pragma ComponentBehavior: Bound
import QtQuick
import Singlr.Ui
Rectangle {
    id: card
    required property var entry
    property bool sessionMode: false
    readonly property bool hovered: hover.hovered
    signal dismissed()
    signal invoked(string action)
    width: 360; height: content.height + 24; radius: 10
    color: sessionMode ? Theme.surface : Theme.raised; border.color: Theme.border
    HoverHandler { id: hover }
    Accessible.role: Accessible.Button
    Accessible.name: entry.app + ": " + entry.title + ". " + entry.body
    activeFocusOnTab: true
    Keys.onReturnPressed: if (entry.defaultAction) invoked("default")
    MouseArea { anchors.fill: parent; enabled: card.entry.defaultAction; onClicked: card.invoked("default") }
    Column {
        id: content; x: 14; y: 12; width: parent.width - 28; spacing: 7
        Row {
            width: parent.width; spacing: 8
            AppIcon { name: card.entry.icon; width: 20; height: 20 }
            UiText { width: content.width - 100; height: 20; text: card.entry.app; font.pixelSize: 11; color: Theme.muted }
            UiText { width: 34; height: 20; text: Qt.formatTime(new Date(card.entry.time), "HH:mm"); font.pixelSize: 11; color: Theme.muted }
            Tool { width: 22; height: 20; icon: "x"; iconSize: 12; description: "Descartar notificación"; onClicked: card.dismissed() }
        }
        UiText { width: parent.width; text: card.entry.title; weight: 590; wrapMode: Text.Wrap; maximumLineCount: 2 }
        UiText { width: parent.width; visible: !!text; text: card.entry.body.replace(/<[^>]*>/g, "").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&"); wrapMode: Text.Wrap; maximumLineCount: 3; color: Theme.secondary }
        Flow {
            width: parent.width; spacing: 4
            Repeater {
                model: card.entry.actionNames || []
                Tool {
                    required property int index
                    required property string modelData
                    label: card.entry.actionLabels?.[index] || modelData
                    width: Math.min(label.length * 7 + 32, content.width); height: 28
                    onClicked: card.invoked(modelData)
                }
            }
        }
    }
}
