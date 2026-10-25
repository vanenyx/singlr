// SPDX-License-Identifier: GPL-2.0-or-later
// Original Singlr pass. Architecture studied against KWin v6.8.1 plugins/blur
// (GPL-2.0-or-later); the native blur remains responsible for the base blur.
#include "liquidglass.h"
#include "shader.h"
#include "blurregion.h"
#include <core/rendertarget.h>
#include <core/renderviewport.h>
#include <effect/effecthandler.h>
#include <effect/effectwindow.h>
#include <window.h>
#include <opengl/eglcontext.h>
#include <opengl/glshadermanager.h>
#include <opengl/glvertexbuffer.h>
#include <cstring>
#include <vector>
#include <wayland/surface.h>
#include <wayland/clientconnection.h>
#include <KSharedConfig>
#include <QVector2D>
#include <QColor>
#include <cmath>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

namespace KWin {
bool GlassEffect::supported() {
    return effects->isOpenGLCompositing() && effects->openglContext()
        && !effects->openglContext()->isSoftwareRenderer();
}
GlassEffect::GlassEffect() {
    m_shader = ShaderManager::instance()->generateCustomShader(ShaderTrait::MapTexture, {}, glassFragment);
    if (!m_shader) {
        m_shader.reset();
        qWarning("Singlr Glass: shader unavailable; retaining native glass");
    }
    connect(effects, &EffectsHandler::windowAdded, this, &GlassEffect::watch);
    connect(effects, &EffectsHandler::windowDeleted, this, [this](EffectWindow *w) {
        auto it = m_surfaces.find(w);
        if (it == m_surfaces.end()) return;
        disconnect(it->second.blurConnection);
        effects->makeOpenGLContextCurrent();
        m_surfaces.erase(it);
    });
    connect(effects, &EffectsHandler::viewRemoved, this, [this](RenderView *view) {
        effects->makeOpenGLContextCurrent();
        for (auto &[w, surface] : m_surfaces) surface.buffers.erase(view);
    });
    m_watcher = KConfigWatcher::create(effects->config());
    connect(m_watcher.data(), &KConfigWatcher::configChanged, this,
        [this](const KConfigGroup &group) {
            if (group.name() == QLatin1String("Effect-singlrliquidglass")) reconfigure(ReconfigureAll);
        });
    m_materialConfig = KSharedConfig::openConfig(QStringLiteral("singlr/singlr.conf"), KConfig::SimpleConfig);
    m_paletteConfig = KSharedConfig::openConfig(QStringLiteral("kdeglobals"));
    m_materialWatcher = KConfigWatcher::create(m_materialConfig);
    m_paletteWatcher = KConfigWatcher::create(m_paletteConfig);
    for (const auto &watcher : {m_materialWatcher, m_paletteWatcher})
        connect(watcher.data(), &KConfigWatcher::configChanged, this, [this] { reconfigure(ReconfigureAll); });
    reconfigure(ReconfigureAll);
    for (auto w : effects->stackingOrder()) watch(w);
}
GlassEffect::~GlassEffect() {
    effects->makeOpenGLContextCurrent();
    m_surfaces.clear();
    m_shader.reset();
}
bool GlassEffect::accepts(EffectWindow *w) const {
    return w && w->surface() && SinglrGlass::eligible(w->window()->resourceClass(),
        w->window()->inherits("KWin::LayerShellV1Window"), !w->surface()->blurRegion().isEmpty());
}
QString GlassEffect::debug(const QString &) const {
    const auto desktop = effects->virtualScreenGeometry();
    QJsonArray windows;
    for (const auto &[w, surface] : m_surfaces) {
        const auto bounds = w->surface()->blurRegion().boundingRect();
        windows.append(QJsonObject{
            {"id", w->internalId().toString()}, {"pid", int(w->pid())},
            {"executable", w->surface()->client()->executablePath()},
            {"resourceClass", w->window()->resourceClass()}, {"visible", w->isVisible()},
            {"eligible", accepts(w)}, {"backgroundItem", bool(surface.item)},
            {"region", QJsonArray{bounds.x(), bounds.y(), bounds.width(), bounds.height()}},
            {"position", QJsonArray{w->pos().x(), w->pos().y()}},
            {"radius", surface.radius}, {"draws", qint64(surface.draws)}, {"lastResult", QString::fromLatin1(surface.lastResult)}});
    }
    return QString::fromUtf8(QJsonDocument(QJsonObject{
        {"shader", bool(m_shader)}, {"enabled", m_settings.enabled},
        {"dark", m_dark}, {"intensity", m_settings.intensity}, {"active", isActive()},
        {"diagnosticOverlay", m_diagnosticOverlay}, {"chainPosition", requestedEffectChainPosition()},
        {"virtualGeometry", QJsonArray{desktop.x(), desktop.y(), desktop.width(), desktop.height()}},
        {"screenCount", effects->screens().size()},
        {"windows", windows}}).toJson(QJsonDocument::Compact));
}
bool GlassEffect::isActive() const {
    if (!m_shader || !m_settings.active() || effects->isScreenLocked()) return false;
    for (const auto &[w, surface] : m_surfaces) if (surface.item && w->isVisible()) return true;
    return false;
}
void GlassEffect::reconfigure(ReconfigureFlags) {
    auto config = effects->config();
    config->reparseConfiguration();
    m_materialConfig->reparseConfiguration();
    m_paletteConfig->reparseConfiguration();
    m_settings = SinglrGlass::Settings::readSurface(config->group(QStringLiteral("Effect-singlrliquidglass")),
        m_materialConfig->group("Appearance"), m_materialConfig->group("Accessibility"));
    const auto background = m_paletteConfig->group("Colors:Window").readEntry("BackgroundNormal", QColor(32, 32, 32));
    m_dark = qGray(background.rgb()) < 192;
    m_diagnosticOverlay = config->group(QStringLiteral("Effect-singlrliquidglass")).readEntry("DiagnosticOverlay", false);
    for (auto &[w, surface] : m_surfaces) update(w);
    // One repaint for a settings change; never a timer or postPaint repaint loop.
    effects->addRepaintFull();
}
void GlassEffect::watch(EffectWindow *w) {
    if (!w->surface() || !w->window()->inherits("KWin::LayerShellV1Window") || m_surfaces.contains(w)) return;
    connect(w->window(), &Window::windowClassChanged, this, [this,w] { update(w); });
    connect(w, &EffectWindow::windowHiddenChanged, this, [this,w] {
        if (!w->isVisible()) {
            effects->makeOpenGLContextCurrent();
            m_surfaces.at(w).buffers.clear();
        }
    });
    auto &surface = m_surfaces[w];
    surface.blurConnection = connect(w->surface(), &SurfaceInterface::blurChanged, this, [this,w] { update(w); });
    update(w);
}
void GlassEffect::update(EffectWindow *w) {
    auto &surface = m_surfaces.at(w);
    surface.draws = 0;
    surface.radius = -1;
    if (!m_shader || !m_settings.active() || !accepts(w)) {
        surface.lastResult = !m_shader ? "no-shader" : !m_settings.active() ? "disabled" : "ineligible-client-or-region";
        effects->makeOpenGLContextCurrent();
        surface.item.reset(); surface.buffers.clear();
        return;
    }
    // Exact corner radius from the shell's deterministic blur region (no side channel).
    const auto region = w->surface()->blurRegion();
    const auto bounds = region.boundingRect();
    std::map<int, int> rowInset;
    for (const auto &r : region.rects())
        for (int y = r.top(); y < r.top() + r.height(); ++y) {
            const int inset = r.left() - bounds.left();
            auto it = rowInset.find(y);
            if (it == rowInset.end() || inset < it->second) rowInset[y] = inset;
        }
    std::vector<int> insets;
    for (int y = bounds.top(); y < bounds.top() + bounds.height(); ++y) {
        const auto it = rowInset.find(y);
        if (it == rowInset.end() || it->second <= 0) break;
        insets.push_back(it->second);
    }
    surface.radius = SinglrGlass::radiusFromInsets(insets, std::min(bounds.width(), bounds.height()) / 2.0);
    effects->addRepaint(w->expandedGeometry());
    if (!surface.item) surface.item = std::make_unique<BackgroundEffectItem>(w->windowItem());
    surface.lastResult = "waiting-for-draw";
    surface.item->setEffectBoundingRect(w->surface()->blurRegion().boundingRect().adjusted(-40, -40, 40, 40));
    surface.item->setPixelsToExpandRepaintsBelowOpaqueRegions(40);
}
void GlassEffect::prePaintScreen(ScreenPrePaintData &data) {
    m_view = data.view;
    effects->prePaintScreen(data);
}
bool GlassEffect::drawWindow(const RenderTarget &target, const RenderViewport &viewport,
        EffectWindow *w, int mask, const Region &region, WindowPaintData &data) {
    if (m_shader && m_settings.active() && m_surfaces.contains(w) && accepts(w) && !effects->activeFullScreenEffect()
        && !(mask & PAINT_WINDOW_TRANSFORMED) && data.xScale() == 1.0 && data.yScale() == 1.0
        && data.xTranslation() == 0 && data.yTranslation() == 0 && data.opacity() == 1.0 && w->opacity() == 1.0)
        render(target, viewport, w, region);
    else if (m_settings.active() && m_surfaces.contains(w) && accepts(w))
        m_surfaces.at(w).lastResult = "skipped-transform-opacity-or-fullscreen-effect";
    return effects->drawWindow(target, viewport, w, mask, region, data);
}
void GlassEffect::render(const RenderTarget &target, const RenderViewport &viewport,
        EffectWindow *w, const Region &deviceRegion) {
    const auto shape = w->surface()->blurRegion().translated(w->pos());
    const auto panelBounds = shape.boundingRect().rounded();
    // Overscan supplies real background to diffusion on every side of the panel.
    const auto bounds = panelBounds.adjusted(-40, -40, 40, 40).intersected(effects->virtualScreenGeometry());
    auto &surface = m_surfaces.at(w);
    surface.lastResult = "outside-viewport";
    if (bounds.isEmpty() || !bounds.intersects(viewport.renderRect().rounded())) return;
    auto &buffer = m_surfaces.at(w).buffers[m_view];
    surface.lastResult = "texture-or-framebuffer-failed";
    const GLenum format = target.texture() ? target.texture()->internalFormat() : GL_RGBA8;
    if (!buffer.texture || buffer.bounds != bounds || buffer.texture->internalFormat() != format) {
        buffer.framebuffer.reset();
        buffer.texture = GLTexture::allocate(format, bounds.size());
        if (!buffer.texture) return;
        buffer.texture->setFilter(GL_LINEAR); buffer.texture->setWrapMode(GL_CLAMP_TO_EDGE);
        buffer.framebuffer = std::make_unique<GLFramebuffer>(buffer.texture.get());
        if (!buffer.framebuffer->valid()) { buffer.framebuffer.reset(); buffer.texture.reset(); return; }
        buffer.bounds = bounds;
        // Clear untouched pixels on the first partial-damage frame.
        GLFramebuffer::pushFramebuffer(buffer.framebuffer.get());
        glClearColor(0,0,0,0); glClear(GL_COLOR_BUFFER_BIT);
        GLFramebuffer::popFramebuffer();
    }
    const Region dirty = viewport.mapFromDeviceCoordinatesContained(deviceRegion) & bounds;
    surface.lastResult = "blit-failed";
    for (const Rect &rect : dirty.rects())
        if (!buffer.framebuffer->blitFromRenderTarget(target, viewport, rect, rect.translated(-bounds.topLeft()))) return;
    // Do not guess from the integer blur region. Native blur remains the
    // fallback until the shell supplies exact geometry asynchronously.
    if (surface.radius < 0) { surface.lastResult = "waiting-for-geometry"; return; }
    const double radius = std::min(surface.radius, std::min(panelBounds.width(), panelBounds.height()) / 2.0);
    ShaderBinder shader(m_shader.get());
    QMatrix4x4 matrix = viewport.projectionMatrix();
    const auto scaledBounds = bounds.scaled(viewport.scale()).rounded();
    matrix.translate(scaledBounds.x(), scaledBounds.y());
    m_shader->setUniform(GLShader::Mat4Uniform::ModelViewProjectionMatrix, matrix);
    m_shader->setUniform("sampler", 0);
    m_shader->setUniform("extent", QVector2D(panelBounds.width(), panelBounds.height()));
    m_shader->setUniform("sourceExtent", QVector2D(bounds.width(), bounds.height()));
    m_shader->setUniform("inset", QVector2D(panelBounds.x()-bounds.x(), panelBounds.y()-bounds.y()));
    m_shader->setUniform("deviceScale", float(viewport.scale()));
    m_shader->setUniform("dark", m_dark ? 1.0f : 0.0f);
    m_shader->setUniform("radius", float(radius));
    m_shader->setUniform("strength", float(m_settings.intensity / 100.0));
    m_shader->setUniform("diagnosticOverlay", m_diagnosticOverlay ? 1.0f : 0.0f);
    const bool blend = glIsEnabled(GL_BLEND);
    GLint srcRGB, dstRGB, srcAlpha, dstAlpha, equationRGB, equationAlpha;
    glGetIntegerv(GL_BLEND_SRC_RGB, &srcRGB); glGetIntegerv(GL_BLEND_DST_RGB, &dstRGB);
    glGetIntegerv(GL_BLEND_SRC_ALPHA, &srcAlpha); glGetIntegerv(GL_BLEND_DST_ALPHA, &dstAlpha);
    glGetIntegerv(GL_BLEND_EQUATION_RGB, &equationRGB); glGetIntegerv(GL_BLEND_EQUATION_ALPHA, &equationAlpha);
    glEnable(GL_BLEND);
    glBlendEquation(GL_FUNC_ADD);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    buffer.texture->bind();
    // Rasterize the bounding box: clipping to wl_region would cut off the AA fringe.
    // SDF coverage alone clips the round corners; zero coverage never touches the target.
    const Rect deviceBounds = viewport.mapToDeviceCoordinatesAligned(bounds);
    const Region clip = deviceRegion & viewport.mapToDeviceCoordinatesAligned(panelBounds.adjusted(-1, -1, 1, 1));
    std::vector<GLVertex2D> vertices;
    for (const Rect &rect : clip.rects()) {
        const RectF local = rect.translated(-deviceBounds.topLeft());
        const float x0 = local.left(), y0 = local.top(), x1 = local.right(), y1 = local.bottom();
        const float u0 = x0 / scaledBounds.width(), u1 = x1 / scaledBounds.width();
        const float v0 = 1.0f - y0 / scaledBounds.height(), v1 = 1.0f - y1 / scaledBounds.height();
        vertices.insert(vertices.end(), {
            {QVector2D(x0,y0), QVector2D(u0,v0)}, {QVector2D(x1,y0), QVector2D(u1,v0)},
            {QVector2D(x0,y1), QVector2D(u0,v1)}, {QVector2D(x0,y1), QVector2D(u0,v1)},
            {QVector2D(x1,y0), QVector2D(u1,v0)}, {QVector2D(x1,y1), QVector2D(u1,v1)}});
    }
    auto *vbo = GLVertexBuffer::streamingBuffer();
    surface.lastResult = vertices.empty() ? "empty-damage-clip" : "vertex-map-failed";
    vbo->reset(); vbo->setAttribLayout(std::span(GLVertexBuffer::GLVertex2DLayout), sizeof(GLVertex2D));
    if (!vertices.empty()) {
        if (auto mapped = vbo->map<GLVertex2D>(vertices.size())) {
            std::memcpy(mapped->data(), vertices.data(), vertices.size() * sizeof(GLVertex2D));
            vbo->unmap(); vbo->bindArrays(); vbo->draw(GL_TRIANGLES, 0, vertices.size()); vbo->unbindArrays();
            ++surface.draws;
            surface.lastResult = "drawn";
        }
    }
    buffer.texture->unbind();
    glBlendFuncSeparate(srcRGB, dstRGB, srcAlpha, dstAlpha);
    glBlendEquationSeparate(equationRGB, equationAlpha);
    if (!blend) glDisable(GL_BLEND);
}
class GlassFactory final : public EffectPluginFactory {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID EffectPluginFactory_iid FILE "metadata.json")
    Q_INTERFACES(KPluginFactory)
public:
    bool isSupported() const override { return GlassEffect::supported(); }
    bool enabledByDefault() const override { return false; }
    Effect *createEffect() const override {
        auto effect = std::make_unique<GlassEffect>();
        return effect->valid() ? effect.release() : nullptr;
    }
};
}
#include "liquidglass.moc"
