// Lanzador del shell Singlr: activa layer-shell solo para este proceso.
#include <LayerShellQt/Shell>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QUrl>

int main(int argc, char *argv[])
{
    // Debe ejecutarse antes de crear QGuiApplication. Fija QT_WAYLAND_SHELL_INTEGRATION
    // en el entorno del proceso; se retira después para que las apps lanzadas usen xdg-shell.
    LayerShellQt::Shell::useLayerShell();
    QGuiApplication app(argc, argv);
    qunsetenv("QT_WAYLAND_SHELL_INTEGRATION");
    app.setApplicationName(QStringLiteral("singlr-shell"));
    app.setDesktopFileName(QStringLiteral("singlr-shell"));

    if (argc < 3) {
        qCritical("uso: singlr-shell <import-path> <Shell.qml> [-- argumentos]");
        return 2;
    }
    QQmlApplicationEngine engine;
    engine.addImportPath(QString::fromLocal8Bit(argv[1]));
    engine.load(QUrl::fromLocalFile(QString::fromLocal8Bit(argv[2])));
    if (engine.rootObjects().isEmpty())
        return 1;
    return app.exec();
}
