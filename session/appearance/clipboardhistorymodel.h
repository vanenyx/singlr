#pragma once
#include <QSortFilterProxyModel>
#include <QStringList>
#include <QtQml/qqmlregistration.h>

// Klipper retains clipboard ownership/MIME restoration. This view tracks copy
// order independently of Klipper's move-to-top-on-selection convention.
class ClipboardHistoryModel : public QSortFilterProxyModel {
    Q_OBJECT
    QML_ELEMENT
public:
    explicit ClipboardHistoryModel(QObject *parent = nullptr);
    void setSourceModel(QAbstractItemModel *model) override;
    Q_INVOKABLE void select(const QString &uuid);
    Q_INVOKABLE void remove(const QString &uuid);
    bool removeRows(int row, int count, const QModelIndex &parent = {}) override;
protected:
    bool lessThan(const QModelIndex &left, const QModelIndex &right) const override;
private Q_SLOTS:
    void sourceActivated();
private:
    QString uuid(const QModelIndex &index) const;
    void reconcile();
    void persist();
    QStringList m_order;
    QString m_path;
    int m_uuidRole = -1;
    bool m_selecting = false;
};
