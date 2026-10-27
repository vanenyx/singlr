// Lanzador del shell Singlr: activa layer-shell solo para este proceso y pide a KWin
// el desenfoque de fondo para las ventanas QML que lo declaran.
#include <KGlobalAccel>
#include <KWindowEffects>
#include <QAction>
#include <LayerShellQt/Shell>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusVirtualObject>
#include <QGuiApplication>
#include <QMetaProperty>
#include <QEvent>
#include <QTimer>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QRegion>
#include <QUrl>
#include "tray.h"
#include "system.h"
#include "shortcuts.h"
#include "launcherbridge.h"
#include "splashbridge.h"
#include <QCoreApplication>
#include <QScopeGuard>
#include <QJsonArray>
#include <QJsonObject>
#include <QJsonDocument>
#include <csignal>
#include <malloc.h>
#include <EGL/egl.h>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QLoggingCategory>
#include <QSocketNotifier>
#include <sys/socket.h>
#include <unistd.h>
#include "configmigration.h"
#include "blurregion.h"
#include "wallpaperprovider.h"

Q_LOGGING_CATEGORY(shellLog, "singlr.shell")

namespace
{
// True only when KWin can only be rendering on a non-NVIDIA GPU: no explicit
// device choice (KWIN_DRM_DEVICES/KWIN_RENDER_NODES), the boot VGA device is not
// NVIDIA and no NVIDIA card drives a connected output.
bool compositorOnMesaGpu()
{
    if (qEnvironmentVariableIsSet("KWIN_DRM_DEVICES") || qEnvironmentVariableIsSet("KWIN_RENDER_NODES"))
        return false;
    const QDir drm(QStringLiteral("/sys/class/drm"));
    const auto driverOf = [&drm](const QString &card) {
        return QFileInfo(drm.filePath(card + QStringLiteral("/device/driver"))).symLinkTarget().section(QLatin1Char('/'), -1);
    };
    bool bootVgaFound = false;
    for (const QString &entry : drm.entryList({QStringLiteral("card*")}, QDir::Dirs | QDir::System)) {
        const QString card = entry.section(QLatin1Char('-'), 0, 0);
        const bool nvidia = driverOf(card).startsWith(QLatin1String("nvidia"));
        if (entry != card) {
            QFile status(drm.filePath(entry + QStringLiteral("/status")));
            if (nvidia && status.open(QIODevice::ReadOnly) && status.readAll().trimmed() == "connected")
                return false;
            continue;
        }
        QFile bootVga(drm.filePath(card + QStringLiteral("/device/boot_vga")));
        if (bootVga.open(QIODevice::ReadOnly) && bootVga.readAll().trimmed() == "1") {
            if (nvidia || driverOf(card).isEmpty())
                return false;
            bootVgaFound = true;
        }
    }
    return bootVgaFound;
}
// libglvnd loads every installed EGL vendor. On a hybrid laptop whose panel is
// driven by a Mesa GPU, NVIDIA's EGL library still initialises inside the shell
// and keeps ~11 MB it never uses. Load only Mesa's vendor when the compositor
// cannot be rendering on NVIDIA; in any mixed or explicit setup keep them all. glvnd reads the variable once, on the first EGL call, so it
// is removed right after and never reaches the applications the shell starts.
void selectEglVendor()
{
    if (qEnvironmentVariableIsSet("__EGL_VENDOR_LIBRARY_FILENAMES") || qEnvironmentVariableIsSet("__EGL_VENDOR_LIBRARY_DIRS"))
        return;
    if (!compositorOnMesaGpu())
        return;
    QStringList dirs{QStringLiteral("/etc/glvnd/egl_vendor.d")};
    QStringList dataDirs = QStandardPaths::standardLocations(QStandardPaths::GenericDataLocation);
    dataDirs << QStringLiteral("/usr/share");
    for (const QString &data : std::as_const(dataDirs))
        dirs << data + QStringLiteral("/glvnd/egl_vendor.d");
    for (const QString &dir : std::as_const(dirs))
        for (const QFileInfo &json : QDir(dir).entryInfoList({QStringLiteral("*.json")}, QDir::Files, QDir::Name)) {
            QFile file(json.filePath());
            if (!file.open(QIODevice::ReadOnly) || !file.readAll().contains("libEGL_mesa"))
                continue;
            qputenv("__EGL_VENDOR_LIBRARY_FILENAMES", QFile::encodeName(json.filePath()));
            eglQueryString(EGL_NO_DISPLAY, EGL_EXTENSIONS);
            qunsetenv("__EGL_VENDOR_LIBRARY_FILENAMES");
            return;
        }
}
int quitSockets[2] = {-1, -1};
void requestQuit(int) {
    const int saved = errno;
    const char byte = 1;
    const auto ignored = ::write(quitSockets[1], &byte, 1);
    (void)ignored;
    errno = saved;
}
// org.kde.osdService: PowerDevil y otros servicios piden aquí el indicador en pantalla
// (brillo, volumen…). Lo atendía plasmashell; Singlr lo reenvía a Session.osdRequest().
class OsdBridge : public QDBusVirtualObject
{
public:
    explicit OsdBridge(QObject *target)
        : m_target(target)
    {
    }
    bool handleMessage(const QDBusMessage &message, const QDBusConnection &connection) override
    {
        if (message.type() != QDBusMessage::MethodCallMessage || message.interface().startsWith(QLatin1String("org.freedesktop.DBus.")))
            return false;
        QMetaObject::invokeMethod(m_target, "osdRequest", Qt::QueuedConnection, Q_ARG(QVariant, message.member()), Q_ARG(QVariant, message.arguments()));
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

// Atajos multimedia que registraba plasmashell («mediacontrol»). El volumen («kmix») lo atiende
// el módulo kded audioshortcutsservice de KDE, que además pide el OSD a org.kde.osdService.
// Se registran las mismas acciones cargando el atajo guardado, sin modificarlo.
void registerGlobalActions(QObject *parent, QObject *session)
{
    const QList<std::pair<QString, QStringList>> components = {
        {QStringLiteral("mediacontrol"),
         {QStringLiteral("playpausemedia"), QStringLiteral("playmedia"), QStringLiteral("pausemedia"), QStringLiteral("stopmedia"),
          QStringLiteral("nextmedia"), QStringLiteral("previousmedia"), QStringLiteral("seekforwardmedia"),
          QStringLiteral("seekbackwardmedia"), QStringLiteral("mediavolumeup"), QStringLiteral("mediavolumedown")}},
    };
    const bool handles = session->metaObject()->indexOfMethod("globalAction(QVariant,QVariant)") >= 0;
    for (const auto &[component, names] : components) {
        for (const QString &name : names) {
            auto *action = new QAction(parent);
            action->setObjectName(name);
            action->setProperty("componentName", component);
            KGlobalAccel::self()->setShortcut(action, {}, KGlobalAccel::Autoloading);
            if (handles)
                QObject::connect(action, &QAction::triggered, session, [session, component, name] {
                    QMetaObject::invokeMethod(session, "globalAction", Q_ARG(QVariant, component), Q_ARG(QVariant, name));
                });
        }
    }
}

void applyBlur(QQuickWindow *window)
{
    // Only a mapped window has a live wl_surface. Updating the background effect of a
    // hidden or destroyed surface is a protocol error that makes KWin drop the client.
    // A hidden surface loses its region with it; the Show event applies it again.
    if (!window->handle() || !window->isVisible())
        return;
    const bool enabled = window->property("singlrBlur").toBool()
        && QQuickWindow::graphicsApi() != QSGRendererInterface::Software;
    const double radius = window->property("singlrBlurRadius").toDouble();
    const auto requested = window->property("singlrBlurRect");
    const QRect bounds = requested.isValid() ? requested.toRectF().toAlignedRect().intersected(QRect(QPoint(), window->size()))
                                            : QRect(QPoint(), window->size());
    const auto region = SinglrGlass::roundedBlurRegion(bounds.size(), radius).translated(bounds.topLeft());
    KWindowEffects::enableBlurBehind(window, enabled && !region.isEmpty(), region);
}

void trackBlur(QQuickWindow *window)
{
    if (!window->property("singlrBlur").isValid()) return;
    if (window->property("_singlrBlurTracked").toBool()) { applyBlur(window); return; }
    window->setProperty("_singlrBlurTracked", true);
    const auto update = [window] { applyBlur(window); };
    QObject::connect(window, &QWindow::widthChanged, window, update);
    QObject::connect(window, &QWindow::heightChanged, window, update);
    QObject::connect(window, &QWindow::visibleChanged, window, update);
    // QML property bindings change in place: sizes need not change to disable transparency.
    const auto updateMethod = window->metaObject()->indexOfProperty("singlrBlur");
    const auto regionMethod = window->metaObject()->indexOfProperty("singlrBlurRect");
    const auto radiusMethod = window->metaObject()->indexOfProperty("singlrBlurRadius");
    auto *refresh = new QTimer(window);
    refresh->setSingleShot(true); refresh->setInterval(0);
    QObject::connect(refresh, &QTimer::timeout, window, update);
    const auto start = refresh->metaObject()->method(refresh->metaObject()->indexOfSlot("start()"));
    for (const int index : {updateMethod, radiusMethod, regionMethod}) {
        if (index >= 0 && window->metaObject()->property(index).hasNotifySignal())
            QObject::connect(window, window->metaObject()->property(index).notifySignal(), refresh, start);
    }
    update();
}
// DeferredLoader creates and destroys native windows after engine.load(). Track
// their Show event as well as the initial surfaces, with no polling timer.
class BlurTracker final : public QObject {
public:
    using QObject::QObject;
protected:
    bool eventFilter(QObject *object, QEvent *event) override {
        if (event->type() == QEvent::Show)
            if (auto *window = qobject_cast<QQuickWindow *>(object)) trackBlur(window);
        return false;
    }
};
}

int main(int argc, char *argv[])
{
    for (int i = 1; i < argc; ++i) {
        if (QByteArray(argv[i]) == "--restore-shortcuts") {
            QCoreApplication app(argc, argv);
            return SinglrShortcuts::restoreKWin() ? 0 : 1;
        }
    }
    // Antes de QGuiApplication; después se retira la variable para que las apps lanzadas usen xdg-shell.
    const bool profile = qEnvironmentVariable("SINGLR_PROFILE") == QLatin1String("1");
    if (profile)
        qputenv("QSG_INFO", "1");
    LayerShellQt::Shell::useLayerShell();
    // The shell belongs to the workspace target, not the saved application
    // session. In particular it must survive app negotiation until KDE commits
    // logout, including when another application cancels it.
    QCoreApplication::setAttribute(Qt::AA_DisableSessionManager);
    // Screen-sized images (wallpaper decode, scaling, crop) are freed right after
    // upload. glibc then raises its dynamic mmap threshold and keeps later large
    // blocks in arenas it never returns: ~60 MB for a 2560x1600 wallpaper.
    // A fixed threshold returns them to the system (P-016).
    mallopt(M_MMAP_THRESHOLD, 128 * 1024);
    selectEglVendor();
    QGuiApplication app(argc, argv);
    // Like plasmashell: outputs vanish briefly on resume or hotplug and the
    // per-screen windows go with them; that must not end the shell.
    app.setQuitOnLastWindowClosed(false);
    qunsetenv("QT_WAYLAND_SHELL_INTEGRATION");
    if (::socketpair(AF_UNIX, SOCK_STREAM | SOCK_NONBLOCK | SOCK_CLOEXEC, 0, quitSockets) != 0) {
        qCCritical(shellLog) << "Cannot install shutdown signal notifier";
        return 1;
    }
    QSocketNotifier quitNotifier(quitSockets[0], QSocketNotifier::Read);
    QObject::connect(&quitNotifier, &QSocketNotifier::activated, &app, [&app, &quitNotifier] {
        quitNotifier.setEnabled(false);
        app.quit();
    });
    std::signal(SIGTERM, requestQuit);
    std::signal(SIGINT, requestQuit);
    app.setApplicationName(QStringLiteral("singlr-shell"));
    app.setDesktopFileName(QStringLiteral("singlr-shell"));
    if (!SinglrConfig::migrate()) {
        qCCritical(shellLog) << "Cannot migrate configuration" << SinglrConfig::path();
        return 1;
    }
    // Logotipos originales de las apps: hicolor contiene los iconos que instala cada
    // aplicación; los temas tipo WhiteSur los encierran en placas. Breeze cubre lo que falte.
    QIcon::setThemeName(QStringLiteral("hicolor"));
    QIcon::setFallbackThemeName(QStringLiteral("breeze"));

    if (argc < 3) {
        qCCritical(shellLog, "uso: singlr-shell <import-path> <Shell.qml> [-- argumentos]");
        return 2;
    }
    QQmlApplicationEngine engine;
    engine.addImageProvider(QStringLiteral("singlrwallpaper"), new SinglrWallpaper::Provider);
    engine.rootContext()->setContextProperty(QStringLiteral("SinglrWallpaperProvider"), true);
    engine.addImportPath(QString::fromLocal8Bit(argv[1]));
    auto bus = QDBusConnection::sessionBus();
    const bool takeover = !app.arguments().contains(QStringLiteral("--windowed"))
        && !app.arguments().contains(QStringLiteral("--no-takeover"));
    const bool ownsPlasma = takeover && bus.registerService(QStringLiteral("org.kde.plasmashell"));
    if (takeover && !ownsPlasma) {
        qCCritical(shellLog) << "Cannot acquire org.kde.plasmashell; refusing a partial or duplicate shell";
        return 1;
    }
    bool shortcutsCleanupDone = false;
    const auto cleanupShortcuts = [ownsPlasma, &shortcutsCleanupDone] {
        if (!ownsPlasma || shortcutsCleanupDone)
            return;
        shortcutsCleanupDone = true;
        if (!SinglrShortcuts::restoreKWin())
            qCWarning(shellLog, "Backup de atajos pendiente; reintente --restore-shortcuts");
    };
    const auto restoreShortcuts = qScopeGuard(cleanupShortcuts);
    QObject::connect(&app, &QCoreApplication::aboutToQuit, &app, cleanupShortcuts);
    if (ownsPlasma) {
        engine.rootContext()->setContextProperty(QStringLiteral("SinglrSystem"), new System(&engine));
        auto *tray = new Tray(&engine);
        engine.addImageProvider(QStringLiteral("singlrtray"), tray->createImageProvider());
        engine.rootContext()->setContextProperty(QStringLiteral("SinglrTray"), tray);
    }
    BlurTracker blurTracker(&app);
    app.installEventFilter(&blurTracker);
    engine.load(QUrl::fromLocalFile(QString::fromLocal8Bit(argv[2])));
    if (engine.rootObjects().isEmpty()) {
        qCCritical(shellLog) << "Cannot load shell QML" << argv[2];
        return 1;
    }
    // Solo en modo sesión: el objeto raíz expone la sesión en su propiedad «surface».
    const auto dumpProfile = [&engine] {
        QJsonArray windows;
        for (QWindow *window : QGuiApplication::allWindows()) {
            if (auto *quick = qobject_cast<QQuickWindow *>(window)) {
                windows.append(QJsonObject{{"class", QString::fromLatin1(quick->metaObject()->className())},
                    {"name", quick->objectName()}, {"visible", quick->isVisible()},
                    {"width", quick->width()}, {"height", quick->height()},
                    {"dpr", quick->devicePixelRatio()}, {"sceneGraphInitialized", quick->isSceneGraphInitialized()}});
            }
        }
        QJsonArray roots;
        for (QObject *root : engine.rootObjects())
            roots.append(QJsonObject{{"class", QString::fromLatin1(root->metaObject()->className())},
                {"liveQObjectDescendants", root->findChildren<QObject *>().size()}});
        const QJsonObject report{{"windows", windows}, {"roots", roots},
            {"textureBytes", QJsonValue::Null}, {"qmlActiveTimers", QJsonValue::Null},
            {"limitations", "Qt public API has no total texture bytes or QML timer registry; QSG_INFO logs backend diagnostics. QObject counts are live ownership descendants, not QML allocations."}};
        qInfo().noquote() << "SINGLR_PROFILE" << QJsonDocument(report).toJson(QJsonDocument::Compact);
    };
    if (profile) {
        QTimer::singleShot(0, &app, dumpProfile);
        QTimer::singleShot(20000, &app, dumpProfile);
    }
    QObject *session = engine.rootObjects().constFirst()->property("surface").value<QObject *>();
    if (session && session->metaObject()->indexOfMethod("toggleLauncher()") >= 0) {
        auto *bridge = new LauncherBridge(session, profile ? std::function<void()>(dumpProfile) : std::function<void()>());
        // Los nombres solo están libres si plasmashell y krunner no se ejecutan.
        if (ownsPlasma)
            bus.registerVirtualObject(QStringLiteral("/PlasmaShell"), bridge);
        // Meta llega por kglobalaccel como acción del componente «plasmashell». Mientras Plasma está
        // parado, Singlr registra esa misma acción y carga el atajo ya guardado sin modificarlo.
        if (ownsPlasma) {
            auto *action = new QAction(&app);
            action->setObjectName(QStringLiteral("activate application launcher"));
            action->setProperty("componentName", QStringLiteral("plasmashell"));
            action->setText(QStringLiteral("Activar el lanzador de aplicaciones"));
            KGlobalAccel::self()->setShortcut(action, {QKeySequence(Qt::META), QKeySequence(Qt::ALT | Qt::Key_F1)}, KGlobalAccel::Autoloading);
            QObject::connect(action, &QAction::triggered, session, [session] { QMetaObject::invokeMethod(session, "toggleLauncher"); });
            registerGlobalActions(&app, session);
            SinglrShortcuts::registerActions(&app, session);
        }
        if (session->metaObject()->indexOfMethod("osdRequest(QVariant,QVariant)") >= 0 && bus.registerService(QStringLiteral("org.kde.osdService")))
            bus.registerVirtualObject(QStringLiteral("/org/kde/osdService"), new OsdBridge(session));
        if (bus.registerService(QStringLiteral("org.kde.krunner"))) {
            bus.registerVirtualObject(QStringLiteral("/App"), bridge);
            bus.registerVirtualObject(QStringLiteral("/org/kde/krunner"), bridge);
        }
    }
    if (ownsPlasma) {
        if (!SinglrShortcuts::applyKWin())
            qCWarning(shellLog, "No se pudieron aplicar los atajos KWin; se restaurará el backup al salir");
    }
    for (QWindow *window : QGuiApplication::allWindows())
        if (auto *quick = qobject_cast<QQuickWindow *>(window))
            trackBlur(quick);
    if (ownsPlasma) new SplashBridge(&app);
    return app.exec();
}
