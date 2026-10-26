#include "clipboardpastebridge.h"
#include <KWayland/Client/connection_thread.h>
#include <KWayland/Client/registry.h>
#include <KWayland/Client/fakeinput.h>
#include <KWayland/Client/plasmawindowmanagement.h>
#include <KSystemClipboard>
#include <KService>
#include <QGuiApplication>
#include <QClipboard>
#include <linux/input-event-codes.h>

using namespace KWayland::Client;

ClipboardPasteBridge::ClipboardPasteBridge(QObject *parent) : QObject(parent) {
    m_retry.setInterval(15);
    m_timeout.setSingleShot(true); m_timeout.setInterval(1500);
    connect(&m_retry, &QTimer::timeout, this, &ClipboardPasteBridge::tryPaste);
    connect(&m_timeout, &QTimer::timeout, this, [this] { finish(false); });
}
bool ClipboardPasteBridge::canPaste() const {
    return m_input && m_input->isValid() && m_windows && m_target && m_clipboard;
}
void ClipboardPasteBridge::enable() {
    if (m_registry || !QGuiApplication::platformName().startsWith(QLatin1String("wayland"))) return;
    m_connection = ConnectionThread::fromApplication(this);
    if (!m_connection) return;
    m_clipboard = KSystemClipboard::instance();
    if (!m_clipboard) return;
    connect(m_clipboard, &KSystemClipboard::changed, this, [this](QClipboard::Mode mode) {
        if (!m_prepared || mode != QClipboard::Clipboard) return;
        // Klipper restores history asynchronously. Wait for our new selection,
        // without reading or retaining its text/image payload here.
        m_ready = m_clipboard->ownsClipboard();
        if (m_pending && !m_ready) finish(false);
        else if (m_pending) tryPaste();
    });
    connect(qGuiApp, &QGuiApplication::focusWindowChanged, this, [this] { if (m_pending) tryPaste(); });
    m_registry = new Registry(this);
    connect(m_registry, &Registry::fakeInputAnnounced, this, [this](quint32 name, quint32 version) {
        if (version < 4) return;
        m_input = m_registry->createFakeInput(name, version, this);
        m_input->authenticate(QStringLiteral("Singlr"), QStringLiteral("Paste the user-selected clipboard history entry"));
        connect(m_input, &FakeInput::removed, this, [this] { cancel(); m_input = nullptr; Q_EMIT changed(); });
        Q_EMIT changed();
    });
    connect(m_registry, &Registry::plasmaWindowManagementAnnounced, this, [this](quint32 name, quint32 version) {
        m_windows = m_registry->createPlasmaWindowManagement(name, version, this);
        connect(m_windows, &PlasmaWindowManagement::activeWindowChanged, this, [this] { if (m_pending) tryPaste(); });
        connect(m_windows, &PlasmaWindowManagement::removed, this, [this] { cancel(); m_windows = nullptr; Q_EMIT changed(); });
        Q_EMIT changed();
    });
    m_registry->create(m_connection); m_registry->setup();
}
void ClipboardPasteBridge::captureTarget() {
    cancel(); enable();
    if (!m_windows || QGuiApplication::focusWindow()) return;
    auto *window = m_windows->activeWindow();
    if (window && window->pid() != quint32(QCoreApplication::applicationPid())) m_target = window;
    Q_EMIT changed();
}
void ClipboardPasteBridge::preparePaste() {
    m_prepared = canPaste(); m_ready = false;
}
void ClipboardPasteBridge::requestPaste() {
    if (!m_prepared || !canPaste()) { finish(false); return; }
    m_pending = true;
    m_timeout.start(); m_retry.start(); Q_EMIT changed();
    // Queued: the QML handler still has to close and unmap its layer surface.
    QMetaObject::invokeMethod(this, &ClipboardPasteBridge::tryPaste, Qt::QueuedConnection);
}
void ClipboardPasteBridge::cancelIfIdle() { if (!m_pending) cancel(); }
void ClipboardPasteBridge::cancel() {
    m_retry.stop(); m_timeout.stop(); m_pending = false; m_prepared = false;
    m_ready = false; m_target = nullptr; Q_EMIT changed();
}
void ClipboardPasteBridge::finish(bool sent) {
    cancel();
    if (sent) Q_EMIT shortcutSent();
    else Q_EMIT failed(QStringLiteral("Entrada seleccionada. No se pudo pegar automáticamente; usa el pegado de la aplicación de destino."));
}
void ClipboardPasteBridge::tryPaste() {
    if (!m_pending) return;
    if (!canPaste()) { finish(false); return; }
    const auto *active = m_windows->activeWindow();
    if (active && active != m_target && active->pid() != quint32(QCoreApplication::applicationPid())) {
        finish(false); return; // Never redirect a paste to a different app.
    }
    if (!m_ready || active != m_target || QGuiApplication::focusWindow()
        || QGuiApplication::queryKeyboardModifiers() != Qt::NoModifier) return;
    const auto service = KService::serviceByDesktopName(m_target->appId());
    const bool terminal = service && service->categories().contains(QLatin1String("TerminalEmulator"));
    m_input->requestKeyboardKeyPress(KEY_LEFTCTRL);
    if (terminal) m_input->requestKeyboardKeyPress(KEY_LEFTSHIFT);
    m_input->requestKeyboardKeyPress(KEY_V); m_input->requestKeyboardKeyRelease(KEY_V);
    if (terminal) m_input->requestKeyboardKeyRelease(KEY_LEFTSHIFT);
    m_input->requestKeyboardKeyRelease(KEY_LEFTCTRL);
    m_connection->flush();
    finish(true);
}
