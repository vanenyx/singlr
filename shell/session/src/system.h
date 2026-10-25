#pragma once
#include <QObject>
#include <QDBusConnection>
#include <QTimer>

class System final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool overviewAvailable READ overviewAvailable NOTIFY overviewAvailableChanged)
public:
    explicit System(QObject *parent = nullptr);
    bool overviewAvailable() const { return m_overviewAvailable; }
    Q_INVOKABLE void invokeShortcut(const QString &component, const QString &action);
Q_SIGNALS:
    void overviewAvailableChanged();
private:
    void refreshOverview();
    QDBusConnection m_bus;
    QTimer m_timer;
    bool m_overviewAvailable = false;
    bool m_pending = false;
};
