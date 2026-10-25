#pragma once
#include <QImageReader>
#include <QMutex>
#include <QMutexLocker>
#include <QQuickImageProvider>
#include <QQuickWindow>
#include <QUrl>

namespace SinglrWallpaper {
inline QImage decode(const QString &file, const QSize &target)
{
    if (target.isEmpty())
        return {};
    QImageReader reader(file);
    reader.setAutoTransform(true);
    QSize nativeTarget = target;
    if (reader.transformation() & QImageIOHandler::TransformationRotate90)
        nativeTarget.transpose();
    const QSize original = reader.size();
    if (!original.isEmpty())
        reader.setScaledSize(original.scaled(nativeTarget, Qt::KeepAspectRatioByExpanding));
    QImage image = reader.read();
    if (image.isNull())
        return {};
    image = image.scaled(target, Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation);
    image = image.copy((image.width() - target.width()) / 2,
                       (image.height() - target.height()) / 2, target.width(), target.height());
    return image.convertToFormat(QImage::Format_ARGB32_Premultiplied);
}

// Qt's default Image factory retains the decoded QImage after GPU upload.
// A screen-sized wallpaper only needs its texture. Keep the file/size so a new
// scene graph can recreate it after context loss, without retaining a CPU copy.
class TextureFactory final : public QQuickTextureFactory {
public:
    TextureFactory(QString file, QImage image)
        : m_file(std::move(file)), m_size(image.size()), m_image(std::move(image)) {}
    QSize textureSize() const override { return m_size; }
    int textureByteCount() const override { return m_size.width() * m_size.height() * 4; }
    QImage image() const override {
        QMutexLocker lock(&m_lock);
        return m_image.isNull() ? decode(m_file, m_size) : m_image;
    }
    qint64 retainedImageBytes() const { QMutexLocker lock(&m_lock); return m_image.sizeInBytes(); }
    QSGTexture *createTexture(QQuickWindow *window) const override {
        QMutexLocker lock(&m_lock);
        if (m_image.isNull())
            m_image = decode(m_file, m_size);
        auto *texture = window->createTextureFromImage(m_image);
        if (texture)
            m_image = {};
        return texture;
    }
private:
    QString m_file;
    QSize m_size;
    mutable QMutex m_lock;
    mutable QImage m_image;
};

class Provider final : public QQuickImageProvider {
public:
    Provider() : QQuickImageProvider(Texture, ForceAsynchronousImageLoading) {}
    QQuickTextureFactory *requestTexture(const QString &id, QSize *size, const QSize &requested) override {
        const QUrl url(QUrl::fromPercentEncoding(id.toUtf8()));
        if (!url.isLocalFile())
            return nullptr;
        const QString file = url.toLocalFile();
        QImage image = decode(file, requested);
        if (image.isNull())
            return nullptr;
        if (size)
            *size = image.size();
        return new TextureFactory(file, std::move(image));
    }
};
}
