// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include "settings.h"
#include <effect/effect.h>
#include <opengl/glshader.h>
#include <opengl/gltexture.h>
#include <opengl/glframebuffer.h>
#include <scene/backgroundeffectitem.h>
#include <map>
#include <KConfigWatcher>

namespace KWin {
class LiquidGlassEffect : public Effect {
    Q_OBJECT
public:
    LiquidGlassEffect();
    ~LiquidGlassEffect() override;
    static bool supported();
    bool valid() const { return bool(m_shader); }
    bool isActive() const override;
    QString debug(const QString &parameter) const override;
    bool blocksDirectScanout() const override { return false; }
    void reconfigure(ReconfigureFlags) override;
    int requestedEffectChainPosition() const override { return 80; } // after native blur
    void prePaintScreen(ScreenPrePaintData &data) override;
    bool drawWindow(const RenderTarget &, const RenderViewport &, EffectWindow *, int, const Region &, WindowPaintData &) override;
private:
    struct Buffer {
        std::unique_ptr<GLTexture> texture;
        std::unique_ptr<GLFramebuffer> framebuffer;
        Rect bounds;
    };
    struct Surface {
        QMetaObject::Connection blurConnection;
        std::unique_ptr<BackgroundEffectItem> item;
        std::map<RenderView *, Buffer> buffers;
        quint64 draws = 0;
        const char *lastResult = "not-drawn";
    };
    void watch(EffectWindow *);
    void update(EffectWindow *);
    bool accepts(EffectWindow *) const;
    void render(const RenderTarget &, const RenderViewport &, EffectWindow *, const Region &);
    KConfigWatcher::Ptr m_watcher;
    SinglrGlass::Settings m_settings;
    std::unique_ptr<GLShader> m_shader;
    std::map<EffectWindow *, Surface> m_surfaces;
    RenderView *m_view = nullptr;
    bool m_diagnosticOverlay = false;
};
}
