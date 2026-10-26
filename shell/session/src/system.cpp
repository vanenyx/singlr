#include "system.h"
#include <QProcess>
#include <QStandardPaths>
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
#include <KService>
#include <KIO/ApplicationLauncherJob>
#include <QMimeDatabase>
#include <pwd.h>
#include <unistd.h>

namespace {
KService::Ptr desktopService(const QUrl &launcher)
{
    if (launcher.scheme() == QLatin1String("applications"))
        return KService::serviceByStorageId(launcher.path());
    if (launcher.isLocalFile() && launcher.fileName().endsWith(QLatin1String(".desktop"))) {
        auto service = KService::serviceByDesktopPath(launcher.toLocalFile());
        if (!service && QFileInfo(launcher.toLocalFile()).isFile())
            service = KService::Ptr(new KService(launcher.toLocalFile()));
        return service;
    }
    return {};
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
    : QObject(parent), m_bus(sessionBus), m_systemBus(systemBus), m_sessionManagement(this)
{
    connect(&m_sessionManagement, &SessionManagement::canSuspendChanged, this, &System::canSuspendChanged);
    connect(&m_sessionManagement, &SessionManagement::canHibernateChanged, this, &System::canHibernateChanged);
    connect(&m_sessionManagement, &SessionManagement::canLockChanged, this, &System::canLockChanged);
    connect(&m_sessionManagement, &SessionManagement::canLogoutChanged, this, &System::canLogoutChanged);
    connect(&m_sessionManagement, &SessionManagement::canRebootChanged, this, &System::canRebootChanged);
    connect(&m_sessionManagement, &SessionManagement::canShutdownChanged, this, &System::canShutdownChanged);
    m_timer.setInterval(10000);
    connect(&m_timer, &QTimer::timeout, this, &System::refreshOverview);
    m_timer.start();
    refreshOverview();
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

// Keep KDE's default confirmation preference and policy. SessionManagement owns
// dispatch; it exposes no per-request completion, error or cancellation signal.
void System::lockScreen() { m_sessionManagement.lock(); }
void System::suspend() { m_sessionManagement.suspend(); }
void System::hibernate() { m_sessionManagement.hibernate(); }
void System::reboot() { m_sessionManagement.requestReboot(); }
void System::powerOff() { m_sessionManagement.requestShutdown(); }
void System::logout() { m_sessionManagement.requestLogout(); }

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
    // Output loss dismisses the layer surface, not the logical QML window.
    // LayerShellQt defaults to QWindow::close() on dismissal, which silently
    // hides a persistent window even when its QML visibility binding stays true.
    // Keep that state intact so remapping also preserves intentional auto-hide.
    auto *layerWindow = LayerShellQt::Window::get(window);
    layerWindow->setCloseOnDismissed(false);
    const bool visible = window->isVisible();
    window->destroy();
    window->setScreen(target);
    // LayerShellQt 6.8 decide la salida con su propia propiedad «screen» (no con QWindow::screen()).
    layerWindow->setScreen(target);
    if (visible)
        window->show();
}

// Resolve the desktop service through sycoca; MIME inheritance is significant
// (e.g. Kate accepts text/x-python through text/plain). Never execute desktop Exec.
bool System::acceptsUrls(const QUrl &launcher, const QList<QUrl> &urls) const
{
    const auto service = desktopService(launcher);
    if (!service || !service->isApplication() || urls.isEmpty()) return false;
    QMimeDatabase database;
    for (const auto &url : urls) {
        // No synchronous network I/O during a drag. Unknown remote content is
        // accepted only when the service explicitly handles that URL scheme.
        if (!url.isValid() || url.isEmpty()) return false;
        if (!url.isLocalFile()) {
            if (!service->hasMimeType(QStringLiteral("x-scheme-handler/") + url.scheme())) return false;
            continue;
        }
        if (!QFileInfo::exists(url.toLocalFile())) return false;
        const auto mime = database.mimeTypeForFile(url.toLocalFile());
        bool accepted = false;
        for (const auto &supported : service->mimeTypes()) {
            if (mime.inherits(supported)) { accepted = true; break; }
        }
        if (!accepted) return false;
    }
    return true;
}

void System::showInFolder(const QList<QUrl> &urls)
{
    if (urls.isEmpty()) return;
    QStringList items;
    for (const auto &url : urls) {
        if (!url.isValid() || !url.isLocalFile()) return;
        items << url.toString();
    }
    auto message = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.FileManager1"),
        QStringLiteral("/org/freedesktop/FileManager1"), QStringLiteral("org.freedesktop.FileManager1"), QStringLiteral("ShowItems"));
    message << items << QString();
    call(m_bus, message, [](const QDBusMessage &reply) {
        if (reply.type() == QDBusMessage::ErrorMessage) qWarning() << "Singlr ShowItems:" << reply.errorMessage();
    });
}

QUrl System::launcherUrl(const QUrl &url) const
{
    const auto service = desktopService(url);
    if (!service || !service->isApplication()) return {};
    QUrl result;
    result.setScheme(QStringLiteral("applications"));
    result.setPath(service->storageId());
    return result;
}

// KService owns locale resolution and Desktop Action metadata (KF6 6.31).
QVariantList System::applicationActions(const QUrl &launcher) const
{
    const auto service = desktopService(launcher);
    QVariantList result;
    if (!service || !service->isApplication()) return result;
    for (const auto &action : service->actions()) {
        if (action.noDisplay() || action.isSeparator() || action.text().isEmpty() || action.exec().isEmpty()) continue;
        result.append(QVariantMap{{QStringLiteral("name"), action.name()},
                                  {QStringLiteral("text"), action.text()},
                                  {QStringLiteral("iconName"), action.icon()}});
    }
    return result;
}

bool System::launchApplicationAction(const QUrl &launcher, const QString &name)
{
    // Resolve again: QML supplies only an action identity, never an Exec command.
    const auto service = desktopService(launcher);
    if (!service || !service->isApplication()) return false;
    for (const auto &action : service->actions()) {
        if (action.name() != name || action.noDisplay() || action.isSeparator()
            || action.text().isEmpty() || action.exec().isEmpty()) continue;
        auto *job = new KIO::ApplicationLauncherJob(action, this);
        connect(job, &KJob::result, this, [this, launcher, name](KJob *job) {
            const QString error = job->error() ? job->errorString() : QString();
            if (!error.isEmpty()) qWarning() << "Singlr application action:" << error;
            Q_EMIT applicationActionFinished(launcher, name, error);
        });
        job->start();
        return true;
    }
    return false;
}


QVariantList System::commandSettingsPages() const
{
    // Expose only pages delivered by the installed app (or the explicit dev checkout).
    if (!KService::serviceByStorageId(QStringLiteral("singlr-settings.desktop"))
        && !QFileInfo::exists(qEnvironmentVariable("SINGLR_DEV_ROOT") + QStringLiteral("/apps/settings/Main.qml"))) return {};
    return {
        QVariantMap{{"page", "appearance"}, {"label", "Apariencia"}, {"keywords", "appearance theme tema oscuro dark claro light color acento accent transparencia transparency animacion motion"}},
        QVariantMap{{"page", "wallpaper"}, {"label", "Fondo de escritorio"}, {"keywords", "wallpaper background fondo imagen"}},
        QVariantMap{{"page", "material"}, {"label", "Material"}, {"keywords", "material glass vidrio solido solid intensidad intensity"}}
    };
}

bool System::openCommandSettings(const QString &page)
{
    if (page != QLatin1String("appearance") && page != QLatin1String("wallpaper") && page != QLatin1String("material")) return false;
    QString program = QStandardPaths::findExecutable(QStringLiteral("singlr-settings"));
    const QString dev = qEnvironmentVariable("SINGLR_DEV_ROOT");
    if (!dev.isEmpty()) program = dev + QStringLiteral("/apps/settings/singlr-settings");
    if (program.isEmpty()) return false;
    // Material is currently a section of Appearance; do not advertise a nonexistent page.
    return QProcess::startDetached(program, page == QLatin1String("wallpaper") ? QStringList{QStringLiteral("--wallpaper")} : QStringList{});
}
