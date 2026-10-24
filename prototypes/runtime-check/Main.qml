pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects

// Technical stress scene only: three live source crops, not a proposed desktop UI.
Item {
    id: root
    width: 2048
    height: 1280
    property bool effectsEnabled: true
    focus: true
    Keys.onSpacePressed: effectsEnabled = !effectsEnabled
    Item {
        id: background
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "#173f45" }
                GradientStop { position: 0.5; color: "#b66c41" }
                GradientStop { position: 1; color: "#302d43" }
            }
        }
        Repeater {
            model: 90
            Rectangle {
                required property int index
                x: (index % 15) * 149 - 40
                y: Math.floor(index / 15) * 230 - 40
                width: 110
                height: 170
                radius: 16
                rotation: index * 17
                color: Qt.hsla((index * 0.037) % 1, 0.6, 0.6, 0.8)
                SequentialAnimation on rotation {
                    loops: Animation.Infinite
                    NumberAnimation { to: 180; duration: 5000 }
                    NumberAnimation { to: 0; duration: 5000 }
                }
            }
        }
        Rectangle {
            y: 500
            width: 340
            height: 340
            radius: 170
            color: "#f6e5be"
            NumberAnimation on x { from: -340; to: 2048; duration: 8000; loops: Animation.Infinite }
        }
    }
    Repeater {
        model: 3
        Item {
            id: panel
            required property int index
            x: 130 + index * 590
            y: 170 + index * 160
            width: 550
            height: 570
            clip: true
            ShaderEffectSource {
                id: sampled
                sourceItem: background
                sourceRect: Qt.rect(panel.x, panel.y, panel.width, panel.height)
                textureSize: Qt.size(panel.width, panel.height)
                live: true
                hideSource: false
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: sampled
                blurEnabled: root.effectsEnabled
                blur: 1
                blurMax: 64
                autoPaddingEnabled: false
            }
            Rectangle {
                anchors.fill: parent
                color: "#40202024"
                border.color: "#90ffffff"
                border.width: 1
                radius: 12
            }
            Text {
                anchors.centerIn: parent
                text: "Runtime check " + (panel.index + 1) + "\nLive blur / Space: toggle"
                color: "white"
                font.pixelSize: 27
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
