#pragma once
#include <QJsonDocument>
#include <QKeySequence>
#include <QMap>
#include <QStringList>

namespace SinglrShortcuts {
using Snapshot = QMap<QString, QList<QKeySequence>>;
QStringList actionNames();
QJsonDocument encode(const Snapshot &snapshot);
bool decode(const QByteArray &json, Snapshot &snapshot);
// Fail closed if availability cannot be established; allow only this exact action.
bool canAssign(bool available, const QList<QStringList> &owners, const QString &component, const QString &action);
QString backupPath();
bool applyKWin();
bool restoreKWin();
void registerActions(QObject *parent, QObject *session);
}
