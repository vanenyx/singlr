#include "system.h"
#include <malloc.h>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusReply>
#include <QRegularExpression>
#include <QDBusObjectPath>
#include <QDBusArgument>
#include <QDir>
#include <QFileInfo>
#include <QUrl>
#include <pwd.h>
#include <unistd.h>

namespace {
QDBusMessage loginCall(const QString &method)
{
    return QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.login1"),
        QStringLiteral("/org/freedesktop/login1"), QStringLiteral("org.freedesktop.login1.Manager"), method);
}
bool allowed(const QString &value)
{
    return value == QStringLiteral("yes") || value == QStringLiteral("challenge");
}
QString iconUrl(const QString &path)
{
    return QFileInfo(path).isAbsolute() && QFileInfo(path).isFile() && QFileInfo(path).isReadable()
        ? QUrl::fromLocalFile(path).toString() : QString();
}
}

System::System(QObject *parent)
    : System(QDBusConnection::sessionBus(), QDBusConnection::systemBus(), parent)
{
}

System::System(const QDBusConnection &sessionBus, const QDBusConnection &systemBus, QObject *parent)
    : QObject(parent), m_bus(sessionBus), m_systemBus(systemBus)
{
    m_timer.setInterval(10000);
    connect(&m_timer, &QTimer::timeout, this, &System::refreshOverview);
    connect(&m_timer, &QTimer::timeout, this, &System::refreshCapabilities);
    m_timer.start();
    refreshOverview();
    refreshCapabilities();
    refreshIdentity();
}

void System::refreshOverview()
{
    if (m_pending)
        return;
    m_pending = true;
    auto message = QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"), QStringLiteral("/Effects"),
        QStringLiteral("org.kde.kwin.Effects"), QStringLiteral("isEffectLoaded"));
    message << QStringLiteral("singlr-overview");
    auto *pending = new QDBusPendingCallWatcher(m_bus.asyncCall(message, 1500), this);
    connect(pending, &QDBusPendingCallWatcher::finished, this, [this, pending] {
        const QDBusPendingReply<bool> reply = *pending;
        pending->deleteLater();
        m_pending = false;
        const bool available = !reply.isError() && reply.value();
        if (m_overviewAvailable != available) {
            m_overviewAvailable = available;
            Q_EMIT overviewAvailableChanged();
        }
    });
}

void System::invokeShortcut(const QString &component, const QString &action)
{
    static const QRegularExpression validComponent(QStringLiteral("^[A-Za-z0-9_]+$"));
    if (!validComponent.match(component).hasMatch() || action.isEmpty())
        return;
    auto message = QDBusMessage::createMethodCall(QStringLiteral("org.kde.kglobalaccel"),
        QStringLiteral("/component/") + component, QStringLiteral("org.kde.kglobalaccel.Component"),
        QStringLiteral("invokeShortcut"));
    message << action;
    auto *pending = new QDBusPendingCallWatcher(m_bus.asyncCall(message, 1500), this);
    connect(pending, &QDBusPendingCallWatcher::finished, this, [pending] {
        const QDBusPendingReply<> reply = *pending;
        if (reply.isError())
            qWarning() << "SinglrSystem shortcut:" << reply.error().message();
        pending->deleteLater();
    });
}

void System::trimMemory()
{
    // glibc conserva los bloques liberados; malloc_trim los devuelve al sistema operativo.
    malloc_trim(0);
}

void System::call(const QDBusConnection &bus, const QDBusMessage &message,
                  std::function<void(const QDBusMessage &)> done, int timeout)
{
    if (!bus.isConnected()) {
        QTimer::singleShot(0, this, [done] {
            done(QDBusMessage::createError(QStringLiteral("org.freedesktop.DBus.Error.Disconnected"),
                QStringLiteral("D-Bus connection unavailable")));
        });
        return;
    }
    auto *pending = new QDBusPendingCallWatcher(bus.asyncCall(message, timeout), this);
    connect(pending, &QDBusPendingCallWatcher::finished, this, [pending, done] {
        const auto reply = pending->reply();
        pending->deleteLater();
        done(reply);
    });
}

void System::refreshCapabilities()
{
    if (!m_sessionActionPending) {
        for (bool hibernate : {false, true}) {
            if (!m_capabilityPending[hibernate])
                queryCapability(hibernate);
        }
    }
}

void System::queryCapability(bool hibernate, std::function<void(bool)> done)
{
    m_capabilityPending[hibernate] = true;
    call(m_systemBus, loginCall(hibernate ? QStringLiteral("CanHibernate") : QStringLiteral("CanSuspend")),
         [this, hibernate, done](const QDBusMessage &message) {
        m_capabilityPending[hibernate] = false;
        const QDBusReply<QString> reply(message);
        const bool available = reply.isValid() && allowed(reply.value());
        bool &current = hibernate ? m_canHibernate : m_canSuspend;
        if (current != available) {
            current = available;
            if (hibernate) Q_EMIT canHibernateChanged();
            else Q_EMIT canSuspendChanged();
        }
        if (done) done(available);
    });
}

void System::refreshIdentity()
{
    const auto *user = getpwuid(getuid());
    m_userName = user ? QString::fromLocal8Bit(user->pw_name) : qEnvironmentVariable("USER");
    m_userIcon = iconUrl(QDir::home().filePath(QStringLiteral(".face.icon")));
    auto message = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.Accounts"),
        QStringLiteral("/org/freedesktop/Accounts"), QStringLiteral("org.freedesktop.Accounts"),
        QStringLiteral("FindUserById"));
    message << qint64(getuid());
    call(m_systemBus, message, [this](const QDBusMessage &message) {
        const QDBusReply<QDBusObjectPath> reply(message);
        if (!reply.isValid()) return; // Local account and ~/.face.icon remain usable.
        auto properties = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.Accounts"),
            reply.value().path(), QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("GetAll"));
        properties << QStringLiteral("org.freedesktop.Accounts.User");
        call(m_systemBus, properties, [this](const QDBusMessage &message) {
            const QDBusReply<QVariantMap> reply(message);
            if (!reply.isValid()) return;
            const auto values = reply.value();
            QString name = values.value(QStringLiteral("RealName")).toString().trimmed();
            if (name.isEmpty()) name = values.value(QStringLiteral("UserName")).toString();
            if (!name.isEmpty() && name != m_userName) {
                m_userName = name;
                Q_EMIT userNameChanged();
            }
            const QString icon = iconUrl(values.value(QStringLiteral("IconFile")).toString());
            if (!icon.isEmpty() && icon != m_userIcon) {
                m_userIcon = icon;
                Q_EMIT userIconChanged();
            }
        });
    });
}

bool System::beginAction()
{
    if (m_sessionActionPending) return false;
    m_sessionActionPending = true;
    Q_EMIT sessionActionPendingChanged();
    return true;
}

void System::failAction(const QString &action, const QString &error)
{
    m_sessionActionPending = false;
    Q_EMIT sessionActionPendingChanged();
    qWarning() << "SinglrSystem" << action << error;
    Q_EMIT sessionActionFailed(action, error);
}

void System::finishAction(const QString &action, const QDBusMessage &reply)
{
    if (reply.type() == QDBusMessage::ErrorMessage) {
        failAction(action, reply.errorName() + QStringLiteral(": ") + reply.errorMessage());
        return;
    }
    m_sessionActionPending = false;
    Q_EMIT sessionActionPendingChanged();
}

void System::lockScreen()
{
    if (!beginAction()) return;
    const auto message = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.ScreenSaver"),
        QStringLiteral("/ScreenSaver"), QStringLiteral("org.freedesktop.ScreenSaver"), QStringLiteral("Lock"));
    call(m_bus, message, [this](const QDBusMessage &reply) { finishAction(QStringLiteral("lockScreen"), reply); });
}

void System::sleepAction(bool hibernate)
{
    if (!beginAction()) return;
    const QString action = hibernate ? QStringLiteral("hibernate") : QStringLiteral("suspend");
    // Recheck on invocation: a property cached for the menu is not authorization.
    queryCapability(hibernate, [this, hibernate, action](bool available) {
        if (!available) {
            failAction(action, QStringLiteral("logind: capability unavailable"));
            return;
        }
        auto message = loginCall(hibernate ? QStringLiteral("Hibernate") : QStringLiteral("Suspend"));
        message << true;
        call(m_systemBus, message, [this, action](const QDBusMessage &reply) { finishAction(action, reply); }, 120000);
    });
}

void System::suspend() { sleepAction(false); }
void System::hibernate() { sleepAction(true); }

void System::shutdownOwner(std::function<void(const QString &)> done)
{
    auto message = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.DBus"),
        QStringLiteral("/org/freedesktop/DBus"), QStringLiteral("org.freedesktop.DBus"), QStringLiteral("GetNameOwner"));
    message << QStringLiteral("org.kde.Shutdown");
    call(m_bus, message, [done](const QDBusMessage &message) {
        const QDBusReply<QString> reply(message);
        done(reply.isValid() ? reply.value() : QString());
    });
}

void System::powerAction(bool reboot)
{
    if (!beginAction()) return;
    const QString action = reboot ? QStringLiteral("reboot") : QStringLiteral("powerOff");
    shutdownOwner([this, reboot, action](const QString &owner) {
        if (!owner.isEmpty()) {
            // KDE owns app negotiation and the final logind Reboot/PowerOff(true).
            // Address the unique owner: never auto-start KDE or retry after a timeout.
            auto message = QDBusMessage::createMethodCall(owner, QStringLiteral("/Shutdown"),
                QStringLiteral("org.kde.Shutdown"), reboot ? QStringLiteral("logoutAndReboot") : QStringLiteral("logoutAndShutdown"));
            call(m_bus, message, [this, action](const QDBusMessage &reply) { finishAction(action, reply); }, 120000);
        } else {
            auto message = loginCall(reboot ? QStringLiteral("Reboot") : QStringLiteral("PowerOff"));
            message << true;
            call(m_systemBus, message, [this, action](const QDBusMessage &reply) { finishAction(action, reply); }, 120000);
        }
    });
}

void System::reboot() { powerAction(true); }
void System::powerOff() { powerAction(false); }

void System::terminateSession()
{
    const QString id = qEnvironmentVariable("XDG_SESSION_ID");
    if (id.isEmpty()) {
        failAction(QStringLiteral("logout"), QStringLiteral("XDG_SESSION_ID is missing; refusing to guess a session"));
        return;
    }
    auto message = loginCall(QStringLiteral("TerminateSession"));
    message << id;
    call(m_systemBus, message, [this](const QDBusMessage &reply) { finishAction(QStringLiteral("logout"), reply); }, 120000);
}

void System::logout()
{
    if (!beginAction()) return;
    if (qEnvironmentVariable("XDG_SESSION_DESKTOP") == QStringLiteral("Singlr")) {
        if (qEnvironmentVariableIsEmpty("XDG_SESSION_ID")) {
            failAction(QStringLiteral("logout"), QStringLiteral("XDG_SESSION_ID is missing"));
            return;
        }
        // This stops us too. The login supervisor finishes cleanup, restores the
        // activation environment and terminates the PAM session (including apps).
        auto message = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.systemd1"),
            QStringLiteral("/org/freedesktop/systemd1"), QStringLiteral("org.freedesktop.systemd1.Manager"), QStringLiteral("StopUnit"));
        message << QStringLiteral("singlr-workspace.target") << QStringLiteral("replace");
        call(m_bus, message, [this](const QDBusMessage &reply) {
            if (reply.type() == QDBusMessage::ErrorMessage) finishAction(QStringLiteral("logout"), reply);
            // Successful enqueue is not completion: keep duplicate logout disabled.
        });
        return;
    }
    shutdownOwner([this](const QString &owner) {
        if (owner.isEmpty()) {
            terminateSession();
            return;
        }
        auto message = QDBusMessage::createMethodCall(owner, QStringLiteral("/Shutdown"),
            QStringLiteral("org.kde.Shutdown"), QStringLiteral("logout"));
        call(m_bus, message, [this](const QDBusMessage &reply) { finishAction(QStringLiteral("logout"), reply); }, 120000);
    });
}
