#include "singularity.h"
#include <QGuiApplication>
#include <QElapsedTimer>
#include <QQuickGraphicsConfiguration>
#include <QQuickWindow>
#include <QScreen>
#include <QTimer>
#include <rhi/qrhi.h>
#include <cmath>
#include <cstdio>
#include <atomic>

// Documented RHI API (Qt >=6.6), with limited compatibility guarantees.
// No Singularity internals: this measures the real public animation path.
int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    const QStringList args = app.arguments();
    bool valid = false;
    const int quality = args.value(1).toInt(&valid);
    if (args.size() != 3 || !valid || quality < 0 || quality > 2
        || (args[2] != "idle" && args[2] != "cursor")) {
        std::fprintf(stderr, "Usage: %s <0|1|2> <idle|cursor>\n", argv[0]);
        return 2;
    }
    const bool cursor = args[2] == "cursor";
    QQuickWindow::setGraphicsApi(QSGRendererInterface::Vulkan);
    // These outlive the window: render-thread callbacks cannot outlive their data.
    // Render-thread callbacks only touch atomics: no lock is shared with the GUI thread.
    std::atomic<bool> measuring{false};
    std::atomic<int> frames{0}, samples{0};
    std::atomic<double> gpuSeconds{0};
    QQuickWindow window;
    QQuickGraphicsConfiguration config;
    config.setTimestamps(true);
    window.setGraphicsConfiguration(config);
    QObject::connect(&window, &QQuickWindow::sceneGraphInitialized, &window, [&] {
        auto *rhi = window.rhi();
        if (rhi) std::fprintf(stderr, "GPU: %s; timestamps supported: %d\n",
                              rhi->driverInfo().deviceName.constData(), rhi->isFeatureSupported(QRhi::Timestamps));
    }, Qt::DirectConnection);
    window.setColor(Qt::black);
    window.setFlag(Qt::FramelessWindowHint); // Full output size, no server-side title bar.
    window.resize(2560, 1600);
    auto *effect = new Singularity(window.contentItem());
    effect->setSize(QSizeF(2560, 1600));
    effect->setQuality(quality);
    effect->setRunning(true);
    QObject::connect(&window, &QQuickWindow::frameSwapped, &window, [&] {
        if (measuring) ++frames;
    }, Qt::DirectConnection);
    QObject::connect(&window, &QQuickWindow::afterFrameEnd, &window, [&] {
        auto *chain = window.swapChain();
        if (!chain) return;
        const double seconds = chain->currentFrameCommandBuffer()->lastCompletedGpuTime();
        if (measuring && seconds > 0 && std::isfinite(seconds)) {
            gpuSeconds = gpuSeconds + seconds;
            ++samples;
        }
    }, Qt::DirectConnection);
    QElapsedTimer motionClock, measurementClock;
    motionClock.start();
    QTimer motion;
    motion.setTimerType(Qt::PreciseTimer);
    QObject::connect(&motion, &QTimer::timeout, &window, [&] {
        const double t = motionClock.nsecsElapsed() / 1e9;
        effect->setPointer(QPointF(.5 + .3 * std::cos(t * 2), .5 + .3 * std::sin(t * 3)));
    });
    if (cursor) {
        effect->setPointerActive(true);
        motion.start(16);
    }
    window.show();
    // Warm up shaders/swapchain for 2 s; sample 6 s, as in the original prototype.
    QTimer::singleShot(2000, &window, [&] {
        if (!window.isExposed() || !effect->animating()
            || window.rendererInterface()->graphicsApi() != QSGRendererInterface::Vulkan
            || window.size() != QSize(2560, 1600)) {
            std::fprintf(stderr, "Invalid benchmark: exposed=%d animating=%d api=%d size=%dx%d\n", window.isExposed(), effect->animating(),
                         int(window.rendererInterface()->graphicsApi()), window.width(), window.height());
            app.exit(1);
            return;
        }
        std::fprintf(stderr, "Qt %s; Vulkan; %dx%d; DPR %.2f; refresh %.2f Hz\n",
                     qVersion(), window.width(), window.height(), window.devicePixelRatio(),
                     window.screen()->refreshRate());
        measurementClock.start();
        measuring = true;
    });
    QTimer::singleShot(8000, &window, [&] {
        measuring = false;
        const double seconds = measurementClock.nsecsElapsed() / 1e9;
        if (frames == 0 || samples == 0 || seconds <= 0) {
            std::fprintf(stderr, "No frames or GPU timestamps; measurement unavailable\n");
            app.exit(1);
            return;
        }
        // Occupancy of this window's GPU commands, not whole-device utilization.
        std::printf("RESULT %d %s %.2f %.3f %.2f %d %.3f\n", quality,
                    cursor ? "cursor" : "idle", frames.load() / seconds,
                    gpuSeconds.load() * 1000 / samples.load(), gpuSeconds.load() / seconds * 100, samples.load(), seconds);
        app.quit();
    });
    return app.exec();
}
