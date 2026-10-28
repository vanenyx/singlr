#include "clipboardhistorymodel.h"
#include <QAbstractListModel>
#include <QJsonArray>
#include <QJsonDocument>
#include <QFile>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QtTest>

class History final : public QAbstractListModel {
    Q_OBJECT
public:
    History() { connect(this,&QAbstractItemModel::rowsRemoved,this,&History::currentTextChanged); }
    QStringList ids{QStringLiteral("a"), QStringLiteral("b"), QStringLiteral("c"), QStringLiteral("d")};
    int rowCount(const QModelIndex &parent = {}) const override { return parent.isValid() ? 0 : ids.size(); }
    QHash<int,QByteArray> roleNames() const override { return {{Qt::UserRole+1,"uuid"},{Qt::DisplayRole,"display"}}; }
    QVariant data(const QModelIndex &i,int role) const override {
        return i.isValid() && (role == Qt::UserRole+1 || role == Qt::DisplayRole) ? ids.value(i.row()) : QVariant();
    }
    void copy(const QString &id) {
        const int row=ids.indexOf(id);
        if (row<0) { beginInsertRows({},0,0); ids.prepend(id); endInsertRows(); }
        else if (row>0) { beginMoveRows({},row,row,{},0); ids.move(row,0); Q_EMIT currentTextChanged(); endMoveRows(); return; }
        Q_EMIT currentTextChanged();
    }
    bool removeRows(int row,int count,const QModelIndex &parent={}) override {
        if (parent.isValid() || row<0 || count<=0 || row+count>ids.size()) return false;
        beginRemoveRows({},row,row+count-1);ids.remove(row,count);endRemoveRows();return true;
    }
Q_SIGNALS:
    void currentTextChanged();
};
class Declarative final : public QSortFilterProxyModel {
    Q_OBJECT
public:
    explicit Declarative(History *history) : native(history) {
        setSourceModel(history);
        connect(history,&History::currentTextChanged,this,&Declarative::currentTextChanged);
    }
    Q_INVOKABLE void moveToTop(const QString &id) { native->copy(id); }
    Q_INVOKABLE void remove(const QString &id) { const int row=native->ids.indexOf(id);if(row>=0)native->removeRows(row,1); }
    History *native;
Q_SIGNALS:
    void currentTextChanged();
};
class ClipboardHistoryTest final : public QObject {
    Q_OBJECT
    QStringList order(QAbstractItemModel &m) { QStringList ids;for(int i=0;i<m.rowCount();++i)ids.append(m.index(i,0).data(Qt::UserRole+1).toString());return ids; }
private Q_SLOTS:
    void removingAnotherItemDoesNotPromoteTheLastSelection() {
        QTemporaryDir dir;qputenv("XDG_STATE_HOME",dir.path().toUtf8());
        History native;Declarative source(&native);ClipboardHistoryModel view;view.setSourceModel(&source);
        view.select(QStringLiteral("d"));
        view.remove(QStringLiteral("b"));
        QTest::qWait(10);QCOMPARE(order(view),QStringList({"a","c","d"}));
    }
    void selectAndCopyHaveDifferentOrdering() {
        QTemporaryDir dir;qputenv("XDG_STATE_HOME",dir.path().toUtf8());
        History native;Declarative source(&native);ClipboardHistoryModel view;view.setSourceModel(&source);
        QCOMPARE(order(view),QStringList({"a","b","c","d"}));
        view.select(QStringLiteral("d"));QCOMPARE(native.ids.first(),QStringLiteral("d"));
        QTest::qWait(10);QCOMPARE(order(view),QStringList({"a","b","c","d"}));
        // Recopying the entry already at native row zero is still a fresh copy.
        native.copy(QStringLiteral("d"));QTRY_COMPARE(order(view),QStringList({"d","a","b","c"}));
        view.select(QStringLiteral("c"));QTest::qWait(10);QCOMPARE(order(view),QStringList({"d","a","b","c"}));
        native.copy(QStringLiteral("new"));QTRY_COMPARE(order(view),QStringList({"new","d","a","b","c"}));
        native.copy(QStringLiteral("b"));QTRY_COMPARE(order(view),QStringList({"b","new","d","a","c"}));
        view.select(QStringLiteral("missing"));QCOMPARE(view.rowCount(),5);
        // Recreate the view: Klipper's current row order must not replace copy order.
        ClipboardHistoryModel restored;restored.setSourceModel(&source);
        QCOMPARE(order(restored),order(view));
        view.remove(QStringLiteral("new"));QCOMPARE(view.rowCount(),4);QVERIFY(!order(view).contains("new"));
        QVERIFY(view.removeRows(0,view.rowCount()));QCOMPARE(native.rowCount(),0);QCOMPARE(view.rowCount(),0);
        QFile state(dir.filePath("singlr/clipboard-order.json"));QVERIFY(state.open(QIODevice::ReadOnly));
        QCOMPARE(QJsonDocument::fromJson(state.readAll()).array().size(),0);
    }
};
QTEST_GUILESS_MAIN(ClipboardHistoryTest)
#include "clipboard_history.moc"
