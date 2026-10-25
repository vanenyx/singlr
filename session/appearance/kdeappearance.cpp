#include "kdeappearance.h"
#include <QGuiApplication>
#include <QQuickWindow>
#include <QPalette>
#include <QSettings>
#include <QStandardPaths>
#include <QDir>
#include <QEvent>
#include <QFileInfo>
#include <QRegularExpression>
#include <KConfigGroup>
#include <KConfigGui>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>
#include <algorithm>

namespace {
QString configPath() {
    return QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + QStringLiteral("/singlr/singlr.conf");
}
}
KDEAppearance::KDEAppearance(QObject *parent) : QObject(parent),
    m_config(KSharedConfig::openConfig(QStringLiteral("kdeglobals"))),
    m_watcher(KConfigWatcher::create(m_config))
{
    qGuiApp->installEventFilter(this);
    connect(m_watcher.data(), &KConfigWatcher::configChanged, this, &KDEAppearance::changed);
    connect(&m_process, &QProcess::finished, this, [this](int code, QProcess::ExitStatus status) {
        if (code != 0 || status != QProcess::NormalExit) {
            m_error = QStringLiteral("No se pudo aplicar la apariencia de KDE: ") + QString::fromUtf8(m_process.readAllStandardError());
            m_queue.clear();
            m_migrating = false;
            m_migrationLock.reset();
        }
        next();
    });
    connect(&m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            m_error = m_process.errorString();
            m_queue.clear();
            m_migrating = false;
            m_migrationLock.reset();
            Q_EMIT changed();
        }
    });
    // Open by name relative to the config dir: KConfigWatcher only delivers KConfig::Notify
    // change signals for such configs ("Watching absolute paths is not supported").
    m_materialConfig = KSharedConfig::openConfig(QStringLiteral("singlr/singlr.conf"), KConfig::SimpleConfig);
    m_materialWatcher = KConfigWatcher::create(m_materialConfig);
    connect(m_materialWatcher.data(), &KConfigWatcher::configChanged, this, [this] {
        refreshMaterials();
    });
    auto *kwinWatcher = new QDBusServiceWatcher(QStringLiteral("org.kde.KWin"), QDBusConnection::sessionBus(),
        QDBusServiceWatcher::WatchForOwnerChange, this);
    connect(kwinWatcher, &QDBusServiceWatcher::serviceOwnerChanged, this, [this] { checkGlass(); });
    QDBusConnection::sessionBus().connect(QStringLiteral("org.kde.KWin"), QStringLiteral("/Effects"),
        QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("PropertiesChanged"),
        this, SLOT(refreshMaterials()));
    refreshMaterials();
    migrate();
}
bool KDEAppearance::softwareRendering() const {
    return QQuickWindow::graphicsApi() == QSGRendererInterface::Software
        || qEnvironmentVariable("QT_QUICK_BACKEND") == QLatin1String("software");
}
QString KDEAppearance::material() const {
    const auto value = m_materialConfig->group("Appearance").readEntry("material", QStringLiteral("glass"));
    return value == QLatin1String("solid") ? value : QStringLiteral("glass");
}
int KDEAppearance::intensity() const {
    return std::clamp(m_materialConfig->group("Appearance").readEntry("intensity", 65), 0, 100);
}
bool KDEAppearance::reduceTransparency() const {
    return m_materialConfig->group("Accessibility").readEntry("reduceTransparency", false);
}
QString KDEAppearance::dockMode() const {
    return m_materialConfig->group("Dock").readEntry("mode", QStringLiteral("floating")) == QLatin1String("fixed")
        ? QStringLiteral("fixed") : QStringLiteral("floating");
}
int KDEAppearance::dockHeight() const {
    const int value = m_materialConfig->group("Dock").readEntry("height", 48);
    return 40 + ((std::clamp(value, 40, 72) - 40 + 4) / 8) * 8;
}
bool KDEAppearance::dockAutoHide() const {
    return m_materialConfig->group("Dock").readEntry("autoHide", false);
}
void KDEAppearance::setDockMode(const QString &mode) {
    if (mode != QLatin1String("floating") && mode != QLatin1String("fixed")) return;
    m_materialConfig->reparseConfiguration();
    m_materialConfig->group("Dock").writeEntry("mode", mode, KConfig::Notify);
    m_materialConfig->sync(); Q_EMIT changed();
}
void KDEAppearance::setDockHeight(int height) {
    const int value = 40 + ((std::clamp(height, 40, 72) - 40 + 4) / 8) * 8;
    m_materialConfig->reparseConfiguration();
    m_materialConfig->group("Dock").writeEntry("height", value, KConfig::Notify);
    m_materialConfig->sync(); Q_EMIT changed();
}
void KDEAppearance::setDockAutoHide(bool enabled) {
    m_materialConfig->reparseConfiguration();
    m_materialConfig->group("Dock").writeEntry("autoHide", enabled, KConfig::Notify);
    m_materialConfig->sync(); Q_EMIT changed();
}
void KDEAppearance::setMaterial(const QString &value) {
    if (value != QLatin1String("solid") && value != QLatin1String("glass")) return;
    m_materialConfig->reparseConfiguration();
    m_materialConfig->group("Appearance").writeEntry("material", value, KConfig::Notify);
    m_materialConfig->sync(); refreshMaterials();
}
void KDEAppearance::setIntensity(int value) {
    m_materialConfig->reparseConfiguration();
    m_materialConfig->group("Appearance").writeEntry("intensity", std::clamp(value, 0, 100), KConfig::Notify);
    m_materialConfig->sync(); refreshMaterials();
}
void KDEAppearance::setReduceTransparency(bool value) {
    m_materialConfig->reparseConfiguration();
    m_materialConfig->group("Accessibility").writeEntry("reduceTransparency", value, KConfig::Notify);
    m_materialConfig->sync(); refreshMaterials();
}
void KDEAppearance::refreshMaterials() {
    m_materialConfig->reparseConfiguration();
    auto appearance = m_materialConfig->group("Appearance");
    // P-021: persist once; subsequent reloads do not rewrite the profile.
    if (appearance.readEntry("material", QString()) == QLatin1String("liquid")) {
        appearance.writeEntry("material", "glass", KConfig::Notify);
        m_materialConfig->sync();
    }
    applyMaterial(); checkGlass(); Q_EMIT changed();
}
void KDEAppearance::applyMaterial() {
    // Only a session with the durable apply/restore journal may change kwinrc.
    const auto journal = QStandardPaths::writableLocation(QStandardPaths::GenericStateLocation)
        + QStringLiteral("/singlr/kwinrc-backup.json");
    if (qEnvironmentVariable("XDG_SESSION_DESKTOP") != QLatin1String("Singlr")
        || !QFileInfo::exists(journal)) return;
    auto config = KSharedConfig::openConfig(QStringLiteral("kwinrc"));
    config->reparseConfiguration();
    auto group = config->group("Effect-singlrliquidglass");
    const bool enabled = material() == QLatin1String("glass") && intensity() > 0 && !reduceTransparency();
    if (group.readEntry("Enabled", false) == enabled && group.readEntry("Intensity", 65) == intensity()) return;
    group.writeEntry("Enabled", enabled, KConfig::Notify);
    group.writeEntry("Intensity", intensity(), KConfig::Notify);
    config->sync();
    // As KDE's effect KCMs do: KWin::reconfigure() does not re-read a loaded effect's settings.
    auto message = QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"), QStringLiteral("/Effects"),
        QStringLiteral("org.kde.kwin.Effects"), QStringLiteral("reconfigureEffect"));
    message << QStringLiteral("singlr-liquidglass");
    QDBusConnection::sessionBus().asyncCall(message);
}
void KDEAppearance::checkGlass() {
    if (m_checkingGlass) return;
    m_checkingGlass = true;
    auto message = QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"), QStringLiteral("/Effects"),
        QStringLiteral("org.kde.kwin.Effects"), QStringLiteral("isEffectLoaded"));
    message << QStringLiteral("singlr-liquidglass");
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(message), this);
    const auto finished = [this, watcher] {
        QDBusPendingReply<bool> reply = *watcher;
        const bool available = !reply.isError() && reply.value();
        m_checkingGlass = false;
        if (m_glassAvailable != available) { m_glassAvailable = available; Q_EMIT changed(); }
        watcher->deleteLater();
    };
    if (watcher->isFinished()) finished();
    else connect(watcher, &QDBusPendingCallWatcher::finished, this, finished);
}
bool KDEAppearance::eventFilter(QObject *object, QEvent *event) {
    if (object == qGuiApp && event->type() == QEvent::ApplicationPaletteChange)
        Q_EMIT changed();
    return QObject::eventFilter(object, event);
}
bool KDEAppearance::dark() const { return qGray(QGuiApplication::palette().window().color().rgb()) < 192; }
QColor KDEAppearance::accent() const { return QGuiApplication::palette().highlight().color(); }
QColor KDEAppearance::selectedAccent() const {
    const auto color = m_config->group(QStringLiteral("General")).readEntry("AccentColor", QColor());
    return color.isValid() && color.alpha() > 0 ? color : accent();
}
QString KDEAppearance::mode() const {
    return m_config->group(QStringLiteral("KDE")).readEntry("AutomaticLookAndFeel", false)
        ? QStringLiteral("auto") : dark() ? QStringLiteral("dark") : QStringLiteral("light");
}
void KDEAppearance::setMode(const QString &mode) {
    if (mode != QLatin1String("auto") && mode != QLatin1String("light") && mode != QLatin1String("dark"))
        return;
    m_error.clear();
    auto group = m_config->group(QStringLiteral("KDE"));
    if (mode == QLatin1String("auto")) {
        // Color-only global themes keep Singlr's decoration and other preferences.
        // Explicit alternate global themes chosen in KDE remain authoritative.
        if (!group.hasKey("DefaultLightLookAndFeel"))
            group.writeEntry("DefaultLightLookAndFeel", "dev.singlr.light", KConfig::Notify);
        if (!group.hasKey("DefaultDarkLookAndFeel"))
            group.writeEntry("DefaultDarkLookAndFeel", "dev.singlr.dark", KConfig::Notify);
    }
    group.writeEntry("AutomaticLookAndFeel", mode == QLatin1String("auto"), KConfig::Notify);
    if (!group.sync()) {
        m_error = QStringLiteral("No se pudo guardar la configuración de KDE.");
        Q_EMIT changed();
        return;
    }
    if (mode != QLatin1String("auto"))
        enqueue({QStringLiteral("plasma-apply-colorscheme"), mode == QLatin1String("dark") ? QStringLiteral("BreezeDark") : QStringLiteral("BreezeLight")});
    Q_EMIT changed();
}
void KDEAppearance::setAccent(const QString &accent) {
    static const QRegularExpression valid(QStringLiteral("^#[0-9a-fA-F]{6}$"));
    if (!valid.match(accent).hasMatch())
        return;
    m_error.clear();
    // The CLI applies a supplied accent without saving the preference itself.
    // Persist the same KConfig keys as the Colors KCM before applying it, so
    // KDE's next automatic scheme change retains the user's custom accent.
    auto group = m_config->group(QStringLiteral("General"));
    group.writeEntry("AccentColor", QColor(accent), KConfig::Notify);
    group.writeEntry("LastUsedCustomAccentColor", QColor(accent), KConfig::Notify);
    group.writeEntry("accentColorFromWallpaper", false, KConfig::Notify);
    if (!group.sync()) {
        m_error = QStringLiteral("No se pudo guardar el acento de KDE.");
        Q_EMIT changed();
        return;
    }
    enqueue({QStringLiteral("plasma-apply-colorscheme"), QStringLiteral("--accent-color"), accent});
}
void KDEAppearance::enqueue(const QStringList &command) {
    m_error.clear();
    m_queue.enqueue(command);
    if (m_process.state() == QProcess::NotRunning)
        next();
}
void KDEAppearance::reloadShell() {
    const auto message = QDBusMessage::createMethodCall(QStringLiteral("org.kde.plasmashell"),
        QStringLiteral("/PlasmaShell"), QStringLiteral("org.kde.PlasmaShell"), QStringLiteral("singlrReloadSettings"));
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(message), this);
    const auto finished = [this, watcher]() {
        QDBusPendingReply<> reply = *watcher;
        if (reply.isError()) {
            m_error = QStringLiteral("Guardado. La sesión Singlr no está disponible para recargar.");
            Q_EMIT changed();
        }
        watcher->deleteLater();
    };
    if (watcher->isFinished())
        finished();
    else
        connect(watcher, &QDBusPendingCallWatcher::finished, this, finished);
}
void KDEAppearance::next() {
    if (m_queue.isEmpty()) {
        if (m_migrating)
            finishMigration();
        Q_EMIT changed();
        return;
    }
    auto command = m_queue.dequeue();
    const auto program = command.takeFirst();
    m_process.start(program, command);
    Q_EMIT changed();
}
void KDEAppearance::migrate() {
    QSettings settings(configPath(), QSettings::IniFormat);
    // T239 schema 1 remains valid; this separately marked migration only moves
    // appearance ownership. Preserve newer schemas, wallpaper and unknown keys.
    bool valid = false;
    const int schema = settings.value(QStringLiteral("Config/schemaVersion"), 0).toInt(&valid);
    if (!valid || schema < 0 || schema > 1 || settings.value(QStringLiteral("Config/kdeAppearanceMigrated"), false).toBool())
        return;
    if (!settings.contains(QStringLiteral("Appearance/mode")) && !settings.contains(QStringLiteral("Appearance/accent")))
        return; // Fresh profiles follow KDE without writing defaults.
    QDir().mkpath(QFileInfo(configPath()).absolutePath());
    m_migrationLock = std::make_unique<QLockFile>(configPath() + QStringLiteral(".appearance-migration.lock"));
    if (!m_migrationLock->tryLock(0)) {
        m_migrationLock.reset();
        return;
    }
    if (settings.contains(QStringLiteral("Appearance/mode")))
        setMode(settings.value(QStringLiteral("Appearance/mode")).toString());
    if (m_error.isEmpty() && settings.contains(QStringLiteral("Appearance/accent")))
        setAccent(settings.value(QStringLiteral("Appearance/accent")).toString());
    m_migrating = m_error.isEmpty();
    if (m_migrating && !busy())
        finishMigration();
}
void KDEAppearance::finishMigration() {
    QSettings settings(configPath(), QSettings::IniFormat);
    settings.setValue(QStringLiteral("Config/kdeAppearanceMigrated"), true);
    settings.remove(QStringLiteral("Appearance/mode"));
    settings.remove(QStringLiteral("Appearance/accent"));
    settings.remove(QStringLiteral("Appearance/applyToApps"));
    settings.sync();
    if (settings.status() != QSettings::NoError)
        m_error = QStringLiteral("No se pudo completar la migración de apariencia.");
    m_migrating = false;
    m_migrationLock.reset();
}
