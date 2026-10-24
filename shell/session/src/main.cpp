// Lanzador del shell Singlr: activa layer-shell solo para este proceso y pide a KWin
// el desenfoque de fondo para las ventanas QML que lo declaran.
#include <KWindowEffects>
#include <LayerShellQt/Shell>
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
    for (QWindow *window : QGuiApplication::allWindows())
        if (auto *quick = qobject_cast<QQuickWindow *>(window))
            trackBlur(quick);
    return app.exec();
}
