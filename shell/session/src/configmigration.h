#pragma once
#include <QDir>
#include <QFileInfo>
#include <QSettings>
#include <QStandardPaths>

namespace SinglrConfig {
inline QString path()
{
    return QStandardPaths::writableLocation(QStandardPaths::ConfigLocation)
        + QStringLiteral("/singlr/singlr.conf");
}

// Schema 0 is the existing, unversioned Appearance configuration. No values
// need conversion yet. Keep unknown keys and never downgrade a newer schema.
inline bool migrate(const QString &file = path())
{
    if (!QDir().mkpath(QFileInfo(file).absolutePath()))
        return false;
    QSettings settings(file, QSettings::IniFormat);
    bool valid = false;
    const int version = settings.value(QStringLiteral("Config/schemaVersion"), 0).toInt(&valid);
    if (!valid || version < 0 || version > 1)
        return false;
    if (version == 0) {
        settings.setValue(QStringLiteral("Config/schemaVersion"), 1);
        settings.sync();
    }
    return settings.status() == QSettings::NoError;
}
}
