#pragma once
#include <KRunner/ResultsModel>
#include <KRunner/QueryMatch>
#include <KRunner/AbstractRunner>
#include <KRunner/RunnerManager>
#include <KPluginMetaData>
#include <QtQml/qqmlregistration.h>

// KRunner keeps match/runner identity opaque to QML. Expose the actual origin,
// including for unique-result IDs which intentionally have no runner prefix.
class CommandSourceModel : public KRunner::ResultsModel
{
    Q_OBJECT
    QML_ELEMENT
public:
    explicit CommandSourceModel(QObject *parent = nullptr) : KRunner::ResultsModel(parent) {
        // The software-store runner loads the whole AppStream catalogue into the
        // shell: ~70 MB per search, ~35 MB never returned. Plasma keeps it out of
        // plasmashell too; installing software is Discover's job.
        QStringList allowed;
        for (const auto &meta : KRunner::RunnerManager::runnerMetaDataList())
            if (meta.pluginId() != QLatin1String("krunner_appstream")) allowed << meta.pluginId();
        runnerManager()->setAllowedRunners(allowed);
    }
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
