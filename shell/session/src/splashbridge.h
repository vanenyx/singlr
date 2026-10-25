#pragma once
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusServiceWatcher>
#include <QQuickWindow>
#include <QGuiApplication>
#include <utility>

// KSplash counts unique standard stages. Replay only achieved milestones if its
// systemd unit registers late; never let a timer pretend the desktop is ready.
class SplashBridge final : public QObject {
public:
    explicit SplashBridge(QObject *parent) : QObject(parent), m_bus(QDBusConnection::sessionBus()) {
        auto *watcher = new QDBusServiceWatcher(QStringLiteral("org.kde.KSplash"), m_bus,
            QDBusServiceWatcher::WatchForRegistration, this);
        watcher->addWatchedService(QStringLiteral("org.kde.ksmserver"));
        connect(watcher, &QDBusServiceWatcher::serviceRegistered, this, [this] { update(); });
        for (auto *window : QGuiApplication::allWindows()) {
            if (auto *quick = qobject_cast<QQuickWindow *>(window); quick && quick->isVisible())
                m_frames.append(connect(quick, &QQuickWindow::frameSwapped, this, [this] {
                    if (!m_desktop) {
                        m_desktop = true;
                        for (const auto &connection : std::as_const(m_frames)) disconnect(connection);
                        m_frames.clear();
                        update();
                    }
                }, Qt::QueuedConnection));
        }
        update();
    }
private:
    void stage(const QString &name) {
        auto message = QDBusMessage::createMethodCall(QStringLiteral("org.kde.KSplash"), QStringLiteral("/KSplash"),
            QStringLiteral("org.kde.KSplash"), QStringLiteral("setStage"));
        message.setArguments({name});
        m_bus.asyncCall(message);
    }
    void update() {
        if (!m_bus.interface() || !m_bus.interface()->isServiceRegistered(QStringLiteral("org.kde.KSplash"))) return;
        stage(QStringLiteral("startPlasma"));
        if (m_bus.interface()->isServiceRegistered(QStringLiteral("org.kde.ksmserver"))) stage(QStringLiteral("ksmserver"));
        if (m_desktop) stage(QStringLiteral("desktop"));
    }
    QDBusConnection m_bus;
    QList<QMetaObject::Connection> m_frames;
    bool m_desktop = false;
};
