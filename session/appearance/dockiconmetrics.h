#pragma once
#include <QObject>
#include <QIcon>
#include <QImage>
#include <QCache>
#include <QRectF>
#include <QUrl>
#include <QVariant>
#include <QtQml/qqmlregistration.h>

// Measures transparent margins once; Kirigami remains the icon renderer.
class DockIconMetrics final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
public:
    explicit DockIconMetrics(QObject *parent = nullptr) : QObject(parent) {}
    static QRectF visibleRect(const QImage &source) {
        const auto image = source.convertToFormat(QImage::Format_ARGB32);
        int left = image.width(), top = image.height(), right = -1, bottom = -1;
        for (int y = 0; y < image.height(); ++y) {
            const auto *row = reinterpret_cast<const QRgb *>(image.constScanLine(y));
            for (int x = 0; x < image.width(); ++x) if (qAlpha(row[x]) != 0) {
                left = qMin(left, x); top = qMin(top, y);
                right = qMax(right, x); bottom = qMax(bottom, y);
            }
        }
        if (right < left || bottom < top) return {0, 0, 1, 1};
        return {double(left) / image.width(), double(top) / image.height(),
                double(right - left + 1) / image.width(), double(bottom - top + 1) / image.height()};
    }
    Q_INVOKABLE QRectF contentRect(const QVariant &source) {
        QIcon icon;
        if (source.canConvert<QIcon>()) icon = source.value<QIcon>();
        else {
            const QString name = source.toString();
            const QUrl url(name);
            if (url.isLocalFile()) icon = QIcon(url.toLocalFile());
            else if (name.startsWith('/') || name.startsWith(QLatin1String(":"))) icon = QIcon(name);
            else if (url.scheme().isEmpty()) icon = QIcon::fromTheme(name);
        }
        if (icon.isNull()) return {0, 0, 1, 1};
        const auto key = icon.cacheKey();
        if (const auto *cached = m_cache.object(key)) return *cached;
        const auto image = icon.pixmap(128, 128).toImage();
        auto rect = visibleRect(image);
        // Kirigami aspect-fits a rectangular pixmap in a square icon item.
        const double side = qMax(image.width(), image.height());
        if (side > 0) rect = {((side - image.width()) / 2 + rect.x() * image.width()) / side,
                             ((side - image.height()) / 2 + rect.y() * image.height()) / side,
                             rect.width() * image.width() / side, rect.height() * image.height() / side};
        m_cache.insert(key, new QRectF(rect));
        return rect;
    }
private:
    // Store rectangles, not pixmaps; bounded across app/icon replacement.
    QCache<qint64, QRectF> m_cache{128};
};
