// SPDX-License-Identifier: GPL-2.0-or-later
#include "../settings.h"
#include "../../../../shell/session/src/blurregion.h"
#ifdef GLASS_PLUGIN
#include <effect/effect.h>
#endif
#include <QPluginLoader>
#include <KConfig>
#include <QJsonObject>
#include <QTemporaryDir>
#include <QtTest>

class GlassTest : public QObject {
    Q_OBJECT
private Q_SLOTS:
    void defaultsAndReload() {
        QTemporaryDir tmp;
        KConfig config(tmp.filePath("kwinrc"), KConfig::SimpleConfig);
        auto group = config.group("Effect-singlrliquidglass");
        auto settings = SinglrGlass::Settings::read(group);
        QVERIFY(!settings.active()); QCOMPARE(settings.intensity, 65);
        group.writeEntry("Enabled", true); group.writeEntry("Intensity", 130); config.sync();
        config.reparseConfiguration(); settings = SinglrGlass::Settings::read(group);
        QVERIFY(settings.active()); QCOMPARE(settings.intensity, 100);
        group.writeEntry("Intensity", -4); config.sync(); config.reparseConfiguration();
        settings = SinglrGlass::Settings::read(group);
        QCOMPARE(settings.intensity, 0); QVERIFY(!settings.active());
        group.writeEntry("Intensity", 40); group.writeEntry("Enabled", false); config.sync();
        config.reparseConfiguration(); QVERIFY(!SinglrGlass::Settings::read(group).active());
    }
    void surfaceModesAndAccessibility() {
        QTemporaryDir tmp;
        KConfig config(tmp.filePath("settings"), KConfig::SimpleConfig);
        auto effect = config.group("Effect-singlrliquidglass");
        auto appearance = config.group("Appearance");
        auto accessibility = config.group("Accessibility");
        const auto read = [&] { return SinglrGlass::Settings::readSurface(effect, appearance, accessibility); };
        QVERIFY(read().active()); // glass default
        appearance.writeEntry("material", "solid"); QVERIFY(!read().active());
        appearance.writeEntry("material", "liquid"); QVERIFY(read().active()); // legacy fallback
        appearance.writeEntry("material", "invalid"); QVERIFY(!read().active());
        appearance.writeEntry("material", "glass"); QVERIFY(read().active());
        appearance.writeEntry("intensity", 0); QVERIFY(!read().active());
        appearance.writeEntry("intensity", 100); QVERIFY(read().active());
        accessibility.writeEntry("reduceTransparency", true); QVERIFY(!read().active());
        appearance.writeEntry("material", "glass"); QVERIFY(!read().active());
    }
    void nativeRegionContainsWholeCells() {
        for (double radius : {0., 8., 10., 12., 12.5, 14.}) {
            const QSize size(100, 80);
            const auto region = SinglrGlass::roundedBlurRegion(size, radius);
            QCOMPARE(region.boundingRect(), QRect(QPoint(), size));
            for (const QRect &rect : region) for (int y = rect.y(); y < rect.y()+rect.height(); ++y)
                for (int x = rect.x(); x < rect.x()+rect.width(); ++x)
                    for (double dx : {0., 1.}) for (double dy : {0., 1.}) {
                        const double qx = std::abs(x+dx-50) - (50-radius);
                        const double qy = std::abs(y+dy-40) - (40-radius);
                        const double d = std::hypot(std::max(qx,0.),std::max(qy,0.)) + std::min(std::max(qx,qy),0.) - radius;
                        QVERIFY(d <= 1e-9);
                    }
        }
    }
    void radiusRecoveredFromRegion() {
        // The effect reads only the wl_region; it must recover the shell's exact radius.
        for (double radius : {0., 6., 8., 10., 12., 14., 16., 20.}) { // Singlr radius tokens are whole pixels
            const QSize size(300, 200);
            const auto region = SinglrGlass::roundedBlurRegion(size, radius);
            std::vector<int> insets;
            for (int y = 0; y < size.height(); ++y) {
                int inset = size.width();
                for (const QRect &rect : region) if (rect.top() <= y && y < rect.top() + rect.height()) inset = std::min(inset, rect.left());
                if (inset <= 0) break;
                insets.push_back(inset);
            }
            QCOMPARE(SinglrGlass::radiusFromInsets(insets, 100.0), radius);
        }
    }
    void scope() {
        QVERIFY(SinglrGlass::eligible("singlr-shell", true, true));
        QVERIFY(!SinglrGlass::eligible("org.kde.dolphin", true, true));
        QVERIFY(!SinglrGlass::eligible("singlr-shell", false, true));
        QVERIFY(!SinglrGlass::eligible("singlr-shell", true, false));
    }
#ifdef GLASS_PLUGIN
    void pluginFactoryLoads() {
        QPluginLoader loader(QStringLiteral(GLASS_PLUGIN));
        QVERIFY2(loader.load(), qPrintable(loader.errorString()));
        auto *factory = qobject_cast<KWin::EffectPluginFactory *>(loader.instance());
        QVERIFY(factory);
        // Creating an Effect needs KWin's singleton and an active EGL context.
        QCOMPARE(loader.metaData()["MetaData"].toObject()["KPlugin"].toObject()["Id"].toString(), QString("singlr-liquidglass"));
        QVERIFY(loader.unload());
    }
#endif
};
QTEST_GUILESS_MAIN(GlassTest)
#include "config.moc"
