#include "kdeappearance.h"
#include <QGuiApplication>
#include <QPalette>
#include <QSettings>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QFile>
#include <QDir>
#include <QScopeGuard>
#include <QtTest>

class AppearanceTest : public QObject {
    Q_OBJECT
    QTemporaryDir m_temp;
    QString m_log;
private Q_SLOTS:
    void initTestCase() {
        QVERIFY(m_temp.isValid());
        qputenv("XDG_CONFIG_HOME", m_temp.path().toUtf8());
        qputenv("XDG_STATE_HOME", m_temp.filePath("state").toUtf8());
        m_log = m_temp.filePath("calls");
        const auto tools = m_temp.filePath("bin");
        QVERIFY(QDir().mkpath(tools));
        QFile tool(tools + "/plasma-apply-colorscheme");
        QVERIFY(tool.open(QIODevice::WriteOnly));
        tool.write("#!/bin/sh\nprintf '%s\\n' \"$@\" >> \"$SINGLR_TEST_CALLS\"\nexit ${SINGLR_TEST_FAILURE:-0}\n");
        tool.close();
        QVERIFY(tool.setPermissions(QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner));
        qputenv("SINGLR_TEST_CALLS", m_log.toUtf8());
        qputenv("PATH", tools.toUtf8() + ':' + qgetenv("PATH"));
    }
    void cleanup() {
        qunsetenv("SINGLR_TEST_FAILURE");
        QFile::remove(m_log);
        QFile::remove(m_temp.filePath("singlr/singlr.conf"));
    }
    void livePaletteIsAuthoritative() {
        KDEAppearance appearance;
        QSignalSpy changed(&appearance, &KDEAppearance::changed);
        QPalette palette = QGuiApplication::palette();
        palette.setColor(QPalette::Window, QColor("#08090a"));
        palette.setColor(QPalette::Highlight, QColor("#eb5ea9"));
        QGuiApplication::setPalette(palette);
        QTRY_VERIFY(appearance.dark());
        QCOMPARE(appearance.accent(), QColor("#eb5ea9"));
        palette.setColor(QPalette::Window, Qt::white);
        QGuiApplication::setPalette(palette);
        QTRY_VERIFY(!appearance.dark());
        QVERIFY(changed.count() >= 2);
        QVERIFY(!QFile::exists(m_log)); // Reading never applies a default palette.
    }
    void modeAndAccentUseKDE() {
        KDEAppearance appearance;
        appearance.setMode("auto");
        QSettings kde(m_temp.filePath("kdeglobals"), QSettings::IniFormat);
        kde.sync();
        QCOMPARE(kde.value("KDE/AutomaticLookAndFeel").toBool(), true);
        QCOMPARE(appearance.mode(), QString("auto"));
        QVERIFY(!QFile::exists(m_log)); // KDE autoswitcher owns the transition.
        appearance.setMode("light");
        appearance.setAccent("#eb5ea9");
        QCOMPARE(appearance.selectedAccent(), QColor("#eb5ea9"));
        QTRY_VERIFY(!appearance.busy());
        QFile log(m_log); QVERIFY(log.open(QIODevice::ReadOnly));
        QCOMPARE(log.readAll(), QByteArray("BreezeLight\n--accent-color\n#eb5ea9\n"));
        kde.sync();
        QCOMPARE(kde.value("KDE/AutomaticLookAndFeel").toBool(), false);
    }
    void preservesUserAutoThemes() {
        auto config = KSharedConfig::openConfig("kdeglobals");
        auto group = config->group("KDE");
        group.writeEntry("DefaultLightLookAndFeel", "user.light");
        group.writeEntry("DefaultDarkLookAndFeel", "user.dark");
        group.sync();
        KDEAppearance appearance;
        appearance.setMode("auto");
        QCOMPARE(group.readEntry("DefaultLightLookAndFeel", QString()), QString("user.light"));
        QCOMPARE(group.readEntry("DefaultDarkLookAndFeel", QString()), QString("user.dark"));
    }
    void legacyMigrationIsOnceAndKeepsWallpaper() {
        QSettings settings(m_temp.filePath("singlr/singlr.conf"), QSettings::IniFormat);
        settings.setValue("Config/schemaVersion", 1);
        settings.setValue("Appearance/mode", "dark");
        settings.setValue("Appearance/accent", "#5e6ad2");
        settings.setValue("Appearance/wallpaper", "singlr:graphite");
        settings.setValue("Unknown/key", "keep");
        settings.sync();
        { KDEAppearance appearance; QTRY_VERIFY(!appearance.busy()); QVERIFY(appearance.error().isEmpty()); }
        settings.sync();
        QVERIFY(settings.value("Config/kdeAppearanceMigrated").toBool());
        QVERIFY(!settings.contains("Appearance/mode"));
        QCOMPARE(settings.value("Appearance/wallpaper").toString(), QString("singlr:graphite"));
        QCOMPARE(settings.value("Unknown/key").toString(), QString("keep"));
        QFile::remove(m_log);
        KDEAppearance again;
        QVERIFY(!again.busy()); QVERIFY(!QFile::exists(m_log));
    }
    void failedMigrationCanRetry() {
        QSettings settings(m_temp.filePath("singlr/singlr.conf"), QSettings::IniFormat);
        settings.setValue("Appearance/mode", "dark"); settings.sync();
        qputenv("SINGLR_TEST_FAILURE", "1");
        { KDEAppearance appearance; QTRY_VERIFY(!appearance.busy()); QVERIFY(!appearance.error().isEmpty()); }
        settings.sync();
        QVERIFY(settings.contains("Appearance/mode"));
        QVERIFY(!settings.value("Config/kdeAppearanceMigrated").toBool());
    }
    void liquidPreferenceMigratesOnce() {
        auto config = KSharedConfig::openConfig("singlr/singlr.conf", KConfig::SimpleConfig);
        config->group("Appearance").writeEntry("material", "liquid");
        config->group("Appearance").writeEntry("unrelated", "keep"); config->sync();
        KDEAppearance appearance;
        QCOMPARE(appearance.material(), QString("glass"));
        config->reparseConfiguration();
        QCOMPARE(config->group("Appearance").readEntry("material", QString()), QString("glass"));
        QCOMPARE(config->group("Appearance").readEntry("unrelated", QString()), QString("keep"));
        appearance.setMaterial("solid"); appearance.setMaterial("liquid");
        QCOMPARE(appearance.material(), QString("solid"));
        appearance.refreshMaterials(); QCOMPARE(appearance.material(), QString("solid"));
    }
    void materialsPersistClampAndPreserveKDE() {
        QFile kwin(m_temp.filePath("kwinrc"));
        QVERIFY(kwin.open(QIODevice::WriteOnly)); kwin.write("[Plugins]\nblurEnabled=true\n"); kwin.close();
        KDEAppearance appearance;
        QCOMPARE(appearance.material(), QString("glass")); QCOMPARE(appearance.intensity(), 65);
        appearance.setMaterial("glass"); appearance.setIntensity(140); appearance.setReduceTransparency(true);
        QCOMPARE(appearance.material(), QString("glass")); QCOMPARE(appearance.intensity(), 100);
        QVERIFY(appearance.reduceTransparency());
        appearance.setMaterial("invalid"); QCOMPARE(appearance.material(), QString("glass"));
        appearance.setIntensity(-1); QCOMPARE(appearance.intensity(), 0);
        KDEAppearance second;
        QCOMPARE(second.material(), QString("glass")); QVERIFY(second.reduceTransparency());
        QVERIFY(kwin.open(QIODevice::ReadOnly)); QCOMPARE(kwin.readAll(), QByteArray("[Plugins]\nblurEnabled=true\n"));
        kwin.close(); QFile::remove(kwin.fileName());
    }
    void sessionJournalAllowsOnlyMaterialConfigWrites() {
        const auto previous = qgetenv("XDG_SESSION_DESKTOP");
        const auto restore = qScopeGuard([previous] { qputenv("XDG_SESSION_DESKTOP", previous); });
        qputenv("XDG_SESSION_DESKTOP", "Singlr");
        const auto journalPath = m_temp.filePath("state/singlr/kwinrc-backup.json");
        QVERIFY(QDir().mkpath(QFileInfo(journalPath).path()));
        QFile journal(journalPath); QVERIFY(journal.open(QIODevice::WriteOnly)); journal.write("[]"); journal.close();
        const auto removeJournal = qScopeGuard([journalPath] { QFile::remove(journalPath); });
        KDEAppearance appearance;
        appearance.setMaterial("glass"); appearance.setIntensity(42);
        auto config = KSharedConfig::openConfig("kwinrc"); config->reparseConfiguration();
        auto group = config->group("Effect-singlrliquidglass");
        QVERIFY(group.readEntry("Enabled", false)); QCOMPARE(group.readEntry("Intensity", -1), 42);
        appearance.setReduceTransparency(true); config->reparseConfiguration();
        QVERIFY(!group.readEntry("Enabled", true));
        // Persistent settings cannot opt a Plasma session into the effect.
        qputenv("XDG_SESSION_DESKTOP", "plasma"); appearance.setReduceTransparency(false);
        config->reparseConfiguration(); QVERIFY(!group.readEntry("Enabled", true));
    }
    void ignoresNewerSchemasAndInvalidInput() {
        QSettings settings(m_temp.filePath("singlr/singlr.conf"), QSettings::IniFormat);
        settings.setValue("Config/schemaVersion", 99);
        settings.setValue("Appearance/mode", "dark"); settings.sync();
        KDEAppearance appearance;
        appearance.setMode("invalid"); appearance.setAccent("#bad; command");
        QVERIFY(!appearance.busy()); QVERIFY(!QFile::exists(m_log));
        settings.sync(); QVERIFY(settings.contains("Appearance/mode"));
    }
};
QTEST_MAIN(AppearanceTest)
#include "appearance.moc"
