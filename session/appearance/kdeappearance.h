#pragma once
#include <QObject>
#include <QColor>
#include <QProcess>
#include <QQueue>
#include <QLockFile>
#include <KConfigWatcher>
#include <KSharedConfig>
#include <QtQml/qqmlregistration.h>
#include <memory>

class KDEAppearance : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool dark READ dark NOTIFY changed)
    Q_PROPERTY(QColor accent READ accent NOTIFY changed)
    Q_PROPERTY(QColor selectedAccent READ selectedAccent NOTIFY changed)
    Q_PROPERTY(QString mode READ mode NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
public:
    explicit KDEAppearance(QObject *parent = nullptr);
    bool dark() const;
    QColor accent() const;
    QColor selectedAccent() const;
    QString mode() const;
    bool busy() const { return m_process.state() != QProcess::NotRunning || !m_queue.isEmpty(); }
    QString error() const { return m_error; }
    Q_INVOKABLE void setMode(const QString &mode);
    Q_INVOKABLE void setAccent(const QString &accent);
    Q_INVOKABLE void reloadShell();
Q_SIGNALS:
    void changed();
private:
    bool eventFilter(QObject *object, QEvent *event) override;
    void enqueue(const QStringList &command);
    void next();
    void finishMigration();
    void migrate();
    KSharedConfig::Ptr m_config;
    KConfigWatcher::Ptr m_watcher;
    QProcess m_process;
    QQueue<QStringList> m_queue;
    QString m_error;
    bool m_migrating = false;
    std::unique_ptr<QLockFile> m_migrationLock;
};
