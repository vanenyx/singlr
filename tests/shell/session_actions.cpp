#include "system.h"
#include <QCoreApplication>
#include <QDBusVirtualObject>
#include <QDBusArgument>
#include <QDBusObjectPath>
#include <QElapsedTimer>
#include <QFile>
#include <QProcess>
#include <QTemporaryDir>
#include <QThread>
#include <iostream>
#include <stdexcept>

#define CHECK(...) do { if (!(__VA_ARGS__)) throw std::runtime_error("line " + std::to_string(__LINE__) + ": " #__VA_ARGS__); } while (false)

void until(std::function<bool()> condition, const QString &expected)
{
    QElapsedTimer timer;
    timer.start();
    while (!condition() && timer.elapsed() < 4000) {
        QCoreApplication::processEvents();
        QThread::msleep(1);
    }
    if (!condition()) throw std::runtime_error(("Timed out: " + expected).toStdString());
}

// Separate process: libkworkspace's sleep requests synchronously wait for D-Bus.
// Both default Qt buses point at the private test daemon, never the user's buses.
class Fixture : public QDBusVirtualObject {
public:
    QString introspect(const QString &) const override { return {}; }
    bool handleMessage(const QDBusMessage &m, const QDBusConnection &bus) override
    {
        QVariantList args;
        if (m.member().startsWith("Can")) {
            args << (qEnvironmentVariableIsSet("SINGLR_TEST_DENIED") ? "no" :
                (m.member() == "CanHibernate" ? "challenge" : "yes"));
        } else if (m.member() == "isEffectLoaded") args << false;
        else if (m.member() == "FindUserById")
            args << QVariant::fromValue(QDBusObjectPath("/org/freedesktop/Accounts/User1000"));
        else if (m.member() == "GetAll")
            args << QVariant::fromValue(QVariantMap{{"RealName", "Test Person"}});
        else {
            QFile record(qEnvironmentVariable("SINGLR_ACTIVATION_RECORD"));
            CHECK(record.open(QIODevice::Append));
            record.write((m.interface() + " " + m.path() + " " + m.member() + " "
                          + (m.arguments().isEmpty() ? "none" : m.arguments().first().toString()) + "\n").toUtf8());
        }
        bus.send(m.createReply(args));
        return true;
    }
};

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    try {
        if (app.arguments().contains("--service")) {
            auto bus = QDBusConnection::sessionBus();
            Fixture fixture;
            CHECK(bus.registerVirtualObject("/", &fixture, QDBusConnection::SubPath));
            for (const auto &name : {"org.freedesktop.login1", "org.freedesktop.Accounts",
                 "org.freedesktop.ScreenSaver", "org.kde.KWin", "org.kde.LogoutPrompt", "org.kde.Shutdown"})
                CHECK(bus.registerService(name));
            std::cout << "READY" << std::endl;
            return app.exec();
        }
        if (app.arguments().contains("--gui-test")) {
            CHECK(qEnvironmentVariableIntValue("PLASMA_SESSION_GUI_TEST") == 1);
            System system;
            CHECK(system.canSuspend() && system.canHibernate());
            system.suspend(); system.hibernate();
            CHECK(!system.sessionActionPending());
            std::cout << "PASS KDE test backend\n";
            return 0;
        }
        if (app.arguments().contains("--offline")) {
            System system;
            QTemporaryDir files;
            CHECK(files.isValid());
            const auto write = [&](const QString &name, const QByteArray &contents) {
                QFile file(files.filePath(name)); CHECK(file.open(QIODevice::WriteOnly));
                CHECK(file.write(contents) == contents.size());
                return QUrl::fromLocalFile(file.fileName());
            };
            const auto editor = write("editor.desktop", "[Desktop Entry]\nType=Application\nName=Editor\nExec=/bin/true %U\nMimeType=text/plain;\n");
            const auto folders = write("folders.desktop", "[Desktop Entry]\nType=Application\nName=Files\nExec=/bin/true %U\nMimeType=inode/directory;\n");
            const auto text = write("sample.txt", "plain text\n");
            const auto python = write("sample.py", "#!/usr/bin/python3\nprint(42)\n");
            const auto image = write("sample.png", QByteArray::fromHex("89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c489"));
            CHECK(system.acceptsUrls(editor, {text, python})); // inherited text/x-python
            CHECK(!system.acceptsUrls(editor, {text, image})); // all URLs must match
            CHECK(!system.acceptsUrls(editor, {}));
            CHECK(!system.acceptsUrls(QUrl("applications:singlr-nonexistent.desktop"), {text}));
            CHECK(!system.acceptsUrls(editor, {QUrl("https://example.org/file.txt")}));
            CHECK(!system.acceptsUrls(editor, {QUrl::fromLocalFile(files.filePath("missing.txt"))}));
            CHECK(system.acceptsUrls(folders, {QUrl::fromLocalFile(files.path())}));
            CHECK(!system.acceptsUrls(folders, {text}));
            SessionManagement kde;
            until([&] { return kde.state() != SessionManagement::State::Loading; }, "offline backend loaded");
            CHECK(system.canSuspend() == kde.canSuspend());
            CHECK(system.canHibernate() == kde.canHibernate());
            CHECK(system.canLock() == kde.canLock());
            CHECK(system.canLogout() == kde.canLogout());
            CHECK(system.canReboot() == kde.canReboot());
            CHECK(system.canShutdown() == kde.canShutdown());
            CHECK(!system.canSuspend() && !system.canHibernate());
            CHECK(!system.userName().isEmpty() && !system.sessionActionPending());
            for (const auto &method : {"lockScreen()", "suspend()", "hibernate()", "reboot()", "powerOff()", "logout()"})
                CHECK(system.metaObject()->indexOfMethod(method) >= 0);
            for (const auto &property : {"canSuspend", "canHibernate", "canLock", "canLogout", "canReboot", "canShutdown", "userName", "userIcon"})
                CHECK(system.metaObject()->indexOfProperty(property) >= 0);
            system.suspend(); system.hibernate(); system.reboot(); system.powerOff();
            CHECK(!system.sessionActionPending());
            std::cout << "PASS offline\n";
            return 0;
        }
        QProcess service;
        service.start(app.applicationFilePath(), {"--service"});
        CHECK(service.waitForStarted());
        CHECK(service.waitForReadyRead());
        CHECK(service.readAllStandardOutput().contains("READY"));
        System system;
        SessionManagement kde;
        int capabilityChanges = 0, cancellations = 0;
        QObject::connect(&system, &System::canSuspendChanged, &app, [&] { ++capabilityChanges; });
        QObject::connect(&system, &System::sessionActionCancelled, &app, [&] { ++cancellations; });
        until([&] { return kde.state() != SessionManagement::State::Loading && system.userName() == "Test Person"; }, "capabilities and identity");
        CHECK(capabilityChanges > 0);
        CHECK(system.canSuspend() == kde.canSuspend());
        CHECK(system.canHibernate() == kde.canHibernate());
        CHECK(system.canReboot() == kde.canReboot());
        CHECK(system.canShutdown() == kde.canShutdown());
        CHECK(system.canLogout() == kde.canLogout());
        CHECK(system.canLock() == kde.canLock());
        const bool denied = qEnvironmentVariableIsSet("SINGLR_TEST_DENIED");
        CHECK(system.canSuspend() != denied && system.canHibernate() != denied);
        const auto history = [] {
            QFile record(qEnvironmentVariable("SINGLR_ACTIVATION_RECORD"));
            return record.open(QIODevice::ReadOnly) ? QString::fromUtf8(record.readAll()) : QString();
        };
        const auto invoke = [&](std::function<void()> action, const QString &expected) {
            action();
            until([&] { return history().contains(expected); }, expected);
            CHECK(!system.sessionActionPending());
        };
        invoke([&] { system.lockScreen(); }, "org.freedesktop.ScreenSaver /ScreenSaver Lock none");
        if (denied) {
            system.suspend(); system.hibernate(); system.reboot(); system.powerOff();
            QCoreApplication::processEvents();
            CHECK(!history().contains("Suspend") && !history().contains("Hibernate") && !history().contains("Reboot"));
        } else {
            invoke([&] { system.suspend(); }, "org.freedesktop.login1.Manager /org/freedesktop/login1 Suspend true");
            invoke([&] { system.hibernate(); }, "org.freedesktop.login1.Manager /org/freedesktop/login1 Hibernate true");
            if (app.arguments().contains("--skip-confirmation")) {
                invoke([&] { system.reboot(); }, "org.kde.Shutdown /Shutdown logoutAndReboot none");
                invoke([&] { system.powerOff(); }, "org.kde.Shutdown /Shutdown logoutAndShutdown none");
            } else {
                invoke([&] { system.reboot(); }, "org.kde.LogoutPrompt /LogoutPrompt promptReboot none");
                invoke([&] { system.powerOff(); }, "org.kde.LogoutPrompt /LogoutPrompt promptShutDown none");
            }
        }
        const QString logout = app.arguments().contains("--skip-confirmation")
            ? "org.kde.Shutdown /Shutdown logout none" : "org.kde.LogoutPrompt /LogoutPrompt promptLogout none";
        invoke([&] { system.logout(); }, logout);
        // No ksmserver registered. Like Plasma, dispatch still goes to KDE's
        // helper; no alternate session termination or fabricated cancellation.
        invoke([&] { system.logout(); }, logout);
        CHECK(cancellations == 0);
        CHECK(!history().contains("Terminate") && !history().contains("isShuttingDown"));
        service.terminate();
        CHECK(service.waitForFinished());
        std::cout << "PASS session-actions\n";
    } catch (const std::exception &error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
