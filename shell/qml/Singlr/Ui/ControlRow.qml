pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
Controls.AbstractButton {
    id: row
    property string glyph: ""
    property string secondaryText: ""
    property string status: ""
    property string actionText: ""
    property bool secured: false
    property bool busy: false
    signal actionTriggered()
    implicitHeight: 36
    leftPadding: 8; rightPadding: 8
    hoverEnabled: true
    Accessible.name: text + (secondaryText ? ", " + secondaryText : "") + (status ? ", " + status : "")
    background: Rectangle { radius: 6; color: row.hovered || row.visualFocus ? Theme.hover : "transparent"; border.color: row.visualFocus ? Theme.focusBorder : "transparent" }
    contentItem: Item {
        Icon { x: 0; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; font.pixelSize: 16; name: row.busy ? "circle-dashed" : row.glyph
            RotationAnimator on rotation { from: 0; to: 360; duration: 1500; loops: Animation.Infinite; running: row.busy }
        }
        UiText { x: 26; height: parent.height; width: Math.max(0, trailing.x - x - 8); text: row.text; horizontalAlignment: Text.AlignLeft; font.pixelSize: 13 }
        Row {
            id: trailing; anchors.right: parent.right; height: parent.height; spacing: 6
            Icon { visible: row.secured; anchors.verticalCenter: parent.verticalCenter; name: "lock-simple"; width: 12; height: 12; font.pixelSize: 12; color: Theme.muted }
            UiText { height: parent.height; visible: !!row.secondaryText && !row.busy && !row.status; text: row.secondaryText; color: Theme.muted; font.pixelSize: 11 }
            UiText { height: parent.height; visible: !(action.visible) && (!!row.status || row.busy); text: row.busy ? "Conectando…" : row.status; color: Theme.muted; font.pixelSize: 11 }
            Controls.Button {
                id: action; height: parent.height; visible: !!row.actionText && (row.hovered || row.activeFocus || hovered || activeFocus)
                text: row.actionText; leftPadding: 6; rightPadding: 6
                contentItem: UiText { text: action.text; font.pixelSize: 11; color: Theme.secondary }
                background: Rectangle { color: action.hovered ? Theme.raised : "transparent"; radius: 4 }
                onClicked: row.actionTriggered()
            }
        }
    }
}
