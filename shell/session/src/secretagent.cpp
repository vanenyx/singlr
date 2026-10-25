#include "secretagent.h"
#include "secretformat.h"

#include <NetworkManagerQt/Manager>
#include <QDBusConnection>
#include <QTimer>
#include <QUuid>
#include <utility>

SecretAgent::SecretAgent(QObject *parent)
    : NetworkManager::SecretAgent(QStringLiteral("org.singlr.networkmanagement"), parent)
{
    connect(NetworkManager::notifier(), &NetworkManager::Notifier::serviceDisappeared, this, [this] {
        const auto ids = m_requests.keys();
        for (const auto &id : ids)
            reject(id, AgentCanceled, true);
    });
}

SecretAgent::~SecretAgent()
{
    const auto ids = m_requests.keys();
    for (const auto &id : ids)
        reject(id, AgentCanceled, true);
    delete m_wallet;
}

void SecretAgent::withWallet(std::function<void(KWallet::Wallet *)> callback, bool allowInteraction)
{
    if (m_wallet && m_wallet->isOpen()) {
        callback(m_wallet);
        return;
    }
    if (!allowInteraction && !KWallet::Wallet::isOpen(KWallet::Wallet::NetworkWallet())) {
        callback(nullptr);
        return;
    }
    m_walletWaiters.append(std::move(callback));
    if (m_opening)
        return;
    // Async opening keeps QML and CancelGetSecrets responsive during wallet unlock.
    delete m_wallet;
    m_opening = true;
    m_wallet = KWallet::Wallet::openWallet(KWallet::Wallet::NetworkWallet(), 0, KWallet::Wallet::Asynchronous);
    const auto finish = [this](bool success) {
        m_opening = false;
        const auto callbacks = std::exchange(m_walletWaiters, {});
        for (const auto &callback : callbacks)
            callback(success && m_wallet && m_wallet->isOpen() ? m_wallet.data() : nullptr);
    };
    if (!m_wallet) {
        finish(false);
        return;
    }
    m_wallet->setParent(this);
    connect(m_wallet, &KWallet::Wallet::walletOpened, this, finish, Qt::SingleShotConnection);
}

NMVariantMapMap SecretAgent::GetSecrets(const NMVariantMapMap &connection, const QDBusObjectPath &path,
                                     const QString &setting, const QStringList &, uint flags)
{
    NetworkManager::ConnectionSettings settings(connection);
    if (settings.uuid().isEmpty() || !settings.setting(setting)) {
        sendError(InvalidConnection, QStringLiteral("Connection UUID or requested setting missing"));
        return {};
    }
    CancelGetSecrets(path, setting);
    setDelayedReply(true);
    const auto id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    m_requests.insert(id, {message(), connection, path.path(), setting, flags});
    QTimer::singleShot(0, this, [this, id, flags] {
        if (!m_requests.contains(id))
            return;
        const auto &request = m_requests[id];
        NetworkManager::ConnectionSettings settings(request.connection);
        if ((flags & RequestNew) || settings.setting(request.setting)->needSecrets().isEmpty())
            process(id, nullptr);
        else
            withWallet([this, id](KWallet::Wallet *wallet) { process(id, wallet); }, flags & AllowInteraction);
    });
    return {};
}

void SecretAgent::process(const QString &id, KWallet::Wallet *wallet)
{
    auto it = m_requests.find(id);
    if (it == m_requests.end())
        return;
    NetworkManager::ConnectionSettings settings(it->connection);
    const auto setting = settings.setting(it->setting);
    if (wallet && wallet->setFolder(SecretFormat::folder)) {
        NMStringMap stored;
        const auto key = SecretFormat::key(settings.uuid(), it->setting);
        if (wallet->entryType(key) == KWallet::Wallet::Map) {
            if (wallet->readMap(key, stored) != 0)
                stored.clear();
        } else {
            QString json;
            if (wallet->readPassword(key, json) == 0)
                SecretFormat::decode(json, stored);
        }
        SecretFormat::mergeStored(setting, it->connection.value(it->setting), stored);
    }
    const bool retry = it->flags & RequestNew;
    if (!retry && setting->needSecrets().isEmpty()) {
        const NMVariantMapMap secrets{{it->setting, setting->secretsToMap()}};
        QDBusConnection::systemBus().send(it->message.createReply(QVariant::fromValue(secrets)));
        m_requests.erase(it);
        return;
    }
    if (!(it->flags & (AllowInteraction | RequestNew)) || SecretFormat::passwordKey(it->connection, it->setting).isEmpty()) {
        reject(id, NoSecrets, false);
        return;
    }
    it->notified = true;
    QString ssid = QString::fromUtf8(it->connection.value(QStringLiteral("802-11-wireless")).value(QStringLiteral("ssid")).toByteArray());
    if (ssid.isEmpty())
        ssid = settings.id();
    Q_EMIT secretRequested(id, ssid, settings.uuid(), retry);
}

void SecretAgent::provide(const QString &id, const QString &password)
{
    const auto it = m_requests.constFind(id);
    if (it == m_requests.cend() || !it->notified)
        return;
    auto request = it.value();
    m_requests.remove(id); // Repeated/late QML calls cannot answer twice.
    const auto key = SecretFormat::passwordKey(request.connection, request.setting);
    request.connection[request.setting].insert(key, password);
    NetworkManager::ConnectionSettings settings(request.connection);
    const NMVariantMapMap secrets{{request.setting, settings.setting(request.setting)->secretsToMap()}};
    QDBusConnection::systemBus().send(request.message.createReply(QVariant::fromValue(secrets)));
    // NM need not call SaveSecrets for secrets returned by this agent itself.
    if (!SecretFormat::persistable(settings.setting(request.setting), request.connection.value(request.setting)).isEmpty())
        withWallet([this, connection = request.connection, setting = request.setting](KWallet::Wallet *wallet) {
            if (!store(wallet, connection, setting))
                qWarning("SinglrSecrets: could not persist supplied secrets in KWallet");
        });
}

void SecretAgent::reject(const QString &id, Error error, bool notify)
{
    const auto it = m_requests.find(id);
    if (it == m_requests.end())
        return;
    const auto request = it.value();
    m_requests.erase(it);
    sendError(error, QStringLiteral("Secret request cancelled or unavailable"), request.message);
    if (notify)
        Q_EMIT requestCancelled(id);
}

void SecretAgent::cancel(const QString &id)
{
    reject(id, UserCanceled, false);
}

void SecretAgent::CancelGetSecrets(const QDBusObjectPath &path, const QString &setting)
{
    const auto ids = m_requests.keys();
    for (const auto &id : ids) {
        const auto &request = m_requests[id];
        if (request.path == path.path() && request.setting == setting)
            reject(id, AgentCanceled, true);
    }
}

bool SecretAgent::store(KWallet::Wallet *wallet, const NMVariantMapMap &connection, const QString &onlySetting)
{
    NetworkManager::ConnectionSettings settings(connection);
    if (!wallet || settings.uuid().isEmpty())
        return false;
    if (!wallet->hasFolder(SecretFormat::folder) && !wallet->createFolder(SecretFormat::folder))
        return false;
    if (!wallet->setFolder(SecretFormat::folder))
        return false;
    for (const auto &setting : settings.settings()) {
        if (!onlySetting.isEmpty() && setting->name() != onlySetting)
            continue;
        const auto secrets = SecretFormat::persistable(setting, connection.value(setting->name()));
        const auto key = SecretFormat::key(settings.uuid(), setting->name());
        if (secrets.isEmpty()) {
            if (wallet->hasEntry(key) && wallet->removeEntry(key) != 0)
                return false;
        } else if (wallet->writePassword(key, SecretFormat::encode(secrets)) != 0) {
            return false;
        }
    }
    return true;
}

bool SecretAgent::remove(KWallet::Wallet *wallet, const QString &uuid)
{
    if (!wallet || uuid.isEmpty())
        return false;
    if (!wallet->hasFolder(SecretFormat::folder))
        return true;
    if (!wallet->setFolder(SecretFormat::folder))
        return false;
    // Delete all settings belonging to this exact UUID, including obsolete ones.
    const auto prefix = SecretFormat::key(uuid, {});
    for (const auto &key : wallet->entryList())
        if (key.startsWith(prefix) && wallet->removeEntry(key) != 0)
            return false;
    return true;
}

void SecretAgent::SaveSecrets(const NMVariantMapMap &connection, const QDBusObjectPath &)
{
    if (NetworkManager::ConnectionSettings(connection).uuid().isEmpty()) {
        sendError(InvalidConnection, QStringLiteral("Missing connection UUID"));
        return;
    }
    setDelayedReply(true);
    withWallet([this, connection, call = message()](KWallet::Wallet *wallet) {
        if (store(wallet, connection))
            QDBusConnection::systemBus().send(call.createReply());
        else
            sendError(InternalError, QStringLiteral("Could not save secrets in KWallet"), call);
    });
}

void SecretAgent::DeleteSecrets(const NMVariantMapMap &connection, const QDBusObjectPath &)
{
    const auto uuid = NetworkManager::ConnectionSettings(connection).uuid();
    if (uuid.isEmpty()) {
        sendError(InvalidConnection, QStringLiteral("Missing connection UUID"));
        return;
    }
    setDelayedReply(true);
    withWallet([this, uuid, call = message()](KWallet::Wallet *wallet) {
        if (remove(wallet, uuid))
            QDBusConnection::systemBus().send(call.createReply());
        else
            sendError(InternalError, QStringLiteral("Could not delete secrets from KWallet"), call);
    });
}
