#pragma once
#include <QDBusVirtualObject>
#include <QDBusMessage>
#include <QDBusConnection>
#include <QMetaObject>

// Puente de Meta/KRunner, aplicaciones y recarga de ajustes hacia Session.
class LauncherBridge : public QDBusVirtualObject
{
public:
    explicit LauncherBridge(QObject *target)
        : m_target(target)
    {
    }
    bool handleMessage(const QDBusMessage &message, const QDBusConnection &connection) override
    {
        if (message.type() != QDBusMessage::MethodCallMessage || message.interface() == QLatin1String("org.freedesktop.DBus.Introspectable")
            || message.interface() == QLatin1String("org.freedesktop.DBus.Properties"))
            return false;
        const char *method = message.path() == QLatin1String("/PlasmaShell")
                ? (message.member() == QLatin1String("singlrReloadSettings") ? "reloadSettings"
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
};

