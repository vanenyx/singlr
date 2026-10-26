// Test-only KWin 6.8.1 backend control. No installed plugin or production hooks.
#include <plugin.h>
#include <main.h>
#include <core/outputbackend.h>
#include <QDBusConnection>

class OutputControl : public KWin::Plugin
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.singlr.TestOutputs")
public:
    OutputControl() {
        QDBusConnection::sessionBus().registerObject(QStringLiteral("/SinglrTestOutputs"), this,
                                                    QDBusConnection::ExportAllSlots);
    }
    ~OutputControl() override {
        QDBusConnection::sessionBus().unregisterObject(QStringLiteral("/SinglrTestOutputs"));
    }
public Q_SLOTS:
    int count() const { return KWin::kwinApp()->outputBackend()->outputs().size(); }
    void removeAll() {
        auto *backend = KWin::kwinApp()->outputBackend();
        const auto outputs = backend->outputs();
        for (auto *output : outputs) backend->removeVirtualOutput(output);
    }
    bool add(const QString &name) {
        return KWin::kwinApp()->outputBackend()->createVirtualOutput(name, name, QSize(1280, 800), 1) != nullptr;
    }
};

class Factory : public KWin::PluginFactory
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID PluginFactory_iid FILE "output-control.json")
    Q_INTERFACES(KWin::PluginFactory)
public:
    std::unique_ptr<KWin::Plugin> create() const override {
        // Even accidental discovery in a normal session cannot remove its outputs.
        if (qEnvironmentVariable("SINGLR_TEST_OUTPUT_CONTROL") != QLatin1String("1")
            || QByteArray(KWin::kwinApp()->outputBackend()->metaObject()->className()) != "KWin::VirtualBackend")
            return {};
        return std::make_unique<OutputControl>();
    }
};
#include "output-control.moc"
