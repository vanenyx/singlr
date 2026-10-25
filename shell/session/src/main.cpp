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
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QRegion>
#include <QUrl>
#include "secretagent.h"
#include "tray.h"
#include "system.h"
#include "shortcuts.h"
#include "launcherbridge.h"
#include <QCoreApplication>
#include <QTimer>
#include <QScopeGuard>
#include <QJsonArray>
#include <QJsonObject>
#include <QJsonDocument>
#include <csignal>
#include <malloc.h>
#include <QLoggingCategory>
#include <QSocketNotifier>
#include <sys/socket.h>
#include <unistd.h>
#include "configmigration.h"
#include "wallpaperprovider.h"

Q_LOGGING_CATEGORY(shellLog, "singlr.shell")

namespace
{
int quitSockets[2] = {-1, -1};
void requestQuit(int) {
    const int saved = errno;
    const char byte = 1;
    const auto ignored = ::write(quitSockets[1], &byte, 1);
    (void)ignored;
    errno = saved;
}
// Región con esquinas redondeadas para que el desenfoque no asome fuera del radio.
QRegion roundedRegion(const QSize &size, int radius)
{
    QRegion region(0, 0, size.width(), size.height());
    if (radius <= 0)
        return region;
    const int d = radius * 2;
    const QRect corners[] = {{0, 0, radius, radius},
                             {size.width() - radius, 0, radius, radius},
                             {0, size.height() - radius, radius, radius},
                             {size.width() - radius, size.height() - radius, radius, radius}};
    const QRect ellipses[] = {{0, 0, d, d},
                              {size.width() - d, 0, d, d},
                              {0, size.height() - d, d, d},
                              {size.width() - d, size.height() - d, d, d}};
    for (int i = 0; i < 4; ++i)
        region -= QRegion(corners[i]).subtracted(QRegion(ellipses[i], QRegion::Ellipse));
    return region;
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
    const bool enabled = window->property("singlrBlur").toBool();
    const int radius = window->property("singlrBlurRadius").toInt();
    KWindowEffects::enableBlurBehind(window, enabled, roundedRegion(window->size(), radius));
}

void trackBlur(QQuickWindow *window)
{
    if (!window->property("singlrBlur").isValid())
        return;
    const auto update = [window] { applyBlur(window); };
    QObject::connect(window, &QWindow::widthChanged, window, update);
    QObject::connect(window, &QWindow::heightChanged, window, update);
    QObject::connect(window, &QWindow::visibleChanged, window, update);
    update();
}
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
        engine.rootContext()->setContextProperty(QStringLiteral("SinglrSecrets"), new SecretAgent(&engine));
        auto *tray = new Tray(&engine);
        engine.addImageProvider(QStringLiteral("singlrtray"), tray->createImageProvider());
        engine.rootContext()->setContextProperty(QStringLiteral("SinglrTray"), tray);
    }
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
    return app.exec();
}
