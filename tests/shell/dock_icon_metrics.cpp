#include "dockiconmetrics.h"
#include <QGuiApplication>
#include <QtTest>

class IconMetricsTest : public QObject {
    Q_OBJECT
private Q_SLOTS:
    void opaqueAndTransparentFallback() {
        QImage image(80, 40, QImage::Format_ARGB32);
        image.fill(Qt::red);
        QCOMPARE(DockIconMetrics::visibleRect(image), QRectF(0, 0, 1, 1));
        image.fill(Qt::transparent);
        QCOMPARE(DockIconMetrics::visibleRect(image), QRectF(0, 0, 1, 1));
        QCOMPARE(DockIconMetrics::visibleRect({}), QRectF(0, 0, 1, 1));
    }
    void asymmetricPaddingPreservesFaintEdges() {
        QImage image(100, 80, QImage::Format_ARGB32);
        image.fill(Qt::transparent);
        for (int y = 8; y < 56; ++y) for (int x = 10; x < 70; ++x)
            image.setPixel(x, y, qRgba(255, 0, 0, 1));
        QCOMPARE(DockIconMetrics::visibleRect(image), QRectF(.1, .1, .6, .6));
        image.setDevicePixelRatio(2);
        QCOMPARE(DockIconMetrics::visibleRect(image), QRectF(.1, .1, .6, .6));
    }
    void qiconReplacementAndLocalUrl() {
        DockIconMetrics metrics;
        QImage image(128, 128, QImage::Format_ARGB32);
        image.fill(Qt::transparent);
        for (int y = 16; y < 112; ++y) for (int x = 16; x < 112; ++x)
            image.setPixel(x, y, qRgba(0, 0, 255, 255));
        QIcon icon(QPixmap::fromImage(image));
        QCOMPARE(metrics.contentRect(QVariant::fromValue(icon)), QRectF(.125, .125, .75, .75));
        QTemporaryDir temp; QVERIFY(temp.isValid());
        const auto path = temp.filePath(QString::fromUtf8("logo #á.png"));
        QVERIFY(image.save(path));
        QCOMPARE(metrics.contentRect(QUrl::fromLocalFile(path)), QRectF(.125, .125, .75, .75));
        image.fill(Qt::green);
        icon = QIcon(QPixmap::fromImage(image));
        QCOMPARE(metrics.contentRect(QVariant::fromValue(icon)), QRectF(0, 0, 1, 1));
        QCOMPARE(metrics.contentRect(QStringLiteral("singlr-missing-test-icon")), QRectF(0, 0, 1, 1));
    }
    void nonsquareIconIsAspectFitted() {
        DockIconMetrics metrics;
        QImage image(128, 64, QImage::Format_RGB32); image.fill(Qt::red);
        const QIcon icon(QPixmap::fromImage(image));
        QCOMPARE(metrics.contentRect(QVariant::fromValue(icon)), QRectF(0, .25, 1, .5));
    }
};
QTEST_MAIN(IconMetricsTest)
#include "dock_icon_metrics.moc"
