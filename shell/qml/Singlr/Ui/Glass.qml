pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
Item {
    id: glass
    property Item backdrop
    property bool crystal: true
    property bool compositorBlur: false
    property real radius: 12
    readonly property bool rhi: glass.GraphicsInfo.api !== GraphicsInfo.Software && glass.GraphicsInfo.api !== GraphicsInfo.Unknown
    readonly property bool canBlur: crystal && rhi && backdrop !== null
    // Sample the lower scene only. Overscan protects the crop from blur edges.
    readonly property point origin: backdrop ? mapToItem(backdrop,-64,-64) : Qt.point(0,0)
    Loader {
        anchors.fill: parent
        active: glass.visible && glass.canBlur
        sourceComponent: Component {
            Item {
                ShaderEffectSource {
                    id: sample; visible: false
                    sourceItem: glass.canBlur ? glass.backdrop : null
                    sourceRect: Qt.rect(glass.origin.x,glass.origin.y,glass.width+128,glass.height+128)
                    textureSize: Qt.size(Math.ceil((glass.width+128)/4),Math.ceil((glass.height+128)/4))
                    live: glass.visible && glass.canBlur
                }
                Rectangle { id: mask; anchors.fill: parent; radius: glass.radius; color: "white"; visible: false; layer.enabled: glass.rhi }
                // The UV crop is provided through a second texture source, after overscan.
                MultiEffect {
                    id: blur; x:-64; y:-64; width:glass.width+128; height:glass.height+128
                    visible:false; source:sample; autoPaddingEnabled:false
                    blurEnabled:true; blurMax:64; blur:.85; saturation:-1
                }
                ShaderEffectSource {
                    id: crop; visible: false
                    textureSize: Qt.size(Math.ceil(glass.width/2), Math.ceil(glass.height/2))
                    sourceItem: glass.canBlur ? blur : null
                    sourceRect: Qt.rect(64,64,glass.width,glass.height)
                    live: glass.visible && glass.canBlur
                }
                MultiEffect {
                    anchors.fill: parent; visible: glass.canBlur
                    source: crop; autoPaddingEnabled: false
                    maskEnabled: true; maskSource: mask
                }
            }
        }
    }
    // Explicit opaque reduced-effects material on software: no fake CPU blur.
    Rectangle {
        anchors.fill: parent; radius: glass.radius
        color: glass.compositorBlur ? Theme.surface : glass.canBlur ? Qt.rgba(Theme.raised.r,Theme.raised.g,Theme.raised.b,Theme.dark?.78:.85) : Theme.raised
        border.width: 1; border.color: Theme.focusBorder
    }
    Rectangle { x:12; y:1; width:parent.width-24; height:1; color:Theme.sheen }
}
