#include "system.h"
#include <LayerShellQt/Window>
#include <QGuiApplication>
#include <QScreen>
#include <QWindow>
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
    : QObject(parent), m_bus(sessionBus), m_systemBus(systemBus),
      m_shutdownWatcher(QStringLiteral("org.kde.Shutdown"), sessionBus,
                        QDBusServiceWatcher::WatchForUnregistration, this)
{
    connect(&m_shutdownWatcher, &QDBusServiceWatcher::serviceUnregistered, this, &System::shutdownFinished);
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
    ++m_actionSerial;
    m_sessionActionPending = true;
    Q_EMIT sessionActionPendingChanged();
    return true;
}

void System::failAction(const QString &action, const QString &error)
{
    m_kdeAction.clear();
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

void System::sessionAction(const QString &action, const QString &method)
{
    if (!beginAction()) return;
    const auto serial = m_actionSerial;
    auto message = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.DBus"),
        QStringLiteral("/org/freedesktop/DBus"), QStringLiteral("org.freedesktop.DBus"), QStringLiteral("GetNameOwner"));
    message << QStringLiteral("org.kde.ksmserver");
    call(m_bus, message, [this, action, method, serial](const QDBusMessage &reply) {
        if (serial != m_actionSerial) return;
        if (reply.type() == QDBusMessage::ErrorMessage) {
            // Only a confirmed absence permits bypassing KDE. A broken bus is
            // not evidence that it is safe to terminate applications directly.
            if (reply.errorName() != QStringLiteral("org.freedesktop.DBus.Error.NameHasNoOwner")) {
                finishAction(action, reply);
                return;
            }
            if (action == QStringLiteral("logout")) {
                terminateSession();
            } else {
                auto direct = loginCall(action == QStringLiteral("reboot") ? QStringLiteral("Reboot") : QStringLiteral("PowerOff"));
                direct << true;
                call(m_systemBus, direct, [this, action](const QDBusMessage &reply) { finishAction(action, reply); }, 120000);
            }
            return;
        }
        m_kdeAction = action;
        // plasma-shutdown is on-demand, unlike ksmserver. Allow its standard
        // D-Bus activation in both installed Singlr and live-on-Plasma sessions.
        auto shutdown = QDBusMessage::createMethodCall(QStringLiteral("org.kde.Shutdown"), QStringLiteral("/Shutdown"),
            QStringLiteral("org.kde.Shutdown"), method);
        call(m_bus, shutdown, [this, action, serial](const QDBusMessage &reply) {
            if (serial != m_actionSerial || m_kdeAction != action) return;
            if (reply.type() == QDBusMessage::ErrorMessage) finishAction(action, reply);
            // The void method reply only acknowledges dispatch. Keep duplicates
            // disabled while applications may be asking the user to save.
        }, 120000);
    });
}

void System::shutdownFinished()
{
    if (m_kdeAction.isEmpty()) return;
    const auto action = m_kdeAction;
    const auto serial = m_actionSerial;
    // Plasma 6.8 exports neither logoutFinished nor logoutCancelled on D-Bus.
    // On cancellation plasma-shutdown exits and ksmserver returns to Idle.
    // Query that public state, without activating a missing session manager.
    auto message = QDBusMessage::createMethodCall(QStringLiteral("org.kde.ksmserver"), QStringLiteral("/KSMServer"),
        QStringLiteral("org.kde.KSMServerInterface"), QStringLiteral("isShuttingDown"));
    message.setAutoStartService(false);
    call(m_bus, message, [this, action, serial](const QDBusMessage &message) {
        if (serial != m_actionSerial || m_kdeAction != action) return;
        const QDBusReply<bool> reply(message);
        if (!reply.isValid()) {
            // Normal completion quits ksmserver before plasma-shutdown. The
            // login supervisor waits for both; there is no destructive retry.
            if (reply.error().type() == QDBusError::ServiceUnknown || reply.error().name() == QStringLiteral("org.freedesktop.DBus.Error.NameHasNoOwner"))
                return;
            finishAction(action, message);
        } else if (!reply.value()) {
            m_kdeAction.clear();
            m_sessionActionPending = false;
            Q_EMIT sessionActionPendingChanged();
            Q_EMIT sessionActionCancelled(action);
        } else {
            failAction(action, QStringLiteral("KDE shutdown exited while the session was still closing"));
        }
    });
}

void System::reboot() { sessionAction(QStringLiteral("reboot"), QStringLiteral("logoutAndReboot")); }
void System::powerOff() { sessionAction(QStringLiteral("powerOff"), QStringLiteral("logoutAndShutdown")); }

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
    sessionAction(QStringLiteral("logout"), QStringLiteral("logout"));
}

void System::placeOnScreen(QObject *object, const QString &screenName)
{
    auto *window = qobject_cast<QWindow *>(object);
    if (!window)
        return;
    QScreen *target = nullptr;
    for (QScreen *screen : QGuiApplication::screens())
        if (screen->name() == screenName)
            target = screen;
    // Siempre se recrea: QML puede haber asignado ya la pantalla sin que la superficie nativa la siga.
    if (!target)
        return;
    const bool visible = window->isVisible();
    window->destroy();
    window->setScreen(target);
    // LayerShellQt 6.8 decide la salida con su propia propiedad «screen» (no con QWindow::screen()).
    LayerShellQt::Window::get(window)->setScreen(target);
    if (visible)
        window->show();
}
