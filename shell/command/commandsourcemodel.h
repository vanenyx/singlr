#pragma once
#include <KRunner/ResultsModel>
#include <KRunner/QueryMatch>
#include <KRunner/AbstractRunner>
#include <QtQml/qqmlregistration.h>

// KRunner keeps match/runner identity opaque to QML. Expose the actual origin,
// including for unique-result IDs which intentionally have no runner prefix.
class CommandSourceModel : public KRunner::ResultsModel
{
    Q_OBJECT
    QML_ELEMENT
public:
    using KRunner::ResultsModel::ResultsModel;
    enum { RunnerIdRole = Qt::UserRole + 100 };
    QHash<int, QByteArray> roleNames() const override {
        auto roles = KRunner::ResultsModel::roleNames();
        roles.insert(RunnerIdRole, "runnerId");
        return roles;
    }
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override {
        if (role == RunnerIdRole) {
            const auto match = getQueryMatch(index);
            return match.runner() ? match.runner()->id() : QString();
        }
        return KRunner::ResultsModel::data(index, role);
    }
};
