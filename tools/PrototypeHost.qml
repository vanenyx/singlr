import QtQuick
import QtQuick.Window

Window {
    id: host
    visible: false
    width: 2048
    height: 1280
    title: "Singlr isolated prototype"
    property var scene: null
    property var surface: null
    property var options: JSON.parse(Qt.application.arguments[Qt.application.arguments.length - 1])
    property int frames: 0
    property double started: 0
    property var intervals: []
    property double previous: 0
    function fail(message: string): void {
        console.error("SINGLR_ERROR " + message)
        Qt.exit(1)
    }
    Component.onCompleted: {
        let component = Qt.createComponent(options.source)
        if (component.status !== Component.Ready) {
            fail(component.errorString())
            return
        }
        scene = component.createObject(null)
        if (!scene) { fail(component.errorString()); return }
        if (scene instanceof Window) {
            surface = scene.contentItem
            scene.visible = true
        } else if (scene instanceof Item) {
            scene.parent = host.contentItem
            surface = scene
            host.width = scene.width || host.width
            host.height = scene.height || host.height
            host.visible = true
        } else { fail("Root must be Item or Window"); return }
        if (options.width) {
            scene.width = options.width
            scene.height = options.height
            if (!(scene instanceof Window)) {
                host.width = options.width
                host.height = options.height
            }
        }
        console.log("SINGLR_LOADED " + options.source)
        if (options.capture) captureTimer.start()
        if (options.duration) finishTimer.start()
    }
    // frameSwapped measures delivery cadence, not GPU execution time.
    Connections {
        target: host.scene instanceof Window ? host.scene : host
        function onFrameSwapped(): void {
            let now = Date.now()
            if (!host.started) host.started = now
            if (now - host.started < 1000) { host.previous = now; return }
            if (host.previous) host.intervals.push(now - host.previous)
            host.previous = now
            host.frames++
        }
    }
    Timer {
        id: captureTimer
        interval: 800
        onTriggered: {
            let ok = host.surface.grabToImage(function(result) {
                if (!result.saveToFile(host.options.capture)) {
                    host.fail("Cannot save capture"); return
                }
                console.log("SINGLR_CAPTURE " + host.options.capture)
                Qt.quit()
            }, Qt.size(host.options.width, host.options.height))
            if (!ok) host.fail("grabToImage rejected")
        }
    }
    Timer {
        id: finishTimer
        interval: host.options.duration || 10000
        onTriggered: {
            let samples = host.intervals.sort(function(a, b) { return a - b })
            let total = samples.reduce(function(a, b) { return a + b }, 0)
            console.log("SINGLR_FRAMES " + JSON.stringify({
                samples: samples.length, warmupMs: 1000,
                meanMs: samples.length ? total / samples.length : null,
                p95Ms: samples.length ? samples[Math.floor(samples.length * 0.95)] : null,
                maxMs: samples.length ? samples[samples.length - 1] : null
            }))
            Qt.quit()
        }
    }
}
