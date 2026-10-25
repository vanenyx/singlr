// Reproduce the SVG lookup/render contract of kde-gtk-config v6.8.1,
// kded/kwin_bridge/auroraedecorationpainter.cpp, without loading kded or a bus.
#include <QGuiApplication>
#include <QSvgRenderer>
#include <QStandardPaths>
#include <QImage>
#include <QPainter>
#include <QDir>
#include <QFile>
#include <cassert>
#include <iostream>

bool draws(const QString &file, const QString &element) {
    QSvgRenderer renderer(file);
    if (!renderer.isValid() || !renderer.elementExists(element)) return false;
    QImage image(50, 50, QImage::Format_ARGB32); image.fill(Qt::transparent);
    QPainter painter(&image); renderer.render(&painter, element, QRectF(0, 0, 50, 50)); painter.end();
    for (int y = 0; y < 50; ++y) for (int x = 0; x < 50; ++x)
        if (qAlpha(image.pixel(x, y))) return true;
    return false;
}
int main(int argc, char **argv) {
    QGuiApplication app(argc, argv);
    const QString source = QString::fromLocal8Bit(argv[1]);
    const QString user = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/aurorae/themes/Singlr/";
    int sourceDraws = 0, userDraws = 0, copiedDraws = 0;
    for (const auto &file : {"close.svg", "minimize.svg", "maximize.svg", "restore.svg"}) {
        for (const auto &element : {"active-center", "hover-center", "pressed-center", "inactive-center"}) {
            sourceDraws += draws(source + '/' + file, element);
            userDraws += draws(user + file, element);
        }
    }
    QDir().mkpath(user);
    for (const auto &file : {"close.svg", "minimize.svg", "maximize.svg", "restore.svg"}) {
        assert(QFile::copy(source + '/' + file, user + file));
        for (const auto &element : {"active-center", "hover-center", "pressed-center", "inactive-center"})
            copiedDraws += draws(user + file, element);
    }
    std::cout << "system/source=" << sourceDraws << "/16 user-missing=" << userDraws
              << "/16 temporary-user-copy=" << copiedDraws << "/16\n";
    return sourceDraws == 16 && userDraws == 0 && copiedDraws == 16 ? 0 : 1;
}
