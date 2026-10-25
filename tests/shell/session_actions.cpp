#include "system.h"
#include <QCoreApplication>
#include <QDBusVirtualObject>
#include <QDBusObjectPath>
#include <QElapsedTimer>
#include <QFile>
#include <QTemporaryDir>
#include <QThread>
#include <QUrl>
#include <iostream>
#include <stdexcept>

#define CHECK(...) do { if (!(__VA_ARGS__)) throw std::runtime_error("line " + std::to_string(__LINE__) + ": " #__VA_ARGS__); } while (false)

void until(std::function<bool()> condition)
{
    QElapsedTimer timer;
    timer.start();
    while (!condition() && timer.elapsed() < 4000) {
        QCoreApplication::processEvents();
        QThread::msleep(1);
    }
    CHECK(condition());
}

class Fixture : public QDBusVirtualObject {
public:
    QStringList calls;
    QString suspendCapability = "yes", hibernateCapability = "challenge";
    bool deny = false, accounts = true;
    QString icon;
    QString introspect(const QString &) const override { return {}; }
    bool handleMessage(const QDBusMessage &m, const QDBusConnection &bus) override
    {
        calls << m.member();
        QVariantList args;
        if (m.member() == "CanSuspend") args << suspendCapability;
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
        if (app.arguments().contains("--offline")) {
            System system(QDBusConnection("missing-session"), QDBusConnection("missing-system"));
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
            until([&] { return failures == 1; });
            CHECK(!system.sessionActionPending());
            system.suspend();
            until([&] { return failures == 2; });
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
        for (const auto &name : {"org.freedesktop.login1", "org.freedesktop.Accounts", "org.freedesktop.ScreenSaver", "org.freedesktop.systemd1", "org.kde.KWin"})
            CHECK(server.registerService(name));
        System system(client, client);
        int failures = 0;
        QObject::connect(&system, &System::sessionActionFailed, &app, [&](const QString &, const QString &) { ++failures; });
        until([&] { return system.canSuspend() && system.canHibernate() && system.userName() == "Test Person"; });
        CHECK(system.userIcon() == QUrl::fromLocalFile(face.fileName()).toString());
        CHECK(fixture.calls.size() == 5); // only overview, two Can*, Accounts lookup + GetAll
        fixture.calls.clear();
        auto invoke = [&](std::function<void()> action, const QString &method) {
            const int count = fixture.calls.count(method);
            action();
            CHECK(system.sessionActionPending());
            until([&] { return !system.sessionActionPending(); });
            CHECK(fixture.calls.count(method) == count + 1);
        };
        invoke([&] { system.lockScreen(); system.lockScreen(); }, "Lock"); // one in-flight action
        invoke([&] { system.suspend(); }, "Suspend");
        CHECK(fixture.calls.indexOf("CanSuspend") < fixture.calls.indexOf("Suspend"));
        invoke([&] { system.hibernate(); }, "Hibernate");
        fixture.suspendCapability = "no";
        int failed = failures;
        system.suspend();
        until([&] { return failures == failed + 1; });
        CHECK(!system.canSuspend() && fixture.calls.count("Suspend") == 1);
        fixture.hibernateCapability = "na";
        failed = failures;
        system.hibernate();
        until([&] { return failures == failed + 1; });
        CHECK(!system.canHibernate() && fixture.calls.count("Hibernate") == 1);
        invoke([&] { system.reboot(); }, "Reboot");
        invoke([&] { system.powerOff(); }, "PowerOff");
        CHECK(server.registerService("org.kde.Shutdown"));
        invoke([&] { system.reboot(); }, "logoutAndReboot");
        invoke([&] { system.powerOff(); }, "logoutAndShutdown");
        qputenv("XDG_SESSION_DESKTOP", "KDE");
        invoke([&] { system.logout(); }, "logout");
        fixture.deny = true;
        failed = failures;
        invoke([&] { system.powerOff(); }, "logoutAndShutdown");
        CHECK(failures == failed + 1 && fixture.calls.count("PowerOff") == 1); // no destructive retry
        fixture.deny = false;
        CHECK(server.unregisterService("org.kde.Shutdown"));
        qputenv("XDG_SESSION_ID", "singlr-test-session");
        invoke([&] { system.logout(); }, "TerminateSession");
        qunsetenv("XDG_SESSION_ID");
        failed = failures;
        system.logout();
        until([&] { return failures == failed + 1; });
        CHECK(fixture.calls.count("TerminateSession") == 1);
        qputenv("XDG_SESSION_DESKTOP", "Singlr");
        failed = failures;
        system.logout();
        CHECK(failures == failed + 1 && !fixture.calls.contains("StopUnit"));
        qputenv("XDG_SESSION_ID", "singlr-test-session");
        system.logout();
        until([&] { return fixture.calls.contains("StopUnit"); });
        CHECK(system.sessionActionPending());
        CHECK(fixture.calls.count("TerminateSession") == 1); // supervisor, not dying shell, terminates installed session
        fixture.accounts = false;
        System fallback(client, client);
        CHECK(!fallback.userName().isEmpty());
        CHECK(fallback.userIcon() == QUrl::fromLocalFile(face.fileName()).toString());
        until([&] { return fixture.calls.count("FindUserById") == 2; });
        std::cout << "PASS session-actions\n";
    } catch (const std::exception &error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
    return 0;
}
