pragma ComponentBehavior: Bound
import QtQuick
import Singlr.System

Singularity {
    id: effect
    objectName: "singularityParticles"
    running: true
    // Lifecycle diagnostics only; never log on every frame.
    onAnimatingChanged: console.info("Singlr Singularidad:", animating ? "animación activa" : "animación pausada")
    quality: Appearance.wallpaperQuality
    reactive: Appearance.wallpaperReactive
    pointer: hover.hovered ? Qt.point(hover.point.position.x / Math.max(1, effect.width), hover.point.position.y / Math.max(1, effect.height)) : Qt.point(.5, .5)
    // Passive desktop hover only: no mouse grab, keyboard focus or global tracking.
    HoverHandler { id: hover; enabled: effect.reactive }
}
