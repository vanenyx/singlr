#include "system.h"
#include <QGuiApplication>
#include <QFile>
#include <QTemporaryDir>
#include <QSignalSpy>
#include <QLocale>
#include <QTest>
#include <iostream>

#define CHECK(value) do { if (!(value)) { qCritical() << "Failed at" << __LINE__ << #value; return 1; } } while (false)
int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    QTemporaryDir dir;
    CHECK(dir.isValid());
    const auto launcher = QUrl::fromLocalFile(dir.filePath("fixture.desktop"));
    QFile desktop(launcher.toLocalFile());
    CHECK(desktop.open(QIODevice::WriteOnly));
    desktop.write((QStringLiteral(
        "[Desktop Entry]\nType=Application\nName=Fixture\nExec=/usr/bin/false\n"
        "Actions=new-window;private;hidden;empty;_SEPARATOR_;\n"
        "[Desktop Action new-window]\nName=New window\nName[es]=Nueva ventana\nName[fr]=Nouvelle fenêtre\n"
        "Icon=window-new\nExec=/usr/bin/touch %1\n"
        "[Desktop Action private]\nName=Private window\nName[es]=Ventana privada\nExec=/usr/bin/true\n"
        "[Desktop Action hidden]\nName=Hidden\nNoDisplay=true\nExec=/usr/bin/false\n"
        "[Desktop Action empty]\nName=Empty\n") .arg(dir.filePath("launched"))).toUtf8());
    desktop.close();
    CHECK(desktop.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner));
    System system(QDBusConnection::sessionBus(), QDBusConnection::sessionBus());
    const auto actions = system.applicationActions(launcher);
    CHECK(actions.size() == 2);
    CHECK(actions[0].toMap()["name"] == "new-window");
    CHECK(actions[0].toMap()["iconName"] == "window-new");
    const auto language = qEnvironmentVariable("LANGUAGE");
    CHECK(actions[0].toMap()["text"] == (language == "es" ? "Nueva ventana" : language == "fr" ? "Nouvelle fenêtre" : "New window"));
    CHECK(actions[1].toMap()["name"] == "private");
    CHECK(actions[1].toMap()["iconName"].toString().isEmpty());
    CHECK(system.applicationActions(QUrl("https://example.org/app.desktop")).isEmpty());
    CHECK(system.applicationActions(QUrl::fromLocalFile(dir.filePath("missing.desktop"))).isEmpty());
    CHECK(!system.launchApplicationAction(launcher, "missing"));
    CHECK(!system.launchApplicationAction(launcher, "hidden"));
    CHECK(!system.launchApplicationAction(launcher, "empty"));
    QSignalSpy finished(&system, &System::applicationActionFinished);
    CHECK(system.launchApplicationAction(launcher, "new-window"));
    CHECK(finished.count() || finished.wait(10000));
    CHECK(finished[0][2].toString().isEmpty());
    for (int i = 0; i < 100 && !QFile::exists(dir.filePath("launched")); ++i) QTest::qWait(20);
    CHECK(QFile::exists(dir.filePath("launched")));
    std::cout << "PASS application-actions " << language.toStdString() << std::endl;
}
