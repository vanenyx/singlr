#include "shortcuts.h"
#include <KGlobalShortcutInfo>
#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusMetaType>
#include <QDBusVirtualObject>
#include <QFile>
#include <QJsonArray>
#include <QJsonObject>
#include <QProcess>
#include <QTemporaryDir>
#include <QTextStream>
#include <cstdlib>
using namespace SinglrShortcuts;
void check(bool ok) { if (!ok) std::abort(); }
Snapshot fixture()
{
    Snapshot data;
    const auto names = actionNames();
    data[names[0]] = {QKeySequence("Meta+PgUp"), QKeySequence("Ctrl+X, Ctrl+M")};
    data[names[1]] = {}; // Explicitly disabled must stay disabled.
    data[names[2]] = {QKeySequence("Meta+Up"), QKeySequence("Ctrl+Alt+T")};
    data[names[3]] = {QKeySequence("Meta+Down")};
    // KWin 6 defaults: the window switcher also owns Meta+Tab.
    data[names[4]] = {QKeySequence("Alt+Tab"), QKeySequence("Meta+Tab")};
    data[names[5]] = {QKeySequence("Alt+Shift+Tab"), QKeySequence("Meta+Shift+Tab")};
    data[names[6]] = {};
    return data;
}
class FakeAccel : public QDBusVirtualObject {
    Snapshot keys = fixture();
public:
    QString introspect(const QString &) const override {
        return "<interface name=\"org.kde.KGlobalAccel\">"
               "<method name=\"shortcutKeys\"><arg type=\"as\" direction=\"in\"/><arg type=\"a(ai)\" direction=\"out\"/></method>"
               "<method name=\"setForeignShortcutKeys\"><arg type=\"as\" direction=\"in\"/><arg type=\"a(ai)\" direction=\"in\"/></method>"
               "</interface>";
    }
    bool handleMessage(const QDBusMessage &m, const QDBusConnection &bus) override {
        const auto args = m.arguments();
        if (args.isEmpty()) return false;
        const QString name = qdbus_cast<QStringList>(args[0]).value(1);
        if (!keys.contains(name)) return false;
        if (m.member() == "shortcutKeys") {
            bus.send(m.createReply(QVariantList{QVariant::fromValue(keys[name])}));
            return true;
        }
        if (m.member() == "setForeignShortcutKeys") {
            keys[name] = qdbus_cast<QList<QKeySequence>>(args[1]);
            bus.send(m.createReply());
            return true;
        }
        return false;
    }
};
int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    if (app.arguments().contains("--server")) {
        qDBusRegisterMetaType<QList<int>>();
        qDBusRegisterMetaType<QKeySequence>();
        qDBusRegisterMetaType<QList<QKeySequence>>();
        auto bus = QDBusConnection::sessionBus();
        FakeAccel server;
        check(bus.registerService("org.kde.kglobalaccel"));
        check(bus.registerVirtualObject("/kglobalaccel", &server));
        QTextStream(stdout) << "READY\n" << Qt::flush;
        return app.exec();
    }
    const auto data = fixture();
    Snapshot parsed;
    check(decode(encode(data).toJson(), parsed) && parsed == data);
    // A backup written before Meta+Tab was managed restores exactly its own actions.
    Snapshot legacy;
    for (int i = 0; i < 4; ++i) legacy[actionNames()[i]] = data[actionNames()[i]];
    Snapshot legacyParsed;
    check(decode(encode(legacy).toJson(), legacyParsed) && legacyParsed == legacy);
    for (const auto &bad : {QByteArray("invalid"), QByteArray("{}"), QByteArray("[]")})
        check(!decode(bad, parsed) && parsed == data);
    auto root = encode(data).object();
    root["version"] = 2;
    check(!decode(QJsonDocument(root).toJson(), parsed));
    root = encode(data).object();
    auto actions = root["actions"].toObject();
    actions[actionNames()[0]] = QJsonArray{QJsonArray{1, 2, 3, 4, 5}};
    root["actions"] = actions;
    check(!decode(QJsonDocument(root).toJson(), parsed));
    for (const auto &badStroke : {QJsonValue(-1), QJsonValue(2.5), QJsonValue("Meta+Up"), QJsonValue(2147483648.0)}) {
        actions[actionNames()[0]] = QJsonArray{QJsonArray{badStroke}};
        root["actions"] = actions;
        check(!decode(QJsonDocument(root).toJson(), parsed));
    }
    check(canAssign(true, {}, "singlr", "notifications"));
    check(!canAssign(false, {}, "singlr", "notifications"));
    check(canAssign(false, {{"singlr", "notifications"}}, "singlr", "notifications"));
    check(!canAssign(true, {{"other", "notifications"}}, "singlr", "notifications"));
    check(!canAssign(false, {{"singlr", "control"}}, "singlr", "notifications"));
    check(!canAssign(true, {{"singlr"}}, "singlr", "notifications"));
    check(!canAssign(false, {{"singlr", "notifications"}, {"other", "action"}}, "singlr", "notifications"));
    if (app.arguments().contains("--unit")) {
        QTextStream(stdout) << "PASS backup, conflicts\n";
        return 0;
    }
    QTemporaryDir runtime;
    check(runtime.isValid());
    qputenv("XDG_RUNTIME_DIR", runtime.path().toUtf8());
    QProcess server;
    server.start(app.applicationFilePath(), {"--server"});
    check(server.waitForReadyRead() && server.readLine() == "READY\n");
    check(applyKWin());
    QDBusInterface api("org.kde.kglobalaccel", "/kglobalaccel", "org.kde.KGlobalAccel");
    const auto keysFor = [&api](const QString &name) {
        QDBusReply<QList<QKeySequence>> reply = api.call("shortcutKeys", QStringList{"kwin", name, "KWin", name});
        check(reply.isValid());
        return reply.value();
    };
    check(keysFor(actionNames()[0]) == QList<QKeySequence>{QKeySequence("Meta+Up")});
    check(keysFor(actionNames()[1]) == QList<QKeySequence>{QKeySequence("Meta+Down")});
    check(keysFor(actionNames()[2]) == QList<QKeySequence>{QKeySequence("Ctrl+Alt+T")});
    check(keysFor(actionNames()[3]).isEmpty());
    check(keysFor(actionNames()[4]) == QList<QKeySequence>{QKeySequence("Alt+Tab")});
    check(keysFor(actionNames()[5]) == QList<QKeySequence>{QKeySequence("Alt+Shift+Tab")});
    check(keysFor(actionNames()[6]) == QList<QKeySequence>{QKeySequence("Meta+Tab")});
    QFile backup(backupPath());
    check(backup.open(QIODevice::ReadOnly));
    const auto original = backup.readAll();
    backup.close();
    check(decode(original, parsed) && parsed == data);
    check(applyKWin());
    check(backup.open(QIODevice::ReadOnly) && backup.readAll() == original);
    backup.close();
    check(restoreKWin() && !backup.exists());
    // Back up the restored state to prove exact restoration, including disabled/multi-stroke bindings.
    check(applyKWin());
    check(backup.open(QIODevice::ReadOnly) && backup.readAll() == original);
    backup.close();
    check(restoreKWin() && restoreKWin());
    check(backup.open(QIODevice::WriteOnly));
    backup.write("invalid");
    backup.close();
    check(!applyKWin() && !restoreKWin() && backup.exists());
    server.terminate();
    check(server.waitForFinished());
    QTextStream(stdout) << "PASS backup, conflicts, isolated D-Bus apply/reapply/restore\n";
}
