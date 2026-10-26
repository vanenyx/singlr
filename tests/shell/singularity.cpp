#include "singularity.h"
#include <QQuickWindow>
#include <QtTest>
#include <QSignalSpy>

class SingularityTest : public QObject {
    Q_OBJECT
private slots:
    void lifecycleAndRendering() {
        QQuickWindow window;
        window.setColor(Qt::black); window.resize(1000, 640);
        auto *effect = new Singularity(window.contentItem());
        effect->setSize(QSizeF(1000, 640));
        window.show(); QVERIFY(QTest::qWaitForWindowExposed(&window));
        QVERIFY(window.rendererInterface()->graphicsApi() != QSGRendererInterface::Software);
        QTest::qWait(100);
        const QImage still = window.grabWindow(); QVERIFY(!still.isNull());
        int lit = 0;
        for (int y = 0; y < still.height(); ++y) for (int x = 0; x < still.width(); ++x)
            if (qRed(still.pixel(x, y)) > 35) ++lit;
        QVERIFY2(lit > 2000, qPrintable(QString::number(lit)));
        QVERIFY(!effect->animating()); QCOMPARE(effect->elapsed(), 0.);
        effect->setRunning(true); QTRY_VERIFY(effect->animating());
        QTest::qWait(200); QVERIFY(effect->elapsed() > .1);
        const QImage moving = window.grabWindow(); QVERIFY(moving != still);
        QSignalSpy frames(effect, &Singularity::elapsedChanged);
        effect->setRunning(false); QVERIFY(!effect->animating());
        QTest::qWait(120); QCOMPARE(frames.count(), 0);
        effect->setRunning(true); QTRY_VERIFY(effect->animating());
        QVERIFY(QMetaObject::invokeMethod(effect, "setLocked", Q_ARG(bool, true)));
        QVERIFY(!effect->animating()); frames.clear(); QTest::qWait(100); QCOMPARE(frames.count(), 0);
        QVERIFY(QMetaObject::invokeMethod(effect, "setLocked", Q_ARG(bool, false)));
        QTRY_VERIFY(effect->animating());
        QVERIFY(QMetaObject::invokeMethod(effect, "setSleeping", Q_ARG(bool, true)));
        QVERIFY(!effect->animating());
        QVERIFY(QMetaObject::invokeMethod(effect, "setSleeping", Q_ARG(bool, false)));
        QTRY_VERIFY(effect->animating());
        effect->setVisible(false); QVERIFY(!effect->animating());
        effect->setVisible(true); QTRY_VERIFY(effect->animating());
        effect->setPointer(QPointF(-1, 5)); QCOMPARE(effect->pointer(), QPointF(0, 1));
        effect->setQuality(10); QCOMPARE(effect->quality(), 2);
        QTest::qWait(80); QVERIFY(!window.grabWindow().isNull());
        window.hide(); QTRY_VERIFY(!effect->animating());
        QPointer<Singularity> guard(effect); delete effect; QVERIFY(guard.isNull());
    }
};
QTEST_MAIN(SingularityTest)
#include "singularity.moc"
