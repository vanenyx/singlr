#include <KRunner/ResultsModel>
#include <KRunner/QueryMatch>
#include <KRunner/AbstractRunner>
#include <QApplication>
#include <QEventLoop>
#include <QTimer>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <cstdio>

int main(int argc, char **argv) {
    QApplication app(argc, argv);
    if (app.arguments().contains("--metadata")) {
        QJsonArray runners;
        for (const auto &meta : KRunner::RunnerManager::runnerMetaDataList())
            runners.append(QJsonObject{{"runnerId", meta.pluginId()}, {"name", meta.name()}});
        const auto json = QJsonDocument(runners).toJson();
        std::fwrite(json.constData(), 1, json.size(), stdout);
        return 0;
    }
    QJsonArray queries;
    for (const auto &query : {"bluetooth", "wifi", "fondo", "firefox", "2+2", "network", "1 km in m"}) {
        QJsonObject entry{{"query", query}, {"settingsQuery", QString::fromLatin1(query) == "wifi" ? "network" : query}};
        for (const auto &mode : {QString("general"), QString("settings")}) {
            KRunner::ResultsModel model;
            if (mode == "settings") model.setSingleRunner("krunner_systemsettings");
            model.setFavoriteIds({"calculator", "unitconverter"});
            QEventLoop loop;
            bool timedOut = false;
            QTimer timeout; timeout.setSingleShot(true);
            QObject::connect(&timeout, &QTimer::timeout, &loop, [&] { timedOut = true; loop.quit(); });
            QObject::connect(model.runnerManager(), &KRunner::RunnerManager::queryFinished, &loop, &QEventLoop::quit);
            model.setQueryString(mode == "settings" && QString::fromLatin1(query) == "wifi" ? QStringLiteral("network") : QString::fromLatin1(query));
            timeout.start(8000); loop.exec();
            QJsonArray rows;
            for (int i = 0; i < model.rowCount(); ++i) {
                const auto match = model.getQueryMatch(model.index(i, 0));
                QJsonArray urls;
                for (const auto &url : match.urls()) urls.append(url.toString());
                rows.append(QJsonObject{{"id", match.id()}, {"runnerId", match.runner() ? match.runner()->id() : QString()},
                    {"display", match.text()}, {"subtext", match.subtext()}, {"category", match.matchCategory()},
                    {"relevance", match.relevance()}, {"categoryRelevance", match.categoryRelevance()},
                    {"decoration", match.iconName()}, {"urls", urls}, {"actions", QJsonArray()}});
            }
            entry.insert(mode, rows); entry.insert(mode + "TimedOut", timedOut);
        }
        queries.append(entry);
    }
    const auto json = QJsonDocument(QJsonObject{{"queries", queries}}).toJson();
    std::fwrite(json.constData(), 1, json.size(), stdout);
}
