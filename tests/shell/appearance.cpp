#include "kdeappearance.h"
#include <QGuiApplication>
#include <QPalette>
#include <QSettings>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QFile>
#include <QDir>
#include <QtTest>

class AppearanceTest : public QObject {
    Q_OBJECT
    QTemporaryDir m_temp;
    QString m_log;
private Q_SLOTS:
    void initTestCase() {
        QVERIFY(m_temp.isValid());
        qputenv("XDG_CONFIG_HOME", m_temp.path().toUtf8());
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
