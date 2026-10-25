#pragma once

#include <NetworkManagerQt/ConnectionSettings>

// Plasma 6.8: Network Management / {uuid};setting, JSON text password.
// Older plasma-nm used a KWallet Map at the same key. Read it with readMap().
namespace SecretFormat
{
inline const QString folder = QStringLiteral("Network Management");
QString key(const QString &uuid, const QString &setting);
QString encode(const NMStringMap &secrets);
bool decode(const QString &json, NMStringMap &secrets);
QString passwordKey(const NMVariantMapMap &connection, const QString &setting);
NMStringMap persistable(const NetworkManager::Setting::Ptr &setting, const QVariantMap &properties);
void mergeStored(const NetworkManager::Setting::Ptr &setting, const QVariantMap &properties, NMStringMap stored);
}
