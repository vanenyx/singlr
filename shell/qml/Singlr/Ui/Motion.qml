pragma Singleton
import QtQuick
import org.kde.kirigami.platform as Kirigami
QtObject {
    // Plasma's platform Units watches kdeglobals [KDE] AnimationDurationFactor.
    // Units clamps longDuration to 1 ms for Animator reliability; disable rather
    // than run an infinite animator with that duration when motion is reduced.
    readonly property bool enabled: Kirigami.Units.longDuration > 1
    readonly property int duration: enabled ? Math.round(Kirigami.Units.longDuration * 0.6) : 0
    readonly property int spinnerDuration: enabled ? Math.round(Kirigami.Units.longDuration * 7.5) : 0
}
