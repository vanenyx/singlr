#include "system.h"
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QRegularExpression>

System::System(QObject *parent) : QObject(parent), m_bus(QDBusConnection::sessionBus())
{
    m_timer.setInterval(10000);
    connect(&m_timer, &QTimer::timeout, this, &System::refreshOverview);
    m_timer.start();
    refreshOverview();
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
