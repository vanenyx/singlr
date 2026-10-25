// Pure format/settings tests: no SecretAgent registration or wallet access.
#include "secretformat.h"
#include <QCoreApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <iostream>
#include <stdexcept>

#define CHECK(...) do { if (!(__VA_ARGS__)) throw std::runtime_error("line " + std::to_string(__LINE__) + ": " #__VA_ARGS__); } while (false)

static NMVariantMapMap wifi(const QString &management = QStringLiteral("wpa-psk"))
{
    return {{QStringLiteral("connection"), {{QStringLiteral("uuid"), QStringLiteral("d93743bb-e05d-4f09-a720-0195aa14b007")},
                                          {QStringLiteral("id"), QStringLiteral("Fixture")},
                                          {QStringLiteral("type"), QStringLiteral("802-11-wireless")}}},
            {QStringLiteral("802-11-wireless"), {{QStringLiteral("ssid"), QByteArray("Fixture")}}},
            {QStringLiteral("802-11-wireless-security"), {{QStringLiteral("key-mgmt"), management},
                                                       {QStringLiteral("psk-flags"), 1}}}};
}

static void json()
{
    CHECK(SecretFormat::folder == QStringLiteral("Network Management"));
    CHECK(SecretFormat::key(QStringLiteral("abc"), QStringLiteral("802-11-wireless-security"))
          == QStringLiteral("{abc};802-11-wireless-security"));
    CHECK(!SecretFormat::key(QStringLiteral("abc1"), QStringLiteral("vpn")).startsWith(SecretFormat::key(QStringLiteral("abc"), {})));
    const NMStringMap expected{{QStringLiteral("psk"), QString::fromUtf8("contraseña\n\"\\🔑")},
                               {QStringLiteral("empty"), QString()}};
    NMStringMap decoded;
    const auto encoded = SecretFormat::encode(expected);
    CHECK(SecretFormat::decode(encoded, decoded));
    CHECK(decoded == expected);
    CHECK(QJsonDocument::fromJson(encoded.toUtf8()).object().value(QStringLiteral("psk")).toString() == expected.value(QStringLiteral("psk")));
    for (const auto &bad : {QStringLiteral("bad"), QStringLiteral("[]"), QStringLiteral("{\"psk\":7}"),
                           QStringLiteral("{\"psk\":\"ok\",\"z\":null}")}) {
        CHECK(!SecretFormat::decode(bad, decoded));
        CHECK(decoded.isEmpty());
    }
}

static void passwords()
{
    const QString security = QStringLiteral("802-11-wireless-security");
    auto connection = wifi();
    CHECK(SecretFormat::passwordKey(connection, security) == QStringLiteral("psk"));
    CHECK(SecretFormat::passwordKey(wifi(QStringLiteral("sae")), security) == QStringLiteral("psk"));
    connection = wifi(QStringLiteral("none"));
    connection[security].insert(QStringLiteral("wep-tx-keyidx"), 2);
    CHECK(SecretFormat::passwordKey(connection, security) == QStringLiteral("wep-key2"));
    connection[security].insert(QStringLiteral("wep-tx-keyidx"), 4);
    CHECK(SecretFormat::passwordKey(connection, security).isEmpty());
    CHECK(SecretFormat::passwordKey(wifi(QStringLiteral("wpa-eap")), security).isEmpty());
    CHECK(SecretFormat::passwordKey(connection, QStringLiteral("vpn")).isEmpty());
    connection.remove(QStringLiteral("802-11-wireless"));
    CHECK(SecretFormat::passwordKey(connection, security).isEmpty());
}

static void roundtrip()
{
    const QString security = QStringLiteral("802-11-wireless-security");
    for (const auto &management : {QStringLiteral("wpa-psk"), QStringLiteral("sae"), QStringLiteral("none")}) {
        auto connection = wifi(management);
        const auto passwordKey = SecretFormat::passwordKey(connection, security);
        connection[security].insert(passwordKey, QStringLiteral("fixture-passphrase"));
        NetworkManager::ConnectionSettings settings(connection);
        const auto setting = settings.setting(security);
        CHECK(setting);
        CHECK(setting->needSecrets().isEmpty());
        CHECK(!setting->needSecrets(true).isEmpty()); // RequestNew must not reuse stored secrets.
        NMStringMap decoded;
        CHECK(SecretFormat::decode(SecretFormat::encode(setting->secretsToStringMap()), decoded));
        connection[security].remove(passwordKey);
        NetworkManager::ConnectionSettings fresh(connection);
        CHECK(!fresh.setting(security)->needSecrets().isEmpty());
        // The legacy KWallet readMap path supplies this very same NMStringMap.
        fresh.setting(security)->secretsFromStringMap(decoded);
        CHECK(fresh.setting(security)->secretsToMap().value(passwordKey).toString() == QStringLiteral("fixture-passphrase"));
        CHECK(fresh.setting(security)->needSecrets().isEmpty());
        CHECK(!fresh.setting(security)->secretsToMap().contains(QStringLiteral("key-mgmt")));
    }
}

static void flags()
{
    const QString security = QStringLiteral("802-11-wireless-security");
    auto connection = wifi();
    connection[security].insert(QStringLiteral("psk"), QStringLiteral("fixture-only"));
    for (uint flag = 0; flag < 8; ++flag) {
        connection[security].insert(QStringLiteral("psk-flags"), flag);
        NetworkManager::ConnectionSettings settings(connection);
        const auto stored = SecretFormat::persistable(settings.setting(security), connection.value(security));
        CHECK(stored.isEmpty() == (flag != 1)); // only AgentOwned, never NotSaved/NotRequired/system-owned.
        if (flag == 1)
            CHECK(stored.value(QStringLiteral("psk")) == QStringLiteral("fixture-only"));
        // A system-supplied secret wins even if an obsolete wallet entry exists.
        SecretFormat::mergeStored(settings.setting(security), connection.value(security), {{QStringLiteral("psk"), QStringLiteral("old-value")}});
        CHECK(settings.setting(security)->secretsToMap().value(QStringLiteral("psk")).toString() == QStringLiteral("fixture-only"));
        auto missing = connection;
        missing[security].remove(QStringLiteral("psk"));
        NetworkManager::ConnectionSettings fresh(missing);
        SecretFormat::mergeStored(fresh.setting(security), missing.value(security), {{QStringLiteral("psk"), QStringLiteral("old-value")}});
        CHECK(fresh.setting(security)->secretsToMap().isEmpty() == bool(flag & 6));
    }
    connection = wifi(QStringLiteral("none"));
    connection[security].insert(QStringLiteral("wep-key2"), QStringLiteral("abcde"));
    connection[security].insert(QStringLiteral("wep-key-flags"), 1);
    NetworkManager::ConnectionSettings settings(connection);
    CHECK(SecretFormat::persistable(settings.setting(security), connection.value(security)).contains(QStringLiteral("wep-key2")));
}

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    try {
        const QString test = argc > 1 ? QString::fromLocal8Bit(argv[1]) : QString();
        if (test == QLatin1String("json")) json();
        else if (test == QLatin1String("passwords")) passwords();
        else if (test == QLatin1String("roundtrip")) roundtrip();
        else if (test == QLatin1String("flags")) flags();
        else throw std::runtime_error("unknown test");
        std::cout << "PASS " << test.toStdString() << '\n';
    } catch (const std::exception &error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
