#pragma once
#include <QObject>
#include <QUrl>
#include <QVariantList>
#include <QDBusConnection>
#include <QTimer>
#include <QDBusMessage>
#include <sessionmanagement.h>
#include <functional>

class System final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool canLock READ canLock NOTIFY canLockChanged)
    Q_PROPERTY(bool canLogout READ canLogout NOTIFY canLogoutChanged)
    Q_PROPERTY(bool canReboot READ canReboot NOTIFY canRebootChanged)
    Q_PROPERTY(bool canShutdown READ canShutdown NOTIFY canShutdownChanged)
    Q_PROPERTY(bool canSuspend READ canSuspend NOTIFY canSuspendChanged)
    Q_PROPERTY(bool canHibernate READ canHibernate NOTIFY canHibernateChanged)
    Q_PROPERTY(QString userName READ userName NOTIFY userNameChanged)
    Q_PROPERTY(QString userIcon READ userIcon NOTIFY userIconChanged)
    Q_PROPERTY(bool sessionActionPending READ sessionActionPending NOTIFY sessionActionPendingChanged)
public:
    explicit System(QObject *parent = nullptr);
    // Metadata connections can be injected; KDE SessionManagement uses Qt default buses.
    System(const QDBusConnection &sessionBus, const QDBusConnection &systemBus, QObject *parent = nullptr);
    bool canSuspend() const { return m_sessionManagement.canSuspend(); }
    bool canHibernate() const { return m_sessionManagement.canHibernate(); }
    QString userName() const { return m_userName; }
    QString userIcon() const { return m_userIcon; }
    // Compatibility only: KDE does not expose the lifetime of individual requests.
    bool sessionActionPending() const { return false; }
    bool canLock() const { return m_sessionManagement.canLock(); }
    bool canLogout() const { return m_sessionManagement.canLogout(); }
    bool canReboot() const { return m_sessionManagement.canReboot(); }
    bool canShutdown() const { return m_sessionManagement.canShutdown(); }
    Q_INVOKABLE QVariantList commandSettingsPages() const;
    Q_INVOKABLE bool openCommandSettings(const QString &page);
    Q_INVOKABLE QUrl launcherUrl(const QUrl &url) const;
    Q_INVOKABLE QVariantList applicationActions(const QUrl &launcher) const;
    Q_INVOKABLE bool launchApplicationAction(const QUrl &launcher, const QString &name);
    Q_INVOKABLE bool acceptsUrls(const QUrl &launcher, const QList<QUrl> &urls) const;
    Q_INVOKABLE void showInFolder(const QList<QUrl> &urls);
    Q_INVOKABLE void lockScreen();
    Q_INVOKABLE void suspend();
    Q_INVOKABLE void hibernate();
    Q_INVOKABLE void reboot();
    Q_INVOKABLE void powerOff();
    Q_INVOKABLE void logout();
    Q_INVOKABLE void invokeShortcut(const QString &component, const QString &action);
    // Devuelve al sistema la memoria libre del montículo tras liberar paneles (P-016).
    Q_INVOKABLE void trimMemory();
    // LayerShellQt crea la superficie al procesar sus propiedades adjuntas, antes de que QML asigne
    // Window.screen: se recrea la superficie nativa en la pantalla indicada.
    Q_INVOKABLE void placeOnScreen(QObject *window, const QString &screenName);
Q_SIGNALS:
    void applicationActionFinished(const QUrl &launcher, const QString &name, const QString &error);
    void canLockChanged();
    void canLogoutChanged();
    void canRebootChanged();
    void canShutdownChanged();
    void canSuspendChanged();
    void canHibernateChanged();
    void userNameChanged();
    void userIconChanged();
    void sessionActionPendingChanged();
    // Legacy signals retained for QML consumers; KDE has no equivalent to forward.
    void sessionActionFailed(const QString &action, const QString &message);
    void sessionActionCancelled(const QString &action);
private:
    void refreshIdentity();
    void call(const QDBusConnection &bus, const QDBusMessage &message,
              std::function<void(const QDBusMessage &)> done, int timeout = 3000);
    QDBusConnection m_bus;
    QDBusConnection m_systemBus;
    SessionManagement m_sessionManagement;
    QString m_userName;
    QString m_userIcon;
};
