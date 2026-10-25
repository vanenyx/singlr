// SPDX-License-Identifier: GPL-2.0-or-later
#include "../settings.h"
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
        QVERIFY(read().active()); QVERIFY(!read().liquid); // glass default
        appearance.writeEntry("material", "solid"); QVERIFY(!read().active());
        appearance.writeEntry("material", "liquid"); QVERIFY(!read().active());
        effect.writeEntry("Enabled", true); QVERIFY(read().active()); QVERIFY(read().liquid);
        appearance.writeEntry("intensity", 0); QVERIFY(!read().active());
        appearance.writeEntry("intensity", 100); QVERIFY(read().active());
        accessibility.writeEntry("reduceTransparency", true); QVERIFY(!read().active());
        appearance.writeEntry("material", "glass"); QVERIFY(!read().active());
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
