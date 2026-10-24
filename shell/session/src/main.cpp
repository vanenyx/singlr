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
#include <QQuickWindow>
#include <QRegion>
#include <QUrl>

namespace
{
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

// Recibe la tecla Meta (KWin llama a org.kde.plasmashell activateLauncherMenu) y Alt+Espacio
// (KRunner) mientras Singlr sustituye a Plasma, y abre el lanzador de Singlr.
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
        QMetaObject::invokeMethod(m_target, "toggleLauncher", Qt::QueuedConnection);
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

// Atajos globales de volumen y multimedia que registraba plasmashell («kmix» y «mediacontrol»).
// Se registran las mismas acciones cargando el atajo guardado, sin modificarlo.
void registerGlobalActions(QObject *parent, QObject *session)
{
    const QList<std::pair<QString, QStringList>> components = {
        {QStringLiteral("kmix"),
         {QStringLiteral("increase_volume"), QStringLiteral("decrease_volume"), QStringLiteral("increase_volume_small"),
          QStringLiteral("decrease_volume_small"), QStringLiteral("mute"), QStringLiteral("increase_microphone_volume"),
          QStringLiteral("decrease_microphone_volume"), QStringLiteral("mic_mute")}},
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
    // Antes de QGuiApplication; después se retira la variable para que las apps lanzadas usen xdg-shell.
    LayerShellQt::Shell::useLayerShell();
    QGuiApplication app(argc, argv);
    qunsetenv("QT_WAYLAND_SHELL_INTEGRATION");
    app.setApplicationName(QStringLiteral("singlr-shell"));
    app.setDesktopFileName(QStringLiteral("singlr-shell"));
    // Logotipos originales de las apps: hicolor contiene los iconos que instala cada
    // aplicación; los temas tipo WhiteSur los encierran en placas. Breeze cubre lo que falte.
    QIcon::setThemeName(QStringLiteral("hicolor"));
    QIcon::setFallbackThemeName(QStringLiteral("breeze"));

    if (argc < 3) {
        qCritical("uso: singlr-shell <import-path> <Shell.qml> [-- argumentos]");
        return 2;
    }
    QQmlApplicationEngine engine;
    engine.addImportPath(QString::fromLocal8Bit(argv[1]));
    engine.load(QUrl::fromLocalFile(QString::fromLocal8Bit(argv[2])));
    if (engine.rootObjects().isEmpty())
        return 1;
    // Solo en modo sesión: el objeto raíz expone la sesión en su propiedad «surface».
    QObject *session = engine.rootObjects().constFirst()->property("surface").value<QObject *>();
    if (session && session->metaObject()->indexOfMethod("toggleLauncher()") >= 0) {
        auto bus = QDBusConnection::sessionBus();
        auto *bridge = new LauncherBridge(session);
        // Los nombres solo están libres si plasmashell y krunner no se ejecutan.
        if (bus.registerService(QStringLiteral("org.kde.plasmashell")))
            bus.registerVirtualObject(QStringLiteral("/PlasmaShell"), bridge);
        // Meta llega por kglobalaccel como acción del componente «plasmashell». Mientras Plasma está
        // parado, Singlr registra esa misma acción y carga el atajo ya guardado sin modificarlo.
        if (bus.interface()->registeredServiceNames().value().contains(QStringLiteral("org.kde.plasmashell"))
            && bus.interface()->serviceOwner(QStringLiteral("org.kde.plasmashell")).value() == bus.baseService()) {
            auto *action = new QAction(&app);
            action->setObjectName(QStringLiteral("activate application launcher"));
            action->setProperty("componentName", QStringLiteral("plasmashell"));
            action->setText(QStringLiteral("Activar el lanzador de aplicaciones"));
            KGlobalAccel::self()->setShortcut(action, {QKeySequence(Qt::META), QKeySequence(Qt::ALT | Qt::Key_F1)}, KGlobalAccel::Autoloading);
            QObject::connect(action, &QAction::triggered, session, [session] { QMetaObject::invokeMethod(session, "toggleLauncher"); });
            registerGlobalActions(&app, session);
        }
        if (session->metaObject()->indexOfMethod("osdRequest(QVariant,QVariant)") >= 0 && bus.registerService(QStringLiteral("org.kde.osdService")))
            bus.registerVirtualObject(QStringLiteral("/org/kde/osdService"), new OsdBridge(session));
        if (bus.registerService(QStringLiteral("org.kde.krunner"))) {
            bus.registerVirtualObject(QStringLiteral("/App"), bridge);
            bus.registerVirtualObject(QStringLiteral("/org/kde/krunner"), bridge);
        }
    }
    for (QWindow *window : QGuiApplication::allWindows())
        if (auto *quick = qobject_cast<QQuickWindow *>(window))
            trackBlur(quick);
    return app.exec();
}
