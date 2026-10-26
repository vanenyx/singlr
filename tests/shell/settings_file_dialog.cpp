#include <QApplication>
#include <QQmlApplicationEngine>
#include <QTemporaryDir>
#include <QSettings>
#include <QImage>
#include <QDir>
#include <QSignalSpy>
#include <KFileWidget>
#include <QtTest>

class FileDialogTest : public QObject {
    Q_OBJECT
    QQmlApplicationEngine engine;
    QObject *dialog = nullptr;
    QUrl imageUrl;
    KFileWidget *picker() {
        for (auto *widget : QApplication::allWidgets())
            if (auto *file = qobject_cast<KFileWidget *>(widget); file && file->isVisible()) return file;
        return nullptr;
    }
    QString storedWallpaper() {
        QSettings settings(qEnvironmentVariable("XDG_CONFIG_HOME") + "/singlr/singlr.conf", QSettings::IniFormat);
        return settings.value("Appearance/wallpaper").toString();
    }
private Q_SLOTS:
    void initTestCase() {
        engine.addImportPath(QStringLiteral(SINGLR_SOURCE_ROOT "/shell/qml"));
        engine.load(QUrl::fromLocalFile(QStringLiteral(SINGLR_SOURCE_ROOT "/apps/settings/Main.qml")));
        QVERIFY(!engine.rootObjects().isEmpty());
        dialog = engine.rootObjects().first()->findChild<QObject *>("wallpaperFileDialog");
        QVERIFY(dialog);
        const QString folder = qEnvironmentVariable("XDG_DATA_HOME") + "/Pictures";
        QVERIFY(QDir().mkpath(folder));
        imageUrl = QUrl::fromLocalFile(folder + QString::fromUtf8("/imagen de prueba #á.png"));
        QImage image(32, 32, QImage::Format_RGB32); image.fill(Qt::blue);
        QVERIFY(image.save(imageUrl.toLocalFile()));
        QVERIFY(dialog->setProperty("currentFolder", QUrl::fromLocalFile(folder)));
    }
    void nativeSelectionIsSaved() {
        QSignalSpy accepted(dialog, SIGNAL(accepted()));
        QVERIFY(accepted.isValid());
        QVERIFY(QMetaObject::invokeMethod(dialog, "open"));
        QTRY_VERIFY(picker()); // Fails if Qt Quick's generic fallback is used.
        auto *file = picker();
        file->setSelectedUrl(imageUrl);
        const auto capture = qEnvironmentVariable("SINGLR_PICKER_CAPTURE");
        if (!capture.isEmpty()) QVERIFY(file->window()->grab().save(capture));
        file->slotOk();
        QTRY_COMPARE(accepted.count(), 1);
        QTRY_COMPARE(QUrl(storedWallpaper()), imageUrl);
    }
    void nativeCancelPreservesWallpaper() {
        const QString before = storedWallpaper();
        QSignalSpy rejected(dialog, SIGNAL(rejected()));
        QVERIFY(QMetaObject::invokeMethod(dialog, "open"));
        QTRY_VERIFY(picker());
        auto *file = picker();
        file->setSelectedUrl(QUrl::fromLocalFile(imageUrl.toLocalFile() + ".other"));
        QVERIFY(QMetaObject::invokeMethod(file->window(), "reject"));
        QTRY_COMPARE(rejected.count(), 1);
        QCOMPARE(storedWallpaper(), before);
    }
};

int main(int argc, char **argv) {
    // All KDE preferences, thumbnails, recent places and wallpaper writes are disposable.
    QTemporaryDir temp;
    if (!temp.isValid()) return 2;
    for (const char *name : {"XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME", "XDG_STATE_HOME", "XDG_RUNTIME_DIR"}) {
        const QByteArray path = temp.path().toUtf8() + '/' + name;
        QDir().mkpath(QString::fromUtf8(path));
        QFile::setPermissions(QString::fromUtf8(path), QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner);
        qputenv(name, path);
    }
    qputenv("DBUS_SESSION_BUS_ADDRESS", "unix:path=/nonexistent");
    qputenv("DBUS_SYSTEM_BUS_ADDRESS", "unix:path=/nonexistent");
    qputenv("QT_QPA_PLATFORM", "offscreen");
    qputenv("QT_QPA_PLATFORMTHEME", "kde");
    qputenv("QT_QUICK_BACKEND", "software");
    qputenv("QT_FORCE_STDERR_LOGGING", "1");
    QApplication app(argc, argv);
    FileDialogTest test;
    return QTest::qExec(&test, argc, argv);
}
#include "settings_file_dialog.moc"
