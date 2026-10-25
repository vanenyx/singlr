#include "system.h"
#include <QCoreApplication>
#include <QDBusVirtualObject>
#include <QDBusArgument>
#include <QDBusObjectPath>
#include <QElapsedTimer>
#include <QFile>
#include <QDebug>
#include <QTemporaryDir>
#include <QThread>
#include <QUrl>
#include <iostream>
#include <stdexcept>

#define CHECK(...) do { if (!(__VA_ARGS__)) throw std::runtime_error("line " + std::to_string(__LINE__) + ": " #__VA_ARGS__); } while (false)

void until(std::function<bool()> condition, const QString &expected,
           std::function<QString()> diagnostics = {})
{
    QElapsedTimer timer;
    timer.start();
    while (!condition() && timer.elapsed() < 4000) {
        QCoreApplication::processEvents();
        QThread::msleep(1);
    }
    if (!condition())
        throw std::runtime_error((QString("Timed out waiting for %1. %2")
            .arg(expected, diagnostics ? diagnostics() : QString())).toStdString());
}

class Fixture : public QDBusVirtualObject {
public:
    QStringList calls;
    QStringList received; // Full history survives calls.clear() between test phases.
    QString diagnostics() const
    {
        return "Received D-Bus calls:\n  " + received.join("\n  ");
    }
    QString suspendCapability = "yes", hibernateCapability = "challenge";
    bool deny = false, accounts = true, shuttingDown = false, shutdownService = false;
    QString icon;
    QString introspect(const QString &) const override { return {}; }
    bool handleMessage(const QDBusMessage &m, const QDBusConnection &bus) override
    {
        calls << m.member();
        QString description;
        QDebug(&description) << m;
        received << description;
        QVariantList args;
        if (m.member() == "ShowItems") {
            CHECK(m.path() == "/org/freedesktop/FileManager1");
            CHECK(m.interface() == "org.freedesktop.FileManager1");
            CHECK(m.arguments().size() == 2);
            CHECK(qdbus_cast<QStringList>(m.arguments()[0]).size() == 1);
        } else if (m.member() == "isShuttingDown") {
            CHECK(m.path() == "/KSMServer");
            CHECK(m.interface() == "org.kde.KSMServerInterface");
            // Qt does not expose NO_AUTO_START on received messages; System sets it explicitly.
            args << shuttingDown;
        } else if (m.member() == "CanSuspend") args << suspendCapability;
        else if (m.member() == "CanHibernate") args << hibernateCapability;
        else if (m.member() == "isEffectLoaded") args << false;
        else if (m.member() == "FindUserById") {
            CHECK(m.arguments().size() == 1);
            CHECK(m.arguments()[0].metaType().id() == QMetaType::LongLong);
            if (!accounts) {
                bus.send(m.createErrorReply("org.freedesktop.DBus.Error.UnknownMethod", "no accounts"));
                return true;
            }
            args << QVariant::fromValue(QDBusObjectPath("/org/freedesktop/Accounts/User1000"));
        } else if (m.member() == "GetAll") {
            CHECK(m.arguments() == QVariantList{QString("org.freedesktop.Accounts.User")});
            args << QVariant::fromValue(QVariantMap{{"RealName", "Test Person"}, {"UserName", "test"}, {"IconFile", icon}});
        } else if (m.member() == "StopUnit") {
            CHECK(m.path() == "/org/freedesktop/systemd1");
            CHECK(m.arguments() == (QVariantList{QString("singlr-workspace.target"), QString("replace")}));
            args << QVariant::fromValue(QDBusObjectPath("/job/1"));
        } else if (m.member() == "TerminateSession") {
            CHECK(m.arguments() == QVariantList{QString("singlr-test-session")});
        } else if (m.member() == "Lock") {
            CHECK(m.path() == "/ScreenSaver");
            CHECK(m.interface() == "org.freedesktop.ScreenSaver");
            CHECK(m.arguments().isEmpty());
        } else if (m.interface() == "org.kde.Shutdown") {
            CHECK(m.path() == "/Shutdown");
            CHECK(m.arguments().isEmpty());
            if (shutdownService) {
                QFile record(qEnvironmentVariable("SINGLR_ACTIVATION_RECORD"));
                CHECK(record.open(QIODevice::Append));
                record.write(m.member().toUtf8() + '\n');
                QTimer::singleShot(50, QCoreApplication::instance(), &QCoreApplication::quit);
            }
        } else {
            CHECK(m.interface() == "org.freedesktop.login1.Manager");
            CHECK(m.path() == "/org/freedesktop/login1");
            CHECK(m.arguments() == QVariantList{true});
        }
        if (deny)
            bus.send(m.createErrorReply("org.freedesktop.DBus.Error.AccessDenied", "fixture denied"));
        else
            bus.send(m.createReply(args));
        return true;
    }
};

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    try {
        if (app.arguments().contains("--shutdown-service")) {
            auto bus = QDBusConnection::sessionBus();
            Fixture service;
            service.shutdownService = true;
            CHECK(bus.registerVirtualObject("/Shutdown", &service));
            CHECK(bus.registerService("org.kde.Shutdown"));
            return app.exec();
        }
        if (app.arguments().contains("--offline")) {
            System system(QDBusConnection("missing-session"), QDBusConnection("missing-system"));
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
            int failures = 0;
            QObject::connect(&system, &System::sessionActionFailed, &app,
                [&](const QString &, const QString &) { ++failures; });
            QElapsedTimer timer;
            timer.start();
            while (timer.elapsed() < 50) QCoreApplication::processEvents();
            CHECK(!system.canSuspend() && !system.canHibernate());
            CHECK(!system.userName().isEmpty() && !system.sessionActionPending());
            CHECK(failures == 0); // failed metadata queries do not invoke actions
            for (const auto &method : {"lockScreen()", "suspend()", "hibernate()", "reboot()", "powerOff()", "logout()"})
                CHECK(system.metaObject()->indexOfMethod(method) >= 0);
            for (const auto &property : {"canSuspend", "canHibernate", "userName", "userIcon"})
                CHECK(system.metaObject()->indexOfProperty(property) >= 0);
            system.lockScreen();
            until([&] { return failures == 1; }, "lockScreen failure on disconnected bus");
            CHECK(!system.sessionActionPending());
            system.suspend();
            until([&] { return failures == 2; }, "suspend failure on disconnected bus");
            CHECK(!system.sessionActionPending());
            system.reboot();
            until([&] { return failures == 3; }, "reboot rejects disconnected owner lookup");
            CHECK(!system.sessionActionPending());
            std::cout << "PASS offline\n";
            return 0;
        }
        // Neither the fixture nor System ever opens the real system bus.
        auto server = QDBusConnection::connectToBus(qEnvironmentVariable("DBUS_SESSION_BUS_ADDRESS"), "fixture");
        auto client = QDBusConnection::connectToBus(qEnvironmentVariable("DBUS_SESSION_BUS_ADDRESS"), "client");
        CHECK(server.isConnected() && client.isConnected());
        Fixture fixture;
        QTemporaryDir home;
        CHECK(home.isValid());
        qputenv("HOME", home.path().toUtf8());
        QFile face(home.filePath(".face.icon"));
        CHECK(face.open(QIODevice::WriteOnly)); face.write("fixture"); face.close();
        fixture.icon = face.fileName();
        CHECK(server.registerVirtualObject("/", &fixture, QDBusConnection::SubPath));
        for (const auto &name : {"org.freedesktop.login1", "org.freedesktop.Accounts", "org.freedesktop.ScreenSaver", "org.freedesktop.systemd1", "org.kde.KWin", "org.freedesktop.FileManager1"})
            CHECK(server.registerService(name));
        System system(client, client);
        system.showInFolder({QUrl::fromLocalFile(face.fileName())});
        until([&] { return fixture.calls.contains("ShowItems"); }, "standard FileManager1 ShowItems");
        int failures = 0, cancellations = 0;
        QObject::connect(&system, &System::sessionActionCancelled, &app,
            [&](const QString &action) { CHECK(!action.isEmpty()); ++cancellations; });
        QObject::connect(&system, &System::sessionActionFailed, &app, [&](const QString &, const QString &) { ++failures; });
        auto diagnostics = [&] {
            return fixture.diagnostics() + QString("\nState: canSuspend=%1 canHibernate=%2 userName=%3 pending=%4 failures=%5")
                .arg(system.canSuspend()).arg(system.canHibernate()).arg(system.userName())
                .arg(system.sessionActionPending()).arg(failures);
        };
        until([&] { return system.canSuspend() && system.canHibernate() && system.userName() == "Test Person"; },
              "login1.CanSuspend/CanHibernate replies and Accounts.FindUserById -> Properties.GetAll (Test Person)",
              diagnostics);
        CHECK(system.userIcon() == QUrl::fromLocalFile(face.fileName()).toString());
        fixture.calls.removeAll("ShowItems"); // checked above
        CHECK(fixture.calls.size() == 5); // only overview, two Can*, Accounts lookup + GetAll
        fixture.calls.clear();
        auto invoke = [&](std::function<void()> action, const QString &method) {
            const int count = fixture.calls.count(method);
            action();
            CHECK(system.sessionActionPending());
            until([&] { return !system.sessionActionPending(); }, method + " reply (action no longer pending)", diagnostics);
            if (fixture.calls.count(method) != count + 1)
                throw std::runtime_error((QString("Expected exactly one new D-Bus %1 call; before=%2 after=%3. %4")
                    .arg(method).arg(count).arg(fixture.calls.count(method)).arg(diagnostics())).toStdString());
        };
        invoke([&] { system.lockScreen(); system.lockScreen(); }, "Lock"); // one in-flight action
        invoke([&] { system.suspend(); }, "Suspend");
        CHECK(fixture.calls.indexOf("CanSuspend") < fixture.calls.indexOf("Suspend"));
        invoke([&] { system.hibernate(); }, "Hibernate");
        fixture.suspendCapability = "no";
        int failed = failures;
        system.suspend();
        until([&] { return failures == failed + 1; }, "login1.CanSuspend(no) rejection without another Suspend", diagnostics);
        CHECK(!system.canSuspend() && fixture.calls.count("Suspend") == 1);
        fixture.hibernateCapability = "na";
        failed = failures;
        system.hibernate();
        until([&] { return failures == failed + 1; }, "login1.CanHibernate(na) rejection without another Hibernate", diagnostics);
        CHECK(!system.canHibernate() && fixture.calls.count("Hibernate") == 1);
        invoke([&] { system.reboot(); }, "Reboot");
        invoke([&] { system.powerOff(); }, "PowerOff");
        // ksmserver's presence, not an already running Shutdown helper or
        // XDG_SESSION_DESKTOP, selects the KDE path. Exercise real activation.
        CHECK(server.registerService("org.kde.ksmserver"));
        qputenv("XDG_SESSION_DESKTOP", "Singlr");
        qunsetenv("XDG_SESSION_ID");
        system.logout(); system.logout();
        CHECK(system.sessionActionPending());
        until([&] { return cancellations == 1; }, "on-demand Shutdown activation and confirmed cancellation", diagnostics);
        QFile activationRecord(qEnvironmentVariable("SINGLR_ACTIVATION_RECORD"));
        CHECK(activationRecord.open(QIODevice::ReadOnly));
        CHECK(activationRecord.readAll() == "logout\n");
        CHECK(!system.sessionActionPending());
        CHECK(!fixture.calls.contains("TerminateSession") && !fixture.calls.contains("StopUnit"));
        auto kdeInvoke = [&](std::function<void()> action, const QString &method) {
            CHECK(server.registerService("org.kde.Shutdown"));
            const int count = fixture.calls.count(method), cancelled = cancellations;
            action(); action();
            until([&] { return fixture.calls.count(method) == count + 1; }, method, diagnostics);
            // An immediate void reply is not logout completion. No timer races
            // or hand-written window closes are allowed to advance this state.
            QElapsedTimer delay; delay.start();
            while (delay.elapsed() < 30) QCoreApplication::processEvents();
            CHECK(system.sessionActionPending());
            action();
            CHECK(server.unregisterService("org.kde.Shutdown"));
            until([&] { return cancellations == cancelled + 1; }, "KDE cancellation after " + method, diagnostics);
            CHECK(!system.sessionActionPending() && fixture.calls.count(method) == count + 1);
        };
        for (const auto &desktop : {"Singlr", "KDE"}) {
            qputenv("XDG_SESSION_DESKTOP", desktop);
            kdeInvoke([&] { system.reboot(); }, "logoutAndReboot");
            kdeInvoke([&] { system.powerOff(); }, "logoutAndShutdown");
            kdeInvoke([&] { system.logout(); }, "logout");
        }
        CHECK(server.registerService("org.kde.Shutdown"));
        fixture.deny = true;
        failed = failures;
        invoke([&] { system.powerOff(); }, "logoutAndShutdown");
        CHECK(failures == failed + 1 && fixture.calls.count("PowerOff") == 1); // no destructive retry
        fixture.deny = false;
        // A helper crash with ksmserver still shutting down is an error, never
        // permission to bypass session negotiation through logind.
        fixture.shuttingDown = true;
        system.reboot();
        until([&] { return fixture.calls.count("logoutAndReboot") == 3; }, "reboot dispatched before helper crash", diagnostics);
        failed = failures;
        CHECK(server.unregisterService("org.kde.Shutdown"));
        until([&] { return failures == failed + 1; }, "helper failure while session still closing", diagnostics);
        fixture.shuttingDown = false;
        CHECK(server.unregisterService("org.kde.ksmserver"));
        qputenv("XDG_SESSION_ID", "singlr-test-session");
        invoke([&] { system.logout(); }, "TerminateSession");
        qunsetenv("XDG_SESSION_ID");
        failed = failures;
        system.logout();
        until([&] { return failures == failed + 1; }, "logout failure without XDG_SESSION_ID", diagnostics);
        CHECK(fixture.calls.count("TerminateSession") == 1 && !fixture.calls.contains("StopUnit"));
        // A surviving Shutdown helper alone must not select KDE without ksmserver.
        CHECK(server.registerService("org.kde.Shutdown"));
        invoke([&] { system.reboot(); }, "Reboot");
        CHECK(server.unregisterService("org.kde.Shutdown"));
        fixture.accounts = false;
        const int lookups = fixture.calls.count("FindUserById");
        System fallback(client, client);
        CHECK(!fallback.userName().isEmpty());
        CHECK(fallback.userIcon() == QUrl::fromLocalFile(face.fileName()).toString());
        // The startup calls were cleared above; compare against this phase's baseline.
        until([&] { return fixture.calls.count("FindUserById") == lookups + 1; },
              "one additional Accounts.FindUserById for fallback identity", diagnostics);
        CHECK(server.registerService("org.kde.ksmserver"));
        CHECK(server.registerService("org.kde.Shutdown"));
        const int cancelled = cancellations, logoutCount = fixture.calls.count("logout");
        system.logout();
        until([&] { return fixture.calls.count("logout") == logoutCount + 1; }, "final logout request", diagnostics);
        CHECK(server.unregisterService("org.kde.ksmserver"));
        CHECK(server.unregisterService("org.kde.Shutdown"));
        QElapsedTimer delay; delay.start();
        while (delay.elapsed() < 50) QCoreApplication::processEvents();
        CHECK(system.sessionActionPending() && cancellations == cancelled);
        CHECK(fixture.calls.count("TerminateSession") == 1 && fixture.calls.count("Reboot") == 2);
        std::cout << "PASS session-actions\n";
    } catch (const std::exception &error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
    return 0;
}
