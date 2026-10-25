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
    // Devuelve al sistema la memoria libre del montículo tras liberar paneles (P-016).
    Q_INVOKABLE void trimMemory();
Q_SIGNALS:
    void overviewAvailableChanged();
private:
    void refreshOverview();
    QDBusConnection m_bus;
    QTimer m_timer;
    bool m_overviewAvailable = false;
    bool m_pending = false;
};
