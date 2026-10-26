// Exercises the real deferred ScreenSurfaces placement, without a compositor.
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQmlContext>
#include <QQmlError>
#include <QtTest>
#include <QScreen>
#include <QWindow>
#include <LayerShellQt/Window>
#include "system.h"

class PlacementRecorder : public QObject
{
    Q_OBJECT
public:
    int calls = 0;
    Q_INVOKABLE void placeOnScreen(QObject *, const QString &) { ++calls; }
};

class SurfaceLifecycle : public QObject
{
    Q_OBJECT
private Q_SLOTS:
    void placementPreservesVisibility_data() {
        QTest::addColumn<bool>("visible");
        QTest::newRow("shown-dock-or-edge") << true;
        QTest::newRow("auto-hidden-dock") << false;
    }
    void placementPreservesVisibility() {
        QFETCH(bool, visible);
        const QDBusConnection disconnected(QStringLiteral("singlr-test-disconnected"));
        System system(disconnected, disconnected);
        QWindow window;
        auto *layer = LayerShellQt::Window::get(&window);
        QVERIFY(layer->closeOnDismissed()); // Installed LayerShellQt's default.
        window.setVisible(visible);
        system.placeOnScreen(&window, QGuiApplication::primaryScreen()->name());
        // The compositor's closed event must not close a logical shell window.
        QVERIFY(!layer->closeOnDismissed());
        QCOMPARE(window.isVisible(), visible);
        QCOMPARE(layer->screen(), QGuiApplication::primaryScreen());
        window.setVisible(!visible);
        system.placeOnScreen(&window, QGuiApplication::primaryScreen()->name());
        QCOMPARE(window.isVisible(), !visible);
    }
    void deferredPlacement_data() {
        QTest::addColumn<bool>("removeScreen");
        QTest::newRow("screen-disappears") << true;
        QTest::newRow("loader-window-disappears") << false;
    }
    void deferredPlacement() {
        QFETCH(bool, removeScreen);
        PlacementRecorder recorder;
        QQmlEngine engine;
        engine.addImportPath(qEnvironmentVariable("SINGLR_TEST_QML_IMPORT", QStringLiteral(SINGLR_ROOT "/shell/qml")));
        engine.addImportPath(QStringLiteral(SINGLR_ROOT "/build/qml"));
        engine.rootContext()->setContextProperty(QStringLiteral("SinglrSystem"), &recorder);
        QStringList errors;
        connect(&engine, &QQmlEngine::warnings, &engine, [&errors](const QList<QQmlError> &warnings) {
            for (const auto &warning : warnings)
                if (warning.description().contains(QStringLiteral("TypeError"))) errors << warning.toString();
        });
        QQmlComponent component(&engine);
        component.setData(R"(
            import QtQuick
            import Singlr.Shell
            ScreenSurfaces {
                outputScreen: Qt.application.screens[0]
                controller: QtObject {
                    property bool showBackground: true
                    property QtObject notificationCenter: QtObject { property int unread: 0 }
                }
            }
        )", QUrl());
        std::unique_ptr<QObject> surface(component.create());
        QVERIFY2(surface != nullptr, qPrintable(component.errorString()));
        QCOMPARE(recorder.calls, 0); // Placement is still queued.
        if (removeScreen) {
            surface->setProperty("outputScreen", QVariant::fromValue<QObject *>(nullptr));
        } else {
            auto *controller = surface->property("controller").value<QObject *>();
            QVERIFY(controller);
            controller->setProperty("showBackground", false);
        }
        QCoreApplication::processEvents();
        QVERIFY2(errors.isEmpty(), qPrintable(errors.join(QLatin1Char('\n'))));
        if (removeScreen) QCOMPARE(recorder.calls, 0);
        else QVERIFY(recorder.calls > 0); // The surviving top bar was placed.
    }
};
QTEST_MAIN(SurfaceLifecycle)
#include "surface-lifecycle.moc"
