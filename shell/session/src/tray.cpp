#include "tray.h"
#include "trayformat.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>
#include <QDBusVariant>
#include <QMutexLocker>
#include <QSet>
#include <QUrl>
#include <utility>

namespace {
const QString watcherService = QStringLiteral("org.kde.StatusNotifierWatcher");
const QString watcherPath = QStringLiteral("/StatusNotifierWatcher");
const QString itemInterface = QStringLiteral("org.kde.StatusNotifierItem");
const QString menuInterface = QStringLiteral("com.canonical.dbusmenu");
const QString propertiesInterface = QStringLiteral("org.freedesktop.DBus.Properties");
constexpr int timeout = 1500;

QDBusMessage call(const QString &service, const QString &path, const QString &interface,
                  const QString &method, const QVariantList &args = {})
{
    auto message = QDBusMessage::createMethodCall(service, path, interface, method);
    message.setArguments(args);
    return message;
}

QStringList addressParts(const QString &address)
{
    const auto slash = address.indexOf(QLatin1Char('/'));
    const QString service = slash < 0 ? address : address.left(slash);
    const QString path = slash < 0 ? QStringLiteral("/StatusNotifierItem") : address.mid(slash);
    if (service.isEmpty() || !path.startsWith(QLatin1Char('/')))
        return {};
    return {service, path};
}

QString key(const QString &service, const QString &path) { return service + path; }

void sendAction(const QDBusConnection &bus, QObject *parent, const QDBusMessage &message)
{
    auto *pending = new QDBusPendingCallWatcher(bus.asyncCall(message, timeout), parent);
    QObject::connect(pending, &QDBusPendingCallWatcher::finished, parent, [pending] {
        const QDBusPendingReply<> reply = *pending;
        if (reply.isError())
            qWarning() << "SinglrTray action:" << reply.error().name() << reply.error().message();
        pending->deleteLater();
    });
}
}

TrayImageProvider::TrayImageProvider(std::shared_ptr<TrayImages> images)
    : QQuickImageProvider(QQuickImageProvider::Image), m_images(std::move(images)) {}

QImage TrayImageProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    QImage image;
    {
        QMutexLocker lock(&m_images->mutex);
        image = m_images->images.value(id.section(QLatin1Char('?'), 0, 0));
    }
    if (size)
        *size = image.size();
    if (!image.isNull() && requestedSize.isValid())
        image = image.scaled(requestedSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    return image;
}

TrayModel::TrayModel(QObject *parent) : QAbstractListModel(parent) {}
int TrayModel::rowCount(const QModelIndex &parent) const { return parent.isValid() ? 0 : m_rows.size(); }
QHash<int, QByteArray> TrayModel::roleNames() const
{
    static const QList<QByteArray> names = {"service", "path", "id", "title", "category", "status", "iconName",
                                           "iconSource", "toolTipTitle", "itemIsMenu", "menuPath"};
    QHash<int, QByteArray> roles;
    for (int i = 0; i < names.size(); ++i)
        roles.insert(Qt::UserRole + 1 + i, names[i]);
    return roles;
}
QVariant TrayModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.column() != 0 || index.row() < 0 || index.row() >= m_rows.size())
        return {};
    return m_rows[index.row()].value(QString::fromLatin1(roleNames().value(role)));
}
void TrayModel::update(const QString &key, const QVariantMap &values)
{
    if (values.value(QStringLiteral("status")).toString() == QLatin1String("Passive")) {
        remove(key);
        return;
    }
    const auto row = m_keys.indexOf(key);
    if (row < 0) {
        beginInsertRows({}, m_rows.size(), m_rows.size());
        m_keys.append(key);
        m_rows.append(values);
        endInsertRows();
    } else if (m_rows[row] != values) {
        m_rows[row] = values;
        Q_EMIT dataChanged(index(row), index(row));
    }
}
void TrayModel::remove(const QString &key)
{
    const auto row = m_keys.indexOf(key);
    if (row < 0)
        return;
    beginRemoveRows({}, row, row);
    m_rows.removeAt(row);
    m_keys.removeAt(row);
    endRemoveRows();
}

TrayItem::TrayItem(const QString &service, const QString &path, const QString &imageId,
                   TrayModel *model, std::shared_ptr<TrayImages> images, QObject *parent)
    : QObject(parent), service(service), path(path), m_bus(QDBusConnection::sessionBus()),
      m_imageId(imageId), m_model(model), m_images(std::move(images))
{
    for (const auto &signal : {"NewIcon", "NewTitle", "NewStatus", "NewToolTip", "NewAttentionIcon", "NewMenu"})
        m_bus.connect(service, path, itemInterface, QString::fromLatin1(signal), this, SLOT(itemChanged(QDBusMessage)));
    m_bus.connect(service, path, propertiesInterface, QStringLiteral("PropertiesChanged"), this, SLOT(itemChanged(QDBusMessage)));
    refresh();
}
TrayItem::~TrayItem()
{
    m_model->remove(key(service, path));
    QMutexLocker lock(&m_images->mutex);
    m_images->images.remove(m_imageId);
}
void TrayItem::itemChanged(const QDBusMessage &) { refresh(); }
void TrayItem::refresh()
{
    // Coalesce bursts, but never publish a response that predates a notification.
    if (m_pending) {
        m_dirty = true;
        return;
    }
    m_pending = true;
    m_dirty = false;
    auto *pending = new QDBusPendingCallWatcher(m_bus.asyncCall(call(service, path, propertiesInterface,
        QStringLiteral("GetAll"), {itemInterface}), timeout), this);
    connect(pending, &QDBusPendingCallWatcher::finished, this, [this, pending] {
        const QDBusPendingReply<QVariantMap> reply = *pending;
        pending->deleteLater();
        m_pending = false;
        if (m_dirty) {
            refresh();
            return;
        }
        if (!reply.isError())
            apply(reply.value());
        else
            qWarning() << "SinglrTray GetAll:" << service << path << reply.error().message();
    });
}
void TrayItem::apply(const QVariantMap &p)
{
    const QString status = p.value(QStringLiteral("Status"), QStringLiteral("Passive")).toString();
    QString iconName = p.value(QStringLiteral("IconName")).toString();
    QImage image = TrayFormat::image(p.value(QStringLiteral("IconPixmap")));
    if (status == QLatin1String("NeedsAttention")) {
        const QString attentionName = p.value(QStringLiteral("AttentionIconName")).toString();
        const QImage attentionImage = TrayFormat::image(p.value(QStringLiteral("AttentionIconPixmap")));
        if (!attentionName.isEmpty() || !attentionImage.isNull()) {
            iconName = attentionName;
            image = attentionImage;
        }
    }
    {
        QMutexLocker lock(&m_images->mutex);
        if (m_images->images.value(m_imageId) != image) {
            ++m_revision;
            if (image.isNull())
                m_images->images.remove(m_imageId);
            else
                m_images->images.insert(m_imageId, image);
        }
    }
    const QString newMenu = p.value(QStringLiteral("Menu")).value<QDBusObjectPath>().path();
    if (menuPath != newMenu) {
        if (!menuPath.isEmpty()) {
            m_bus.disconnect(service, menuPath, menuInterface, QStringLiteral("LayoutUpdated"), this, SLOT(layoutUpdated(QDBusMessage)));
            m_bus.disconnect(service, menuPath, menuInterface, QStringLiteral("ItemsPropertiesUpdated"), this, SLOT(layoutUpdated(QDBusMessage)));
        }
        menuPath = newMenu;
        if (!menuPath.isEmpty() && menuPath != QLatin1String("/")) {
            m_bus.connect(service, menuPath, menuInterface, QStringLiteral("LayoutUpdated"), this, SLOT(layoutUpdated(QDBusMessage)));
            m_bus.connect(service, menuPath, menuInterface, QStringLiteral("ItemsPropertiesUpdated"), this, SLOT(layoutUpdated(QDBusMessage)));
        }
        Q_EMIT menuChanged(service);
    }
    const QUrl source = image.isNull() ? QUrl() : QUrl(QStringLiteral("image://singlrtray/%1?v=%2").arg(m_imageId).arg(m_revision));
    m_model->update(key(service, path), {
        {QStringLiteral("service"), service}, {QStringLiteral("path"), path},
        {QStringLiteral("id"), p.value(QStringLiteral("Id"), QString())},
        {QStringLiteral("title"), p.value(QStringLiteral("Title"), QString())},
        {QStringLiteral("category"), p.value(QStringLiteral("Category"), QString())},
        {QStringLiteral("status"), status}, {QStringLiteral("iconName"), iconName},
        {QStringLiteral("iconSource"), source},
        {QStringLiteral("toolTipTitle"), TrayFormat::toolTipTitle(p.value(QStringLiteral("ToolTip")))},
        {QStringLiteral("itemIsMenu"), p.value(QStringLiteral("ItemIsMenu"), false)},
        {QStringLiteral("menuPath"), menuPath}});
}
void TrayItem::layoutUpdated(const QDBusMessage &) { Q_EMIT menuChanged(service); }

Tray::Tray(QObject *parent)
    : QObject(parent), m_bus(QDBusConnection::sessionBus()), m_model(this), m_images(std::make_shared<TrayImages>())
{
    m_hostService = QStringLiteral("org.kde.StatusNotifierHost-%1").arg(QCoreApplication::applicationPid());
    if (!m_bus.registerService(m_hostService)) {
        qWarning() << "SinglrTray: cannot register" << m_hostService;
        m_hostService.clear();
        return;
    }
    auto *watcher = new QDBusServiceWatcher(watcherService, m_bus, QDBusServiceWatcher::WatchForOwnerChange, this);
    connect(watcher, &QDBusServiceWatcher::serviceOwnerChanged, this, [this] { watcherChanged(); });
    m_bus.connect(watcherService, watcherPath, watcherService, QStringLiteral("StatusNotifierItemRegistered"),
                  this, SLOT(itemRegistered(QString)));
    m_bus.connect(watcherService, watcherPath, watcherService, QStringLiteral("StatusNotifierItemUnregistered"),
                  this, SLOT(itemUnregistered(QString)));
    watcherChanged();
}
Tray::~Tray()
{
    // Delete receivers before the model/cache members are destroyed.
    const auto oldItems = std::exchange(m_items, {});
    qDeleteAll(oldItems);
    if (!m_hostService.isEmpty())
        m_bus.unregisterService(m_hostService);
}
QQuickImageProvider *Tray::createImageProvider() const { return new TrayImageProvider(m_images); }
void Tray::watcherChanged()
{
    ++m_generation;
    const auto oldItems = std::exchange(m_items, {});
    QSet<QString> services;
    for (const auto *item : oldItems)
        services.insert(item->service);
    qDeleteAll(oldItems);
    for (const auto &service : services)
        Q_EMIT menuChanged(service);
    sendAction(m_bus, this, call(watcherService, watcherPath, watcherService,
                               QStringLiteral("RegisterStatusNotifierHost"), {m_hostService}));
    snapshot();
}
void Tray::snapshot()
{
    const auto generation = m_generation;
    const auto changes = m_changes;
    auto *pending = new QDBusPendingCallWatcher(m_bus.asyncCall(call(watcherService, watcherPath, propertiesInterface,
        QStringLiteral("Get"), {watcherService, QStringLiteral("RegisteredStatusNotifierItems")}), timeout), this);
    connect(pending, &QDBusPendingCallWatcher::finished, this, [this, pending, generation, changes] {
        const QDBusPendingReply<QDBusVariant> reply = *pending;
        pending->deleteLater();
        if (generation != m_generation)
            return;
        if (changes != m_changes) {
            snapshot();
            return;
        }
        if (reply.isError()) {
            qWarning() << "SinglrTray watcher:" << reply.error().message();
            return;
        }
        const QStringList addresses = qdbus_cast<QStringList>(reply.value().variant());
        QSet<QString> present;
        for (const auto &address : addresses) {
            const auto parts = addressParts(address);
            if (parts.isEmpty())
                continue;
            present.insert(key(parts[0], parts[1]));
            itemRegistered(address);
        }
        for (const auto &old : m_items.keys())
            if (!present.contains(old))
                delete m_items.take(old);
    });
}
void Tray::itemRegistered(const QString &address)
{
    ++m_changes;
    const auto parts = addressParts(address);
    if (parts.isEmpty() || m_items.contains(key(parts[0], parts[1])))
        return;
    auto *item = new TrayItem(parts[0], parts[1], QString::number(++m_nextImage), &m_model, m_images, this);
    connect(item, &TrayItem::menuChanged, this, &Tray::menuChanged);
    m_items.insert(key(parts[0], parts[1]), item);
}
void Tray::itemUnregistered(const QString &address)
{
    ++m_changes;
    const auto parts = addressParts(address);
    if (!parts.isEmpty()) {
        delete m_items.take(key(parts[0], parts[1]));
        Q_EMIT menuChanged(parts[0]);
    }
}
void Tray::activate(const QString &service, const QString &path, int x, int y)
{
    if (m_items.contains(key(service, path)))
        sendAction(m_bus, this, call(service, path, itemInterface, QStringLiteral("Activate"), {x, y}));
}
void Tray::secondaryActivate(const QString &service, const QString &path, int x, int y)
{
    if (m_items.contains(key(service, path)))
        sendAction(m_bus, this, call(service, path, itemInterface, QStringLiteral("SecondaryActivate"), {x, y}));
}
void Tray::scroll(const QString &service, const QString &path, int delta, const QString &orientation)
{
    if (m_items.contains(key(service, path)) && (orientation == QLatin1String("vertical") || orientation == QLatin1String("horizontal")))
        sendAction(m_bus, this, call(service, path, itemInterface, QStringLiteral("Scroll"), {delta, orientation}));
}
bool Tray::knownMenu(const QString &service, const QString &path) const
{
    if (path.isEmpty() || path == QLatin1String("/"))
        return false;
    for (const auto *item : m_items)
        if (item->service == service && item->menuPath == path)
            return true;
    return false;
}
QVariantList Tray::menu(const QString &service, const QString &menuPath)
{
    if (!knownMenu(service, menuPath))
        return {};
    // Block (not BlockWithGui) avoids nested GUI event processing/reentrancy.
    // Even exporters without AboutToShow may provide a valid GetLayout.
    m_bus.call(call(service, menuPath, menuInterface, QStringLiteral("AboutToShow"), {0}), QDBus::Block, timeout);
    const auto reply = m_bus.call(call(service, menuPath, menuInterface, QStringLiteral("GetLayout"),
                                       {0, -1, QStringList{}}), QDBus::Block, timeout);
    if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().size() != 2) {
        qWarning() << "SinglrTray GetLayout:" << service << menuPath << reply.errorMessage();
        return {};
    }
    return TrayFormat::menu(reply.arguments()[1]);
}
void Tray::activateMenuItem(const QString &service, const QString &menuPath, int id)
{
    if (id != 0 && knownMenu(service, menuPath))
        sendAction(m_bus, this, call(service, menuPath, menuInterface, QStringLiteral("Event"),
            {id, QStringLiteral("clicked"), QVariant::fromValue(QDBusVariant(0)),
             uint(QDateTime::currentMSecsSinceEpoch())}));
}
