#pragma once

#include <QAbstractListModel>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QHash>
#include <QImage>
#include <QMutex>
#include <QQuickImageProvider>
#include <memory>

class TrayItem;

struct TrayImages {
    QMutex mutex;
    QHash<QString, QImage> images;
};

class TrayImageProvider final : public QQuickImageProvider
{
public:
    explicit TrayImageProvider(std::shared_ptr<TrayImages> images);
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;
private:
    std::shared_ptr<TrayImages> m_images;
};

class TrayModel final : public QAbstractListModel
{
    Q_OBJECT
public:
    explicit TrayModel(QObject *parent = nullptr);
    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;
    void update(const QString &key, const QVariantMap &values);
    void remove(const QString &key);
private:
    QStringList m_keys;
    QList<QVariantMap> m_rows;
};

class Tray final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QAbstractItemModel *items READ items CONSTANT)
public:
    explicit Tray(QObject *parent = nullptr);
    ~Tray() override;
    QAbstractItemModel *items() { return &m_model; }
    QQuickImageProvider *createImageProvider() const;
    Q_INVOKABLE void activate(const QString &service, const QString &path, int x, int y);
    Q_INVOKABLE void secondaryActivate(const QString &service, const QString &path, int x, int y);
    Q_INVOKABLE void scroll(const QString &service, const QString &path, int delta, const QString &orientation);
    Q_INVOKABLE void requestMenu(const QString &service, const QString &menuPath);
    Q_DECL_DEPRECATED_X("Use requestMenu and menuReady/menuFailed")
    Q_INVOKABLE QVariantList menu(const QString &service, const QString &menuPath);
    Q_INVOKABLE void activateMenuItem(const QString &service, const QString &menuPath, int id);
Q_SIGNALS:
    void menuReady(const QString &service, const QString &menuPath, const QVariantList &items);
    void menuFailed(const QString &service, const QString &menuPath, const QString &error);
    void menuChanged(const QString &service);
private Q_SLOTS:
    void itemRegistered(const QString &address);
    void itemUnregistered(const QString &address);
private:
    QDBusConnection m_bus;
    QString m_hostService;
    TrayModel m_model;
    std::shared_ptr<TrayImages> m_images;
    QHash<QString, TrayItem *> m_items;
    quint64 m_generation = 0;
    quint64 m_changes = 0;
    quint64 m_nextImage = 0;
    void watcherChanged();
    void snapshot();
    bool knownMenu(const QString &service, const QString &path) const;
};

// One receiver per (service,path), so signals from two items on the same bus
// connection cannot refresh or remove one another. All subscriptions die with it.
class TrayItem final : public QObject
{
    Q_OBJECT
public:
    TrayItem(const QString &service, const QString &path, const QString &imageId,
             TrayModel *model, std::shared_ptr<TrayImages> images, QObject *parent);
    ~TrayItem() override;
    QString service, path, menuPath;
Q_SIGNALS:
    void menuChanged(const QString &service);
// QDBusMessage accepts every signal payload, including NewStatus(s),
// LayoutUpdated(ui) and complex ItemsPropertiesUpdated arrays.
private Q_SLOTS:
    void itemChanged(const QDBusMessage &message);
    void layoutUpdated(const QDBusMessage &message);
private:
    QDBusConnection m_bus;
    QString m_imageId;
    TrayModel *m_model;
    std::shared_ptr<TrayImages> m_images;
    bool m_pending = false;
    bool m_dirty = false;
    quint64 m_revision = 0;
    void refresh();
    void apply(const QVariantMap &properties);
};
