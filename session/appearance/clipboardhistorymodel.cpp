#include "clipboardhistorymodel.h"
#include <QAbstractProxyModel>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QSaveFile>
#include <QScopedValueRollback>
#include <QStandardPaths>

ClipboardHistoryModel::ClipboardHistoryModel(QObject *parent) : QSortFilterProxyModel(parent) {
    m_path = QStandardPaths::writableLocation(QStandardPaths::GenericStateLocation)
        + QStringLiteral("/singlr/clipboard-order.json");
    QFile file(m_path);
    // Metadata only: no text, image or other clipboard payload is duplicated.
    if (file.open(QIODevice::ReadOnly) && file.size() <= 1024 * 1024) {
        const auto values = QJsonDocument::fromJson(file.readAll()).array();
        for (const auto &value : values) {
            const auto id = value.toString();
            if (!id.isEmpty() && !m_order.contains(id)) m_order.append(id);
        }
    }
    sort(0);
}
QString ClipboardHistoryModel::uuid(const QModelIndex &index) const {
    return index.data(m_uuidRole).toString();
}
bool ClipboardHistoryModel::lessThan(const QModelIndex &left, const QModelIndex &right) const {
    const auto a = m_order.indexOf(uuid(left)), b = m_order.indexOf(uuid(right));
    return a == b ? left.row() < right.row() : a < b;
}
void ClipboardHistoryModel::setSourceModel(QAbstractItemModel *model) {
    if (sourceModel() == model) return;
    if (sourceModel()) disconnect(sourceModel(), nullptr, this, nullptr);
    m_uuidRole = model ? model->roleNames().key("uuid", -1) : -1;
    QSortFilterProxyModel::setSourceModel(model);
    if (!model) return;
    connect(model, &QAbstractItemModel::rowsInserted, this, &ClipboardHistoryModel::reconcile);
    connect(model, &QAbstractItemModel::rowsRemoved, this, &ClipboardHistoryModel::reconcile);
    connect(model, &QAbstractItemModel::modelReset, this, &ClipboardHistoryModel::reconcile);
    connect(model, &QAbstractItemModel::dataChanged, this, [this](const QModelIndex &, const QModelIndex &, const QList<int> &roles) {
        if (roles.isEmpty() || roles.contains(m_uuidRole)) reconcile();
    });
    // Public QML notification on KDE's DeclarativeHistoryModel, also emitted for
    // a fresh external copy of the item already at Klipper's native row zero.
    connect(model, SIGNAL(currentTextChanged()), this, SLOT(sourceActivated()));
    if (model->rowCount()) reconcile();
}
void ClipboardHistoryModel::reconcile() {
    if (!sourceModel()) return;
    QStringList present;
    for (int row = 0; row < sourceModel()->rowCount(); ++row) {
        const auto id = uuid(sourceModel()->index(row, 0));
        if (!id.isEmpty()) present.append(id);
    }
    QStringList updated;
    for (const auto &id : present) if (!m_order.contains(id)) updated.append(id);
    for (const auto &id : std::as_const(m_order)) if (present.contains(id)) updated.append(id);
    if (updated == m_order) return;
    m_order = updated;
    invalidate();
    persist();
}
void ClipboardHistoryModel::sourceActivated() {
    if (m_selecting || !sourceModel()) return;
    // Read the underlying model: the QML proxy may still be propagating the
    // rowsMoved notification when currentTextChanged arrives from Klipper.
    auto *model = sourceModel();
    while (auto *proxy = qobject_cast<QAbstractProxyModel *>(model)) {
        if (!proxy->sourceModel()) return;
        model = proxy->sourceModel();
    }
    const auto id = uuid(model->index(0, 0));
    if (id.isEmpty()) return;
    QMetaObject::invokeMethod(this, [this, id] {
        if (!m_order.contains(id) || m_order.first() == id) return;
        m_order.removeAll(id); m_order.prepend(id);
        invalidate(); persist();
    }, Qt::QueuedConnection);
}
void ClipboardHistoryModel::select(const QString &id) {
    if (!sourceModel() || !m_order.contains(id)) return;
    const QScopedValueRollback selecting(m_selecting, true);
    QMetaObject::invokeMethod(sourceModel(), "moveToTop", Qt::DirectConnection, Q_ARG(QString, id));
}
void ClipboardHistoryModel::remove(const QString &id) {
    const QScopedValueRollback selecting(m_selecting, true);
    if (sourceModel()) QMetaObject::invokeMethod(sourceModel(), "remove", Qt::DirectConnection, Q_ARG(QString, id));
}
bool ClipboardHistoryModel::removeRows(int row, int count, const QModelIndex &parent) {
    const QScopedValueRollback selecting(m_selecting, true);
    if (sourceModel() && !parent.isValid() && row == 0 && count == rowCount())
        return sourceModel()->removeRows(0, sourceModel()->rowCount());
    return QSortFilterProxyModel::removeRows(row, count, parent);
}
void ClipboardHistoryModel::persist() {
    QDir().mkpath(QFileInfo(m_path).absolutePath());
    QSaveFile file(m_path);
    if (!file.open(QIODevice::WriteOnly)) return;
    file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    file.write(QJsonDocument(QJsonArray::fromStringList(m_order)).toJson(QJsonDocument::Compact));
    file.commit();
}
