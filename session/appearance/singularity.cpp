#include "singularity.h"
#include <QQuickWindow>
#include <QSGGeometryNode>
#include <QSGMaterial>
#include <QSGMaterialShader>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QGuiApplication>
#include <KScreenDpms/Dpms>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <random>

namespace {
class Material;
class Shader final : public QSGMaterialShader {
public:
    Shader() {
        setShaderFileName(VertexStage, QStringLiteral(":/singlr/singularity/shaders/singularity.vert.qsb"));
        setShaderFileName(FragmentStage, QStringLiteral(":/singlr/singularity/shaders/singularity.frag.qsb"));
        setFlag(UpdatesGraphicsPipelineState);
    }
    bool updateUniformData(RenderState &, QSGMaterial *, QSGMaterial *) override;
    bool updateGraphicsPipelineState(RenderState &, GraphicsPipelineState *s, QSGMaterial *, QSGMaterial *) override {
        s->blendEnable = true;
        s->srcColor = GraphicsPipelineState::One;
        s->dstColor = GraphicsPipelineState::One;
        return true;
    }
};
class Material final : public QSGMaterial {
public:
    Material() { setFlag(Blending); setFlag(RequiresFullMatrix); setFlag(NoBatching); }
    QSGMaterialType *type() const override { static QSGMaterialType type; return &type; }
    QSGMaterialShader *createShader(QSGRendererInterface::RenderMode) const override { return new Shader; }
    // Distinct uniforms per output: never merge different surfaces into one draw.
    int compare(const QSGMaterial *other) const override { return this == other ? 0 : std::less<const QSGMaterial *>{}(this, other) ? -1 : 1; }
    float time = 0, width = 1, height = 1, density = 1;
    int wakeCount = 0; // Live wakes are packed first; the shader reads no others.
    std::array<float, 32 * 4> wakes{}, pushes{};
};
bool Shader::updateUniformData(RenderState &s, QSGMaterial *material, QSGMaterial *) {
    auto *m = static_cast<Material *>(material);
    auto *data = s.uniformData();
    if (s.isMatrixDirty()) std::memcpy(data->data(), s.combinedMatrix().constData(), 64);
    // Point sizes are in framebuffer pixels, so the shader needs the output scale.
    const float values[] = {s.opacity(), m->time, m->width, m->height, float(s.devicePixelRatio()), float(m->wakeCount), m->density, 0.f};
    Q_ASSERT(data->size() >= 96 + 2 * int(sizeof(m->wakes)));
    std::memcpy(data->data() + 64, values, sizeof(values));
    std::memcpy(data->data() + 96, m->wakes.data(), sizeof(m->wakes));
    std::memcpy(data->data() + 96 + sizeof(m->wakes), m->pushes.data(), sizeof(m->pushes));
    return true;
}
struct Vertex { float radius, phase, seed, kind; };
class ParticleNode final : public QSGGeometryNode {
public:
    int quality;
    explicit ParticleNode(int level) : quality(level) {
        static const QSGGeometry::Attribute attributes[] = {
            QSGGeometry::Attribute::create(0, 4, QSGGeometry::FloatType, true)
        };
        static const QSGGeometry::AttributeSet set{1, sizeof(Vertex), attributes};
        const int count = level == 0 ? 26000 : level == 2 ? 90000 : 52000;
        // One primitive per particle: rasterizing small primitives, not shading
        // pixels, dominates the cost on integrated GPUs.
        auto *g = new QSGGeometry(set, count);
        g->setDrawingMode(QSGGeometry::DrawPoints);
        g->setVertexDataPattern(QSGGeometry::StaticPattern);
        auto *v = static_cast<Vertex *>(g->vertexData());
        std::mt19937 rng(0x51a91);
        auto random = [&rng] { return float(rng() >> 8) / 16777216.f; };
        for (int i = 0; i < count; ++i) {
            const float kind = random();
            const float radius = random(), phase = random() * 6.2831853f, seed = random();
            *v++ = {radius, phase, seed, kind};
        }
        setGeometry(g); setFlag(OwnsGeometry);
        auto *m = new Material;
        m->density = 52000.f / float(count);
        setMaterial(m); setFlag(OwnsMaterial);
    }
};
}

Singularity::Singularity(QQuickItem *parent) : QQuickItem(parent) {
    setFlag(ItemHasContents);
    // One pending single shot at most; nothing is scheduled in static/hidden/paused mode.
    m_timer.setSingleShot(true);
    m_timer.setTimerType(Qt::PreciseTimer);
    connect(&m_timer, &QTimer::timeout, this, &Singularity::requestFrame);
    connect(this, &QQuickItem::windowChanged, this, &Singularity::attachWindow);
    connect(this, &QQuickItem::visibleChanged, this, &Singularity::syncTimer);
    auto session = QDBusConnection::sessionBus();
    session.connect(QStringLiteral("org.freedesktop.ScreenSaver"), QStringLiteral("/ScreenSaver"),
                    QStringLiteral("org.freedesktop.ScreenSaver"), QStringLiteral("ActiveChanged"), this, SLOT(setLocked(bool)));
    auto request = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.ScreenSaver"), QStringLiteral("/ScreenSaver"),
                                                 QStringLiteral("org.freedesktop.ScreenSaver"), QStringLiteral("GetActive"));
    auto *watcher = new QDBusPendingCallWatcher(session.asyncCall(request), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher] {
        const QDBusPendingReply<bool> reply = *watcher;
        if (!reply.isError()) setLocked(reply.value());
        watcher->deleteLater();
    });
    QDBusConnection::systemBus().connect(QStringLiteral("org.freedesktop.login1"), QStringLiteral("/org/freedesktop/login1"),
                                        QStringLiteral("org.freedesktop.login1.Manager"), QStringLiteral("PrepareForSleep"), this, SLOT(setSleeping(bool)));
    if (QGuiApplication::platformName().startsWith(QLatin1String("wayland"))) {
        // Observe only: never request a DPMS mode or inhibit idle/sleep.
        auto *dpms = new KScreen::Dpms(this);
        connect(dpms, &KScreen::Dpms::modeChanged, this, [this](KScreen::Dpms::Mode mode, QScreen *screen) {
            m_screenOff[screen] = mode != KScreen::Dpms::On; syncTimer();
        });
        connect(qGuiApp, &QGuiApplication::screenRemoved, this, [this](QScreen *screen) { m_screenOff.remove(screen); syncTimer(); });
    }
    attachWindow(window());
}
float Singularity::wakeStrength(qreal age) {
    if (age < 0 || age >= WakeLife) return 0;
    // Eases in instead of jumping, returns with a faint overshoot like
    // disturbed water and reaches exactly zero before the slot is reused.
    const qreal rise = 1. - std::exp(-age / .07);
    const qreal t = std::clamp((age - 1.1) / (WakeLife - 1.1), 0., 1.);
    const qreal fade = 1. - t * t * (3. - 2. * t);
    return float(.8 * rise * std::exp(-age * 3.2) * std::cos(age * 3.) * fade);
}
void Singularity::advanceFrame(float dt) {
    m_time += dt;
    // Only a tiny cursor history runs on the CPU. Every particle stays on the GPU.
    if (m_reactive && m_pointerActive && m_pointerDirty) {
        const QPointF moved = m_target - m_lastPointer;
        const qreal distance = std::hypot(moved.x() * width(), moved.y() * height());
        const qreal since = m_time - m_lastWake;
        // Wakes are spaced by distance, so a fast stroke leaves a continuous
        // trail instead of separate bumps. A live wake is never overwritten.
        if (distance < 1.) m_pointerDirty = false;
        else if (distance >= std::min(width(), height()) * .04 || since >= .05) {
            auto *slot = std::find_if(m_wakes.begin(), m_wakes.end(), [this](const Wake &w) { return m_time - w.born >= WakeLife; });
            if (slot != m_wakes.end()) {
                QPointF velocity = moved / std::clamp(since, 1. / 60., .15);
                const qreal length = std::hypot(velocity.x(), velocity.y());
                if (length > 2.) velocity *= 2. / length;
                *slot = {m_target, velocity, m_time};
                m_lastWake = m_time;
                m_lastPointer = m_target;
                m_pointerDirty = false;
            }
        }
    }
    update(); emit elapsedChanged();
}
void Singularity::requestFrame() {
    if (!m_active) return;
    // Time advances on a fixed grid of whole refresh periods, so motion stays
    // even when a frame lands one vblank late or the compositor holds frames.
    const qint64 now = m_clock.nsecsElapsed();
    float dt = 0;
    if (m_lastTick >= 0) {
        const qint64 ticks = std::max<qint64>(1, std::llround(double(now - m_lastTick) / double(m_period)));
        m_lastTick += ticks * m_period;
        dt = float(ticks * m_period) / 1e9f;
    } else m_lastTick = now;
    m_framePending = true;
    advanceFrame(std::min(dt, .1f));
}
void Singularity::scheduleFrame() {
    if (!m_active || m_framePending) return;
    const qreal refresh = m_window && m_window->screen() && m_window->screen()->refreshRate() > 1 ? m_window->screen()->refreshRate() : 60.;
    const bool interactive = wakesAlive() || (m_reactive && m_pointerActive && m_pointerDirty);
    // 30 fps at rest, 60 fps while the cursor disturbs the field, always as a
    // whole number of output refresh periods to avoid uneven frame pacing.
    const qint64 vblank = qint64(1e9 / refresh);
    m_period = std::max<qint64>(1, std::llround(refresh / (interactive ? 60. : 30.))) * vblank;
    if (m_lastTick < 0) { requestFrame(); return; }
    const qint64 wait = m_lastTick + m_period - m_clock.nsecsElapsed() - vblank / 2;
    m_timer.start(int(std::max<qint64>(0, wait / 1000000)));
}
void Singularity::frameSwapped() {
    // Only the frame this item asked for continues the chain. If the compositor
    // stops presenting the surface (covered, off, locked), no swap arrives and
    // the animation costs nothing until it is shown again.
    if (!m_framePending) return;
    m_framePending = false;
    scheduleFrame();
}
void Singularity::attachWindow(QQuickWindow *window) {
    if (m_window) { m_window->removeEventFilter(this); disconnect(m_window, nullptr, this, nullptr); }
    m_window = window;
    if (window) {
        window->installEventFilter(this);
        connect(window, &QWindow::visibleChanged, this, &Singularity::syncTimer);
        connect(window, &QWindow::screenChanged, this, &Singularity::syncTimer);
        connect(window, &QQuickWindow::frameSwapped, this, &Singularity::frameSwapped, Qt::QueuedConnection);
    }
    syncTimer();
}
bool Singularity::eventFilter(QObject *object, QEvent *event) {
    if (object == m_window && (event->type() == QEvent::Expose || event->type() == QEvent::Hide || event->type() == QEvent::Show))
        QMetaObject::invokeMethod(this, &Singularity::syncTimer, Qt::QueuedConnection);
    return QQuickItem::eventFilter(object, event);
}
void Singularity::syncTimer() {
    const bool run = m_running && isVisible() && m_window && m_window->isVisible() && m_window->isExposed()
        && !m_locked && !m_sleeping && !m_screenOff.value(m_window->screen(), false)
        && m_window->rendererInterface()->graphicsApi() != QSGRendererInterface::Software;
    if (run == m_active) return;
    m_active = run;
    m_timer.stop();
    m_framePending = false;
    m_lastTick = -1;
    if (run) { m_clock.start(); scheduleFrame(); }
    emit animatingChanged();
}
void Singularity::setRunning(bool value) { if (m_running == value) return; m_running = value; syncTimer(); emit runningChanged(); }
void Singularity::setLocked(bool value) { m_locked = value; syncTimer(); }
void Singularity::setSleeping(bool value) { m_sleeping = value; syncTimer(); }
void Singularity::setPointer(QPointF value) {
    if (!std::isfinite(value.x()) || !std::isfinite(value.y())) return;
    value = QPointF(std::clamp(value.x(), 0., 1.), std::clamp(value.y(), 0., 1.));
    if (m_target == value) return; m_target = value;
    if (m_pointerActive && m_reactive) {
        m_pointerDirty = true;
        // Leave the 30 fps cadence as soon as the cursor starts moving.
        if (m_timer.isActive()) { m_timer.stop(); scheduleFrame(); }
    }
    emit pointerChanged();
}
void Singularity::setPointerActive(bool value) {
    if (m_pointerActive == value) return;
    m_pointerActive = value;
    m_pointerDirty = false;
    if (value) m_lastPointer = m_target; // Re-entry must not create a cross-screen impulse.
    emit pointerActiveChanged();
}
void Singularity::setReactive(bool value) {
    if (m_reactive == value) return;
    m_reactive = value;
    if (!value) { m_wakes = {}; update(); }
    emit reactiveChanged();
}
void Singularity::setQuality(int value) {
    value = std::clamp(value, 0, 2); if (m_quality == value) return;
    m_quality = value; update(); emit qualityChanged();
}
QSGNode *Singularity::updatePaintNode(QSGNode *old, UpdatePaintNodeData *) {
    if (!window() || window()->rendererInterface()->graphicsApi() == QSGRendererInterface::Software || width() <= 0 || height() <= 0) {
        delete old; return nullptr;
    }
    auto *node = static_cast<ParticleNode *>(old);
    if (node && node->quality != m_quality) { delete node; node = nullptr; }
    if (!node) node = new ParticleNode(m_quality);
    auto *m = static_cast<Material *>(node->material());
    m->time = m_time; m->width = width(); m->height = height();
    m->wakeCount = 0;
    for (const auto &wake : m_wakes) {
        const qreal age = m_time - wake.born;
        const float strength = m_reactive ? wakeStrength(age) : 0.f;
        if (strength == 0.f) continue;
        const int at = m->wakeCount++ * 4;
        m->wakes[at] = wake.position.x(); m->wakes[at + 1] = wake.position.y();
        m->wakes[at + 2] = strength; m->wakes[at + 3] = float(age);
        m->pushes[at] = wake.velocity.x(); m->pushes[at + 1] = wake.velocity.y();
    }
    node->markDirty(QSGNode::DirtyMaterial);
    return node;
}
