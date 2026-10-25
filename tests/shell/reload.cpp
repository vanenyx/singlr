#include "launcherbridge.h"
#include <QCoreApplication>
#include <QQmlEngine>
#include <QQmlComponent>
#include <memory>
#include <cstdio>

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    QQmlEngine engine;
    QQmlComponent component(&engine);
    component.setData(R"(import QtQml
        QtObject {
            property int reloads: 0
            property int toggles: 0
            property int applications: 0
            function reloadSettings() { reloads++ }
            function toggleLauncher() { toggles++ }
            function showApplications() { applications++ }
        })", QUrl());
    std::unique_ptr<QObject> target(component.create());
    if (!target) return 1;
    LauncherBridge bridge(target.get());
    const auto call = [&](const char *path, const char *member) {
        return bridge.handleMessage(QDBusMessage::createMethodCall("org.kde.plasmashell",
            QString::fromLatin1(path), "org.kde.PlasmaShell", QString::fromLatin1(member)),
            QDBusConnection::sessionBus());
    };
    call("/PlasmaShell", "singlrReloadSettings");
    QCoreApplication::processEvents();
    if (target->property("reloads").toInt() != 1 || target->property("toggles").toInt() != 0) return 2;
    call("/PlasmaShell", "singlrShowApplications");
    call("/App", "display");
    QCoreApplication::processEvents();
    if (target->property("applications").toInt() != 1 || target->property("toggles").toInt() != 1) return 3;
    // Older sessions without reloadSettings must not toggle the launcher.
    component.setData(R"(import QtQml
        QtObject { property int toggles: 0; function toggleLauncher() { toggles++ } })", QUrl());
    std::unique_ptr<QObject> old(component.create());
    if (!old) return 4;
    LauncherBridge legacy(old.get());
    legacy.handleMessage(QDBusMessage::createMethodCall("org.kde.plasmashell", "/PlasmaShell",
        "org.kde.PlasmaShell", "singlrReloadSettings"), QDBusConnection::sessionBus());
    QCoreApplication::processEvents();
    if (old->property("toggles").toInt() != 0) return 5;
    std::puts("PASS reload dispatch, queued invocation, legacy session and launcher actions");
}
