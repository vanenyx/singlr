#pragma once
#include <QObject>
#include <QPointer>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

class KSystemClipboard;
namespace KWayland::Client { class Registry; class ConnectionThread; class FakeInput; class PlasmaWindowManagement; class PlasmaWindow; }

// Desktop-shell-only, bounded paste action. No generic keyboard injection API.
class ClipboardPasteBridge final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool canPaste READ canPaste NOTIFY changed)
    Q_PROPERTY(bool pending READ pending NOTIFY changed)
public:
    explicit ClipboardPasteBridge(QObject *parent = nullptr);
    bool canPaste() const;
    bool pending() const { return m_pending; }
    Q_INVOKABLE void enable();
    Q_INVOKABLE void captureTarget();
    Q_INVOKABLE void preparePaste();
    Q_INVOKABLE void requestPaste();
    Q_INVOKABLE void cancelIfIdle();
    Q_INVOKABLE void cancel();
Q_SIGNALS:
    void changed();
    void failed(const QString &message);
    void shortcutSent();
private:
    void tryPaste();
    void finish(bool sent);
    KWayland::Client::ConnectionThread *m_connection = nullptr;
    KWayland::Client::Registry *m_registry = nullptr;
    QPointer<KWayland::Client::FakeInput> m_input;
    QPointer<KWayland::Client::PlasmaWindowManagement> m_windows;
    QPointer<KWayland::Client::PlasmaWindow> m_target;
    KSystemClipboard *m_clipboard = nullptr;
    QTimer m_retry;
    QTimer m_timeout;
    bool m_prepared = false;
    bool m_ready = false;
    bool m_pending = false;
};
