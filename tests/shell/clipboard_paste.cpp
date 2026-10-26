#include "clipboardpastebridge.h"
#include <QSignalSpy>
#include <QtTest>
class ClipboardPasteTest : public QObject {
    Q_OBJECT
private Q_SLOTS:
    void unavailableKeepsManualCopyAndNeverSendsKeys() {
        ClipboardPasteBridge bridge;
        QSignalSpy sent(&bridge, &ClipboardPasteBridge::shortcutSent);
        QSignalSpy failed(&bridge, &ClipboardPasteBridge::failed);
        bridge.enable(); bridge.captureTarget();
        QVERIFY(!bridge.canPaste()); QVERIFY(!bridge.pending());
        bridge.preparePaste(); bridge.requestPaste();
        QCOMPARE(failed.count(), 1); QCOMPARE(sent.count(), 0);
        QVERIFY(!bridge.pending());
        QTest::qWait(40); QCOMPARE(sent.count(), 0);
    }
    void cancellingIsQuiet() {
        ClipboardPasteBridge bridge;
        QSignalSpy sent(&bridge, &ClipboardPasteBridge::shortcutSent);
        QSignalSpy failed(&bridge, &ClipboardPasteBridge::failed);
        bridge.captureTarget(); bridge.cancelIfIdle(); bridge.cancel();
        QVERIFY(!bridge.canPaste()); QVERIFY(!bridge.pending());
        QCOMPARE(sent.count(), 0); QCOMPARE(failed.count(), 0);
    }
};
QTEST_MAIN(ClipboardPasteTest)
#include "clipboard_paste.moc"
