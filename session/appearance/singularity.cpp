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
    float time = 0, width = 1, height = 1, pointerX = .5, pointerY = .5, density = 1;
};
bool Shader::updateUniformData(RenderState &s, QSGMaterial *material, QSGMaterial *) {
    auto *m = static_cast<Material *>(material);
    auto *data = s.uniformData();
    if (s.isMatrixDirty()) std::memcpy(data->data(), s.combinedMatrix().constData(), 64);
    const float values[] = {s.opacity(), m->time, m->width, m->height, m->pointerX, m->pointerY, m->density};
    std::memcpy(data->data() + 64, values, sizeof(values));
    return true;
}
struct Vertex { float x, y, radius, phase, seed, kind; };
class ParticleNode final : public QSGGeometryNode {
public:
    int quality;
    explicit ParticleNode(int level) : quality(level) {
        static const QSGGeometry::Attribute attributes[] = {
            QSGGeometry::Attribute::create(0, 2, QSGGeometry::FloatType, true),
            QSGGeometry::Attribute::create(1, 4, QSGGeometry::FloatType)
        };
        static const QSGGeometry::AttributeSet set{2, sizeof(Vertex), attributes};
        const int count = level == 0 ? 18000 : level == 2 ? 64000 : 36000;
        auto *g = new QSGGeometry(set, count * 6);
        g->setDrawingMode(QSGGeometry::DrawTriangles);
        g->setVertexDataPattern(QSGGeometry::StaticPattern);
        auto *v = static_cast<Vertex *>(g->vertexData());
        std::mt19937 rng(0x51a91);
        auto random = [&rng] { return float(rng() >> 8) / 16777216.f; };
        const float corners[6][2] = {{-1,-1},{1,-1},{-1,1},{-1,1},{1,-1},{1,1}};
        for (int i = 0; i < count; ++i) {
            const float kind = random();
            const float radius = random(), phase = random() * 6.2831853f, seed = random();
            for (const auto &corner : corners) *v++ = {corner[0], corner[1], radius, phase, seed, kind};
        }
        setGeometry(g); setFlag(OwnsGeometry);
        auto *m = new Material;
        m->density = 36000.f / float(count);
        setMaterial(m); setFlag(OwnsMaterial);
    }
};
}

Singularity::Singularity(QQuickItem *parent) : QQuickItem(parent) {
    setFlag(ItemHasContents);
    m_timer.setInterval(34); // <=30 fps; no timer at all in static/hidden/paused mode.
    m_timer.setTimerType(Qt::PreciseTimer);
    connect(&m_timer, &QTimer::timeout, this, [this] {
        const float dt = std::min(float(m_clock.restart()) / 1000.f, .1f);
        m_time += dt;
        const QPointF target = m_reactive ? m_target : QPointF(.5, .5);
        m_pointer += (target - m_pointer) * (1.f - std::exp(-dt * 3.f));
        update(); emit elapsedChanged();
    });
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
void Singularity::attachWindow(QQuickWindow *window) {
    if (m_window) { m_window->removeEventFilter(this); disconnect(m_window, nullptr, this, nullptr); }
    m_window = window;
    if (window) {
        window->installEventFilter(this);
        connect(window, &QWindow::visibleChanged, this, &Singularity::syncTimer);
        connect(window, &QWindow::screenChanged, this, &Singularity::syncTimer);
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
    if (run == m_timer.isActive()) return;
    if (run) { m_clock.start(); m_timer.start(); } else m_timer.stop();
    emit animatingChanged();
}
void Singularity::setRunning(bool value) { if (m_running == value) return; m_running = value; syncTimer(); emit runningChanged(); }
void Singularity::setLocked(bool value) { m_locked = value; syncTimer(); }
void Singularity::setSleeping(bool value) { m_sleeping = value; syncTimer(); }
void Singularity::setPointer(QPointF value) {
    if (!std::isfinite(value.x()) || !std::isfinite(value.y())) return;
    value = QPointF(std::clamp(value.x(), 0., 1.), std::clamp(value.y(), 0., 1.));
    if (m_target == value) return; m_target = value; emit pointerChanged();
}
void Singularity::setReactive(bool value) { if (m_reactive == value) return; m_reactive = value; emit reactiveChanged(); }
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
    m->pointerX = m_pointer.x(); m->pointerY = m_pointer.y();
    node->markDirty(QSGNode::DirtyMaterial);
    return node;
}
