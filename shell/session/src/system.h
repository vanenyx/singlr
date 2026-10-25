#pragma once
#include <QObject>
#include <QUrl>
#include <QVariantList>
#include <QDBusConnection>
#include <QTimer>
#include <QDBusMessage>
#include <QDBusServiceWatcher>
#include <functional>

class System final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool overviewAvailable READ overviewAvailable NOTIFY overviewAvailableChanged)
    Q_PROPERTY(bool canSuspend READ canSuspend NOTIFY canSuspendChanged)
    Q_PROPERTY(bool canHibernate READ canHibernate NOTIFY canHibernateChanged)
    Q_PROPERTY(QString userName READ userName NOTIFY userNameChanged)
    Q_PROPERTY(QString userIcon READ userIcon NOTIFY userIconChanged)
    Q_PROPERTY(bool sessionActionPending READ sessionActionPending NOTIFY sessionActionPendingChanged)
public:
    explicit System(QObject *parent = nullptr);
    // Separate connections allow tests to use only private buses.
    System(const QDBusConnection &sessionBus, const QDBusConnection &systemBus, QObject *parent = nullptr);
    bool overviewAvailable() const { return m_overviewAvailable; }
    bool canSuspend() const { return m_canSuspend; }
    bool canHibernate() const { return m_canHibernate; }
    QString userName() const { return m_userName; }
    QString userIcon() const { return m_userIcon; }
    bool sessionActionPending() const { return m_sessionActionPending; }
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
    void overviewAvailableChanged();
    void canSuspendChanged();
    void canHibernateChanged();
    void userNameChanged();
    void userIconChanged();
    void sessionActionPendingChanged();
    void sessionActionFailed(const QString &action, const QString &message);
    void sessionActionCancelled(const QString &action);
private:
    void refreshOverview();
    void refreshCapabilities();
    void refreshIdentity();
    void queryCapability(bool hibernate, std::function<void(bool)> done = {});
    void call(const QDBusConnection &bus, const QDBusMessage &message,
              std::function<void(const QDBusMessage &)> done, int timeout = 3000);
    void sessionAction(const QString &action, const QString &method);
    void shutdownFinished();
    bool beginAction();
    void finishAction(const QString &action, const QDBusMessage &reply);
    void failAction(const QString &action, const QString &error);
    void sleepAction(bool hibernate);
    void terminateSession();
    QDBusConnection m_bus;
    QDBusConnection m_systemBus;
    QDBusServiceWatcher m_shutdownWatcher;
    QString m_kdeAction;
    quint64 m_actionSerial = 0;
    QTimer m_timer;
    bool m_overviewAvailable = false;
    bool m_pending = false;
    bool m_canSuspend = false;
    bool m_canHibernate = false;
    bool m_sessionActionPending = false;
    bool m_capabilityPending[2] = {false, false};
    QString m_userName;
    QString m_userIcon;
};
