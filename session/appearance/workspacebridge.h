#pragma once
#include <QObject>
#include <QDBusConnection>
#include <QtQml/qqmlregistration.h>

// The shell opts in; importing Singlr.Ui from KWin never exports a shell endpoint.
class WorkspaceBridge : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_CLASSINFO("D-Bus Interface", "org.singlr.Workspace")
public:
    explicit WorkspaceBridge(QObject *parent = nullptr) : QObject(parent) {}
    ~WorkspaceBridge() override {
        if (m_exported) QDBusConnection::sessionBus().unregisterObject(QStringLiteral("/SinglrWorkspace"));
    }
    Q_INVOKABLE bool enable() {
        if (!m_exported)
            m_exported = QDBusConnection::sessionBus().registerObject(QStringLiteral("/SinglrWorkspace"), this,
                QDBusConnection::ExportAllSlots);
        return m_exported;
    }
public Q_SLOTS:
    void search(const QString &text, const QString &screenName) { Q_EMIT searchRequested(text, screenName); }
Q_SIGNALS:
    void searchRequested(const QString &text, const QString &screenName);
private:
    bool m_exported = false;
};
