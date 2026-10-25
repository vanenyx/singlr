// Load/compile only: instantiating Workspace requires a live KWin compositor.
#include <QGuiApplication>
#include <QLibrary>
#include <QQmlComponent>
#include <QQmlEngine>
#include <cstdio>

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    if (argc != 2) {
        std::fprintf(stderr, "Usage: check-load /absolute/path/main.qml\n");
        return 2;
    }
    QLibrary kwin("/usr/lib/libkwin.so.6");
    if (!kwin.load()) {
        std::fprintf(stderr, "%s\n", qPrintable(kwin.errorString()));
        return 2;
    }
    QQmlEngine engine;
    QQmlComponent component(&engine, QUrl::fromLocalFile(QString::fromLocal8Bit(argv[1])));
    while (component.isLoading()) {
        app.processEvents();
    }
    for (const auto &error : component.errors()) {
        std::fprintf(stderr, "%s\n", qPrintable(error.toString()));
    }
    std::fprintf(stderr, "Component status: %d (Ready=1)\n", int(component.status()));
    return component.isReady() ? 0 : 1;
}
