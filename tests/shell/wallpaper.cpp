#include "wallpaperprovider.h"
#include <QGuiApplication>
#include <QQuickView>
#include <QSGTexture>
#include <QTemporaryDir>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QElapsedTimer>
#include <cassert>

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    QTemporaryDir tmp;
    const QString file = tmp.path() + QStringLiteral("/Fondo #50% á.png");
    QImage source(400, 200, QImage::Format_RGB32);
    source.fill(Qt::red);
    // Only the central square survives PreserveAspectCrop.
    for (int y = 0; y < 200; ++y)
        for (int x = 100; x < 300; ++x)
            source.setPixelColor(x, y, Qt::green);
    assert(source.save(file));
    const QUrl url = QUrl::fromLocalFile(file);
    const QString id = QString::fromLatin1(QUrl::toPercentEncoding(url.toString()));
    SinglrWallpaper::Provider provider;
    QSize size;
    std::unique_ptr<QQuickTextureFactory> factory(provider.requestTexture(id, &size, QSize(64, 64)));
    assert(factory && size == QSize(64, 64));
    assert(factory->image().pixelColor(32, 32) == QColor(Qt::green));
    assert(factory->image().pixelColor(0, 32) == QColor(Qt::green));
    auto *concrete = static_cast<SinglrWallpaper::TextureFactory *>(factory.get());
    assert(concrete->retainedImageBytes() == 64 * 64 * 4);
    assert(!provider.requestTexture(id, &size, QSize()));
    assert(!provider.requestTexture("https://example.com/test", &size, QSize(64, 64)));
    assert(!provider.requestTexture("file:///nonexistent-t239", &size, QSize(64, 64)));

    QQuickWindow window;
    window.resize(64, 64);
    window.show();
    QElapsedTimer timer;
    timer.start();
    while (!window.isSceneGraphInitialized() && timer.elapsed() < 3000)
        app.processEvents();
    assert(window.isSceneGraphInitialized());
    for (int cycle = 0; cycle < 2; ++cycle) {
        std::unique_ptr<QSGTexture> texture(factory->createTexture(&window));
        assert(texture && texture->textureSize() == QSize(64, 64));
        assert(concrete->retainedImageBytes() == 0);
        // image() remains supported without keeping its decoded copy resident.
        assert(factory->image().pixelColor(32, 32) == QColor(Qt::green));
        assert(concrete->retainedImageBytes() == 0);
    }
    // The actual QML URL path must survive Qt's escaping and provider dispatch.
    QQmlEngine engine;
    engine.addImageProvider("singlrwallpaper", new SinglrWallpaper::Provider);
    QQmlComponent component(&engine);
    component.setData(("import QtQuick\nImage { sourceSize: Qt.size(64,64); source: 'image://singlrwallpaper/"
                       + id + "'; cache: false }").toUtf8(), QUrl());
    std::unique_ptr<QObject> image(component.create());
    assert(image);
    timer.restart();
    while (image->property("status").toInt() == 2 && timer.elapsed() < 3000)
        app.processEvents();
    assert(image->property("status").toInt() == 1);
}
