#pragma once

#include <NetworkManagerQt/SecretAgent>
#include <KWallet>
#include <QPointer>
#include <functional>

class SecretAgent final : public NetworkManager::SecretAgent
{
    Q_OBJECT
public:
    explicit SecretAgent(QObject *parent = nullptr);
    ~SecretAgent() override;

    NMVariantMapMap GetSecrets(const NMVariantMapMap &connection, const QDBusObjectPath &path,
                              const QString &setting, const QStringList &hints, uint flags) override;
    void SaveSecrets(const NMVariantMapMap &connection, const QDBusObjectPath &path) override;
    void DeleteSecrets(const NMVariantMapMap &connection, const QDBusObjectPath &path) override;
    void CancelGetSecrets(const QDBusObjectPath &path, const QString &setting) override;

    Q_INVOKABLE void provide(const QString &requestId, const QString &password);
    Q_INVOKABLE void cancel(const QString &requestId);

Q_SIGNALS:
    void secretRequested(const QString &requestId, const QString &ssid, const QString &connectionUuid, bool retry);
    void requestCancelled(const QString &requestId);

private:
    struct Request {
        QDBusMessage message;
        NMVariantMapMap connection;
        QString path;
        QString setting;
        uint flags;
        bool notified = false;
    };
    QMap<QString, Request> m_requests;
    QPointer<KWallet::Wallet> m_wallet;
    QList<std::function<void(KWallet::Wallet *)>> m_walletWaiters;
    bool m_opening = false;

    void withWallet(std::function<void(KWallet::Wallet *)> callback, bool allowInteraction = true);
    void process(const QString &id, KWallet::Wallet *wallet);
    bool store(KWallet::Wallet *wallet, const NMVariantMapMap &connection, const QString &onlySetting = {});
    bool remove(KWallet::Wallet *wallet, const QString &uuid);
    void reject(const QString &id, Error error, bool notify);
};
