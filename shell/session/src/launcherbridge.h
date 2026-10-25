#pragma once
#include <QDBusVirtualObject>
#include <QDBusMessage>
#include <QDBusConnection>
#include <QMetaObject>
#include <functional>

// Puente de Meta/KRunner, aplicaciones y recarga de ajustes hacia Session.
class LauncherBridge : public QDBusVirtualObject
{
public:
    explicit LauncherBridge(QObject *target, std::function<void()> profile = {})
        : m_target(target), m_profile(std::move(profile))
    {
    }
    bool handleMessage(const QDBusMessage &message, const QDBusConnection &connection) override
    {
        if (message.type() != QDBusMessage::MethodCallMessage || message.interface() == QLatin1String("org.freedesktop.DBus.Introspectable")
            || message.interface() == QLatin1String("org.freedesktop.DBus.Properties"))
            return false;
        if (message.path() == QLatin1String("/PlasmaShell") && message.member() == QLatin1String("singlrProfile")) {
            if (m_profile) {
                m_profile();
                connection.send(message.createReply());
            } else {
                connection.send(message.createErrorReply(QStringLiteral("org.kde.plasmashell.ProfileDisabled"),
                    QStringLiteral("Requiere SINGLR_PROFILE=1")));
            }
            return true;
        }
        const char *method = message.path() == QLatin1String("/PlasmaShell")
                ? (message.member() == QLatin1String("toggleControlCenter") ? "toggleControlCenter"
                   : message.member() == QLatin1String("toggleNotifications") ? "toggleNotifications"
                   : message.member() == QLatin1String("singlrReloadSettings") ? "reloadSettings"
                   : message.member() == QLatin1String("singlrShowApplications") ? "showApplications" : "toggleLauncher")
                : "toggleLauncher";
        const QByteArray signature = QByteArray(method) + "()";
        if (m_target->metaObject()->indexOfMethod(signature.constData()) < 0) {
            connection.send(message.createErrorReply(QStringLiteral("org.kde.plasmashell.MissingMethod"), QString::fromLatin1(signature)));
            return true;
        }
        QMetaObject::invokeMethod(m_target, method, Qt::QueuedConnection);
        connection.send(message.createReply());
        return true;
    }
    QString introspect(const QString &) const override
    {
        return {};
    }

private:
    QObject *m_target;
    std::function<void()> m_profile;
};

