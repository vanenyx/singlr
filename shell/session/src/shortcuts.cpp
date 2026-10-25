#include <algorithm>
#include "shortcuts.h"
#include <KGlobalAccel>
#include <KGlobalShortcutInfo>
#include <QAction>
#include <QCoreApplication>
#include <QDBusInterface>
#include <QDBusMetaType>
#include <QDBusReply>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonObject>
#include <QLockFile>
#include <QSaveFile>
#include <QDebug>
#include <cmath>
#include <limits>

namespace SinglrShortcuts {
QStringList actionNames()
{
    return {QStringLiteral("Window Maximize"), QStringLiteral("Window Minimize"),
            QStringLiteral("Window Quick Tile Top"), QStringLiteral("Window Quick Tile Bottom")};
}
QJsonDocument encode(const Snapshot &snapshot)
{
    QJsonObject actions;
    for (auto it = snapshot.cbegin(); it != snapshot.cend(); ++it) {
        QJsonArray keys;
        for (const auto &key : it.value()) {
            QJsonArray strokes;
            for (int i = 0; i < key.count(); ++i)
                strokes.append(key[i].toCombined());
            keys.append(strokes);
        }
        actions.insert(it.key(), keys);
    }
    return QJsonDocument(QJsonObject{{"version", 1}, {"component", "kwin"}, {"actions", actions}});
}
bool decode(const QByteArray &json, Snapshot &snapshot)
{
    const auto document = QJsonDocument::fromJson(json);
    const auto root = document.object();
    if (root.value("version") != QJsonValue(1) || root.value("component") != QJsonValue("kwin") || !root.value("actions").isObject())
        return false;
    const auto actions = root.value("actions").toObject();
    if (actions.size() != actionNames().size())
        return false;
    Snapshot parsed;
    for (const auto &name : actionNames()) {
        if (!actions.value(name).isArray())
            return false;
        QList<QKeySequence> keys;
        for (const auto &value : actions.value(name).toArray()) {
            if (!value.isArray() || value.toArray().size() > 4)
                return false;
            int strokes[4] = {};
            int i = 0;
            for (const auto &stroke : value.toArray()) {
                const double number = stroke.toDouble(-1);
                if (!stroke.isDouble() || number < 0 || number > std::numeric_limits<int>::max() || number != std::floor(number))
                    return false;
                strokes[i++] = int(number);
            }
            keys.append(QKeySequence(strokes[0], strokes[1], strokes[2], strokes[3]));
        }
        parsed.insert(name, keys);
    }
    snapshot = parsed;
    return true;
}
bool canAssign(bool available, const QList<QStringList> &owners, const QString &component, const QString &action)
{
    for (const auto &owner : owners)
        if (owner.size() < 2 || owner[0] != component || owner[1] != action)
            return false;
    return available || !owners.isEmpty();
}
QString backupPath()
{
    const auto runtime = qEnvironmentVariable("XDG_RUNTIME_DIR");
    return runtime.isEmpty() ? QString() : runtime + QStringLiteral("/singlr-live/shortcuts-backup.json");
}
namespace {
void registerTypes()
{
    // Same operators and registration as KGlobalAccel: QKeySequence=(ai), list=a(ai).
    qDBusRegisterMetaType<QList<int>>();
    qDBusRegisterMetaType<QKeySequence>();
    qDBusRegisterMetaType<QList<QKeySequence>>();
}
QStringList actionId(const QString &name) { return {QStringLiteral("kwin"), name, QStringLiteral("KWin"), name}; }
bool readKeys(QDBusInterface &api, Snapshot &snapshot)
{
    for (const auto &name : actionNames()) {
        QDBusReply<QList<QKeySequence>> reply = api.call(QStringLiteral("shortcutKeys"), actionId(name));
        if (!reply.isValid()) {
            qWarning() << "Singlr: shortcutKeys" << name << reply.error();
            return false;
        }
        snapshot.insert(name, reply.value());
    }
    return true;
}
bool writeKeys(QDBusInterface &api, const QString &name, const QList<QKeySequence> &keys)
{
    QDBusReply<void> reply = api.call(QStringLiteral("setForeignShortcutKeys"), actionId(name), QVariant::fromValue(keys));
    if (!reply.isValid())
        qWarning() << "Singlr: setForeignShortcutKeys" << name << reply.error();
    if (!reply.isValid())
        return false;
    QDBusReply<QList<QKeySequence>> actual = api.call(QStringLiteral("shortcutKeys"), actionId(name));
    if (!actual.isValid() || actual.value() != keys) {
        qWarning() << "Singlr: KGlobalAccel no confirmó los atajos" << name;
        return false;
    }
    return true;
}
bool loadBackup(const QString &path, Snapshot &snapshot)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly) || !decode(file.readAll(), snapshot)) {
        qWarning() << "Singlr: backup de atajos inválido; se conserva" << path;
        return false;
    }
    return true;
}
}
bool applyKWin()
{
    registerTypes();
    const QString path = backupPath();
    if (path.isEmpty() || !QDir().mkpath(QFileInfo(path).absolutePath()))
        return false;
    QLockFile lock(path + ".lock");
    if (!lock.tryLock(0))
        return false;
    QDBusInterface api("org.kde.kglobalaccel", "/kglobalaccel", "org.kde.KGlobalAccel");
    api.setTimeout(1500);
    Snapshot current, original;
    if (!readKeys(api, current))
        return false;
    if (QFile::exists(path)) {
        if (!loadBackup(path, original))
            return false;
    } else {
        QSaveFile file(path);
        const auto data = encode(current).toJson();
        if (!file.open(QIODevice::WriteOnly) || !file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner)
            || file.write(data) != data.size() || !file.commit()) {
            qWarning() << "Singlr: no se pudo guardar backup de atajos" << path;
            return false;
        }
    }
    const QKeySequence up(Qt::META | Qt::Key_Up), down(Qt::META | Qt::Key_Down);
    // Release these keys from all four actions first, including inverted custom bindings.
    for (const auto &name : actionNames()) {
        auto keys = current.value(name);
        keys.removeAll(up);
        keys.removeAll(down);
        if (!writeKeys(api, name, keys))
            return false;
    }
    return writeKeys(api, actionNames()[0], {up}) && writeKeys(api, actionNames()[1], {down});
}
bool restoreKWin()
{
    const QString path = backupPath();
    if (path.isEmpty() || !QFile::exists(path))
        return true;
    QLockFile lock(path + ".lock");
    if (!lock.tryLock(0))
        return false;
    Snapshot original;
    if (!loadBackup(path, original))
        return false;
    registerTypes();
    QDBusInterface api("org.kde.kglobalaccel", "/kglobalaccel", "org.kde.KGlobalAccel");
    api.setTimeout(1500);
    // Clear first so restoring a key to its original owner cannot conflict.
    for (const auto &name : actionNames())
        if (!writeKeys(api, name, {}))
            return false;
    for (const auto &name : actionNames())
        if (!writeKeys(api, name, original.value(name)))
            return false;
    return QFile::remove(path);
}
void registerActions(QObject *parent, QObject *session)
{
    if (session->metaObject()->indexOfMethod("activateDockEntry(QVariant)") >= 0) {
        for (int n = 1; n <= 9; ++n) {
            auto *action = new QAction(parent);
            action->setObjectName(QStringLiteral("activate task manager entry %1").arg(n));
            action->setProperty("componentName", "plasmashell");
            action->setText(QStringLiteral("Activar entrada %1 del dock").arg(n));
            KGlobalAccel::self()->setShortcut(action, {QKeySequence(Qt::META | (Qt::Key_0 + n))}, KGlobalAccel::Autoloading);
            QObject::connect(action, &QAction::triggered, session, [session, n] {
                QMetaObject::invokeMethod(session, "activateDockEntry", Q_ARG(QVariant, n));
            });
        }
    } else {
        qWarning() << "Singlr: falta activateDockEntry(QVariant)";
    }
    struct Entry { const char *name; const char *method; QKeyCombination key; };
    const Entry entries[] = {{"Mostrar notificaciones", "toggleNotifications", Qt::META | Qt::Key_N},
                             {"Centro de control", "toggleControlCenter", Qt::META | Qt::Key_A},
                             {"Historial del portapapeles", "toggleClipboard", Qt::META | Qt::Key_V}};
    for (const auto &entry : entries) {
        const QByteArray signature = QByteArray(entry.method) + "()";
        if (session->metaObject()->indexOfMethod(signature.constData()) < 0) {
            qWarning() << "Singlr: falta" << signature;
            continue;
        }
        const QString name = QString::fromUtf8(entry.name);
        const QKeySequence key(entry.key);
        bool available = KGlobalAccel::isGlobalShortcutAvailable(key);
        QList<QStringList> owners;
        for (const auto type : {KGlobalAccel::Equal, KGlobalAccel::Shadows, KGlobalAccel::Shadowed})
            for (const auto &owner : KGlobalAccel::globalShortcutsByKey(key, type))
                owners.append({owner.componentUniqueName(), owner.uniqueName()});
        if (QByteArray(entry.method) == "toggleClipboard") {
            // KDE's Klipper runs inside this process and registers its own popup
            // ("show-on-mouse-pos", Meta+V) under our component. As when picking
            // another action in System Settings > Shortcuts, Singlr's history panel
            // takes the key for this component only; Plasma's entry is untouched.
            const QString self = QCoreApplication::applicationName();
            if (owners == QList<QStringList>{{self, QStringLiteral("show-on-mouse-pos")}}) {
                registerTypes();
                QDBusInterface api("org.kde.kglobalaccel", "/kglobalaccel", "org.kde.KGlobalAccel");
                api.setTimeout(1500);
                const QStringList klipper{self, QStringLiteral("show-on-mouse-pos"), self, QString()};
                QDBusReply<void> reply = api.call(QStringLiteral("setForeignShortcutKeys"), klipper,
                                                  QVariant::fromValue(QList<QKeySequence>{}));
                if (reply.isValid()) {
                    owners.clear();
                    available = true;
                } else {
                    qWarning() << "Singlr: no se pudo liberar Meta+V de Klipper" << reply.error();
                }
            }
        }
        if (!canAssign(available, owners, QStringLiteral("singlr"), name)) {
            // Si la tecla pertenece a una acción de plasmashell, Singlr ya es dueño de ese componente
            // mientras sustituye a Plasma: atiende esa misma acción sin cambiar el atajo guardado.
            // Cuando Plasma vuelve, la acción vuelve a ser suya.
            const auto plasmaOwner = std::find_if(owners.cbegin(), owners.cend(), [](const QStringList &owner) {
                return owner.value(0) == QLatin1String("plasmashell");
            });
            if (owners.size() == 1 && plasmaOwner != owners.cend()) {
                auto *borrowed = new QAction(parent);
                borrowed->setObjectName(plasmaOwner->value(1));
                borrowed->setProperty("componentName", "plasmashell");
                KGlobalAccel::self()->setShortcut(borrowed, {key}, KGlobalAccel::Autoloading);
                QObject::connect(borrowed, &QAction::triggered, session, [session, method = entry.method] {
                    QMetaObject::invokeMethod(session, method);
                });
                qInfo() << "Singlr: atiende" << key << "mediante plasmashell /" << plasmaOwner->value(1);
                continue;
            }
            qWarning() << "Singlr: conflicto de atajo; se conserva" << key << owners;
            continue;
        }
        auto *action = new QAction(name, parent);
        action->setObjectName(name);
        action->setProperty("componentName", "singlr");
        action->setProperty("componentDisplayName", "Singlr");
        KGlobalAccel::self()->setDefaultShortcut(action, {key}, KGlobalAccel::NoAutoloading);
        KGlobalAccel::self()->setShortcut(action, {key}, KGlobalAccel::NoAutoloading);
        QObject::connect(action, &QAction::triggered, session, [session, method = entry.method] {
            QMetaObject::invokeMethod(session, method);
        });
    }
}
}
