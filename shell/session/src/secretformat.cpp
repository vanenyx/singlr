#include "secretformat.h"

#include <QDBusMetaType>
#include <QJsonDocument>
#include <QJsonObject>

namespace
{
uint secretFlags(const QString &setting, const QVariantMap &properties, const QString &key)
{
    const auto name = key.startsWith(QLatin1String("wep-key")) ? QStringLiteral("wep-key-flags") : key + QStringLiteral("-flags");
    return setting == QLatin1String("vpn") ? qdbus_cast<NMStringMap>(properties.value(QStringLiteral("data"))).value(name).toUInt()
                                           : properties.value(name).toUInt();
}
}

QString SecretFormat::key(const QString &uuid, const QString &setting)
{
    return QLatin1Char('{') + uuid + QStringLiteral("};") + setting;
}

QString SecretFormat::encode(const NMStringMap &secrets)
{
    QJsonObject object;
    for (auto it = secrets.cbegin(); it != secrets.cend(); ++it)
        object.insert(it.key(), it.value());
    return QString::fromUtf8(QJsonDocument(object).toJson(QJsonDocument::Compact));
}

bool SecretFormat::decode(const QString &json, NMStringMap &secrets)
{
    secrets.clear();
    const auto document = QJsonDocument::fromJson(json.toUtf8());
    if (!document.isObject())
        return false;
    const auto object = document.object();
    for (auto it = object.begin(); it != object.end(); ++it) {
        if (!it.value().isString()) {
            secrets.clear();
            return false;
        }
        secrets.insert(it.key(), it.value().toString());
    }
    return true;
}

QString SecretFormat::passwordKey(const NMVariantMapMap &connection, const QString &setting)
{
    // The QML contract has one password field; never substitute it for a VPN,
    // certificate, PIN or an enterprise identity/multi-secret authentication.
    if (!connection.contains(QStringLiteral("802-11-wireless")))
        return {};
    const auto properties = connection.value(setting);
    if (setting == QLatin1String("802-11-wireless-security")) {
        const auto management = properties.value(QStringLiteral("key-mgmt")).toString();
        if (management == QLatin1String("wpa-psk") || management == QLatin1String("sae") || management == QLatin1String("wpa-none"))
            return QStringLiteral("psk");
        if (management == QLatin1String("none")) {
            const auto index = properties.value(QStringLiteral("wep-tx-keyidx")).toUInt();
            if (index <= 3)
                return QStringLiteral("wep-key%1").arg(index);
        }
        if (management == QLatin1String("ieee8021x") && properties.value(QStringLiteral("auth-alg")).toString() == QLatin1String("leap"))
            return QStringLiteral("leap-password");
    }
    if (setting == QLatin1String("802-1x")) {
        NetworkManager::ConnectionSettings settings(connection);
        const auto security = settings.setting(setting);
        if (security && security->needSecrets(true) == QStringList{QStringLiteral("password")})
            return QStringLiteral("password");
    }
    return {};
}

NMStringMap SecretFormat::persistable(const NetworkManager::Setting::Ptr &setting, const QVariantMap &properties)
{
    auto secrets = setting->secretsToStringMap();
    for (auto it = secrets.begin(); it != secrets.end();) {
        const uint flags = secretFlags(setting->name(), properties, it.key());
        if (!(flags & NetworkManager::Setting::AgentOwned) || (flags & (NetworkManager::Setting::NotSaved | NetworkManager::Setting::NotRequired)))
            it = secrets.erase(it);
        else
            ++it;
    }
    return secrets;
}

void SecretFormat::mergeStored(const NetworkManager::Setting::Ptr &setting, const QVariantMap &properties, NMStringMap stored)
{
    for (auto it = stored.begin(); it != stored.end();) {
        if (secretFlags(setting->name(), properties, it.key()) & (NetworkManager::Setting::NotSaved | NetworkManager::Setting::NotRequired))
            it = stored.erase(it);
        else
            ++it;
    }
    // Secrets supplied by NM take precedence over an older wallet value.
    const auto supplied = setting->secretsToStringMap();
    for (auto it = supplied.cbegin(); it != supplied.cend(); ++it)
        stored.insert(it.key(), it.value());
    setting->secretsFromStringMap(stored);
}
