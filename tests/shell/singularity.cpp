#include "singularity.h"
#include <QQuickWindow>
#include <QtTest>
#include <QSignalSpy>

class SingularityTest : public QObject {
    Q_OBJECT
private slots:
    void fullFieldAndLocalWake() {
        QQuickWindow window;
        window.setColor(Qt::black); window.resize(1000, 640);
        auto *effect = new Singularity(window.contentItem());
        effect->setSize(QSizeF(1000, 640));
        window.show(); QVERIFY(QTest::qWaitForWindowExposed(&window));
        auto capture = [&] { effect->update(); QTest::qWait(35); return window.grabWindow(); };
        effect->m_time = 2.;
        const QImage base = capture(); QVERIFY(!base.isNull());
        // Every part of the output has actual rendered particles, not just the disk.
        for (int row = 0; row < 4; ++row) for (int col = 0; col < 6; ++col) {
            int lit = 0;
            for (int y = row * 160; y < (row + 1) * 160; ++y)
                for (int x = col * 166; x < (col + 1) * 166; ++x)
                    if (qRed(base.pixel(x, y)) > 6) ++lit;
            QVERIFY2(lit > 12, qPrintable(QString("tile %1,%2: %3").arg(col).arg(row).arg(lit)));
        }
        effect->setPointer(QPointF(.22, .20));
        QCOMPARE(capture(), base); // No hover: never repel around an invented center.
        effect->m_wakes[0] = {QPointF(.22, .20), QPointF(.3, .1), 2.};
        const QImage disturbed = capture();
        QVERIFY(disturbed.copy(100, 20, 260, 240) != base.copy(100, 20, 260, 240));
        QCOMPARE(disturbed.copy(500, 0, 500, 640), base.copy(500, 0, 500, 640));
        QCOMPARE(disturbed.copy(0, 320, 1000, 320), base.copy(0, 320, 1000, 320));
        const QString captureDir = qEnvironmentVariable("SINGLR_CAPTURE_DIR");
        if (!captureDir.isEmpty()) {
            QVERIFY(base.save(captureDir + "/flow-base.png"));
            QVERIFY(disturbed.save(captureDir + "/flow-local-wake.png"));
        }
        effect->m_wakes[0].born = -.1; // >2 s: fully restored at exactly the same orbit time.
        QCOMPARE(capture(), base);
        effect->m_wakes[0].born = 2.;
        effect->setReactive(false);
        QCOMPARE(capture(), base);
        effect->setReactive(true);
        effect->setPointerActive(true);
        effect->advanceFrame(.1f);
        const qreal born = effect->m_wakes[0].born;
        QVERIFY(born > 2.);
        for (int i = 0; i < 25; ++i) effect->advanceFrame(.1f);
        QCOMPARE(effect->m_wakes[0].born, born); // A stationary cursor creates no new impulses.
        QVERIFY(effect->m_time - born > 2.);
        effect->setPointerActive(false);
        effect->m_time = 5.;
        const QImage later = capture();
        QVERIFY(later.copy(0, 0, 300, 200) != base.copy(0, 0, 300, 200));
    }
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
