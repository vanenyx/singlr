pragma ComponentBehavior: Bound
import QtQuick
import org.kde.kirigami as Kirigami
import Singlr.System as Native

Item {
    id: frame
    property var source
    readonly property rect inkBounds: Native.DockIconMetrics.contentRect(source)
    readonly property real targetExtent: Math.max(1, Math.min(width, height) - 2)
    // Bound pathological padding; keep a pixel of breathing room around the mark.
    readonly property real renderExtent: Math.min(Math.min(width, height) * 1.5,
        targetExtent / Math.max(inkBounds.width, inkBounds.height))
    clip: true
    Kirigami.Icon {
        objectName: "dockBrandIcon"
        source: frame.source
        roundToIconSize: false
        // Use the same sample size as the metrics, then downsample. Requesting
        // a nonstandard 35/53 px QIcon can select a smaller bitmap and upscale it.
        width: 128; height: width
        scale: frame.renderExtent / width
        transformOrigin: Item.TopLeft
        x: (frame.width - frame.renderExtent * frame.inkBounds.width) / 2 - frame.renderExtent * frame.inkBounds.x
        y: (frame.height - frame.renderExtent * frame.inkBounds.height) / 2 - frame.renderExtent * frame.inkBounds.y
    }
}
