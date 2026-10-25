// T222: pure tests and protocol fixtures. No KDE services or native QMenus.
#include "tray.h"
#include "system.h"
#include <QTimer>
#include "trayformat.h"
#include <QCoreApplication>
#include <QDBusMessage>
#include <QDBusMetaType>
#include <QDBusObjectPath>
#include <QDBusReply>
#include <QDBusVariant>
#include <QDBusVirtualObject>
#include <QElapsedTimer>
#include <QGuiApplication>
#include <QProcess>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQmlExpression>
#include <QThread>
#include <iostream>
#include <stdexcept>

#define CHECK(...) do { if (!(__VA_ARGS__)) throw std::runtime_error("line " + std::to_string(__LINE__) + ": " #__VA_ARGS__); } while (false)

namespace {
const QString service = QStringLiteral("org.singlr.TrayFixture");
const QString watcher = QStringLiteral("org.kde.StatusNotifierWatcher");
const QString properties = QStringLiteral("org.freedesktop.DBus.Properties");
const QString itemInterface = QStringLiteral("org.kde.StatusNotifierItem");
const QString menuInterface = QStringLiteral("com.canonical.dbusmenu");

using WirePixmap = std::tuple<int, int, QByteArray>;
QVariant pixmapWire(int size = 32, const QByteArray &pixel = QByteArray::fromHex("80123456"))
{
    QDBusArgument arg;
    arg << QList<WirePixmap>{{size, size, pixel.repeated(size * size)}};
    return QVariant::fromValue(arg);
}

QVariant menuNode(int id, const QVariantMap &properties = {}, const QVariantList &children = {})
{
    QDBusArgument arg;
    arg.beginStructure();
    arg << id << properties;
    arg.beginArray(QMetaType::fromType<QDBusVariant>());
    for (const auto &child : children)
        arg << QDBusVariant(child);
    arg.endArray();
    arg.endStructure();
    return QVariant::fromValue(arg);
}
QVariant layout()
{
    return menuNode(0, {}, {
        menuNode(1, {{"label", "_Abrir __archivo_"}, {"icon-name", "document-open"}}),
        menuNode(2, {{"type", "separator"}}),
        menuNode(3, {{"label", "_Opciones"}, {"enabled", false}}, {
            menuNode(4, {{"label", "_Activado"}, {"toggle-type", "checkmark"}, {"toggle-state", 1}}),
            menuNode(5, {{"visible", false}, {"toggle-type", "radio"}, {"toggle-state", 0}})}),
        menuNode(6, {{"toggle-state", -1}})});
}
QVariant tooltip()
{
    QDBusArgument arg;
    arg.beginStructure();
    arg << QStringLiteral("fixture");
    arg << QList<WirePixmap>{};
    arg << QString::fromUtf8("Título de prueba") << QStringLiteral("Description");
    arg.endStructure();
    return QVariant::fromValue(arg);
}

void pixmaps()
{
    // Fixture construction also runs without a bus; catches invalid variant
    // nesting before the optional protocol roundtrip test can be attempted.
    CHECK(layout().value<QDBusArgument>().currentSignature() == "(ia{sv}av)");
    CHECK(pixmapWire().value<QDBusArgument>().currentSignature() == "a(iiay)");
    CHECK(tooltip().value<QDBusArgument>().currentSignature() == "(sa(iiay)ss)");
    using TrayFormat::Pixmap;
    const QByteArray color = QByteArray::fromHex("80123456ffabcdef");
    auto image = TrayFormat::image({Pixmap{2, 1, color}});
    CHECK(image.size() == QSize(2, 1));
    CHECK(image.format() == QImage::Format_ARGB32);
    CHECK(image.pixel(0, 0) == 0x80123456u);
    CHECK(image.pixel(1, 0) == 0xffabcdefu);
    CHECK(image.pixelColor(0, 0).alpha() == 128);
    const auto p = [](int w, int h) { return Pixmap{w, h, QByteArray(w * h * 4, '\x7f')}; };
    CHECK(TrayFormat::image({p(16, 16), p(48, 48), p(24, 24), p(32, 32)}).size() == QSize(32, 32));
    CHECK(TrayFormat::image({p(16, 16), p(24, 24), p(48, 48)}).size() == QSize(24, 24));
    CHECK(TrayFormat::image({p(24, 24), p(40, 40)}).size() == QSize(40, 40));
    CHECK(TrayFormat::image({p(32, 20)}).size() == QSize(32, 20));
    CHECK(TrayFormat::image({Pixmap{-1, 1, {}}, Pixmap{0, 0, {}}, Pixmap{4097, 1, {}},
                             Pixmap{32, 32, "short"}, Pixmap{1, 1, "extra"}}).isNull());
    CHECK(TrayFormat::image(QVariant()).isNull());
    CHECK(TrayFormat::menu(42).isEmpty());
    CHECK(TrayFormat::toolTipTitle(42).isEmpty());
    CHECK(TrayFormat::label(QString::fromUtf8("_Árbol __x _y_")).toUtf8() == "Árbol _x y");
}

void model()
{
    TrayModel model;
    int inserted = 0, removed = 0, changed = 0;
    QObject::connect(&model, &QAbstractItemModel::rowsInserted, [&] { ++inserted; });
    QObject::connect(&model, &QAbstractItemModel::rowsRemoved, [&] { ++removed; });
    QObject::connect(&model, &QAbstractItemModel::dataChanged, [&] { ++changed; });
    const QVariantMap active{{"status", "Active"}, {"title", "One"}};
    model.update("a", active);
    model.update("a", active);
    CHECK(inserted == 1 && changed == 0 && model.rowCount() == 1);
    CHECK(model.roleNames().size() == 12);
    CHECK(model.rowCount(model.index(0)) == 0);
    CHECK(!model.data({}, Qt::UserRole + 1).isValid());
    model.update("a", {{"status", "NeedsAttention"}, {"title", "Two"}});
    CHECK(changed == 1);
    model.update("b", {{"status", "Passive"}});
    CHECK(model.rowCount() == 1);
    model.update("a", {{"status", "Passive"}});
    CHECK(model.rowCount() == 0 && removed == 1);
    model.update("a", active);
    CHECK(inserted == 2);
    model.remove("missing");
    model.remove("a");
    CHECK(removed == 2);

    const auto images = std::make_shared<TrayImages>();
    images->images.insert("1", QImage(32, 32, QImage::Format_ARGB32));
    TrayImageProvider provider(images);
    QSize size;
    CHECK(provider.requestImage("1?v=9", &size, {16, 16}).size() == QSize(16, 16));
    CHECK(size == QSize(32, 32));
    CHECK(provider.requestImage("missing", &size, {}).isNull());
    CHECK(size.isEmpty());
}

// A separate process forces real D-Bus marshalling; Qt's same-connection local
// call shortcut would otherwise bypass QDBusArgument demarshalling entirely.
class Fixture final : public QDBusVirtualObject
{
public:
    QString status = QStringLiteral("Active");
    QString title = QStringLiteral("Fixture");
    QStringList addresses{service + "/Active", service + "/Passive"};
    QVariantMap calls;
    QStringList order;
    QString host;
    QString menuMode;
    bool effectLoaded = true;
    QString introspect(const QString &) const override { return {}; }
    bool handleMessage(const QDBusMessage &m, const QDBusConnection &bus) override
    {
        const auto args = m.arguments();
        QVariantList reply;
        if (m.member() == QLatin1String("isEffectLoaded")) {
            CHECK(m.path() == "/Effects" && m.interface() == "org.kde.kwin.Effects");
            CHECK(args == QVariantList({"singlr-overview"}));
            reply = {effectLoaded};
        } else if (m.member() == QLatin1String("EffectLoaded")) {
            effectLoaded = args[0].toBool();
        } else if (m.member() == QLatin1String("invokeShortcut")) {
            CHECK(m.path() == "/component/kwin" && m.interface() == "org.kde.kglobalaccel.Component");
            calls.insert(m.member(), args);
        } else if (m.member() == QLatin1String("MenuMode")) {
            menuMode = args[0].toString();
        } else if (m.path() == QLatin1String("/StatusNotifierWatcher")) {
            if (m.member() == QLatin1String("RegisterStatusNotifierHost"))
                host = args[0].toString();
            else if (m.member() == QLatin1String("Get"))
                reply = {QVariant::fromValue(QDBusVariant(addresses))};
            else
                return false;
        } else if (m.member() == QLatin1String("GetAll")) {
            const QVariantMap props{{"Id", m.path()}, {"Title", title}, {"Category", "ApplicationStatus"},
                {"Status", m.path() == QLatin1String("/Passive") ? QStringLiteral("Passive") : status},
                {"IconName", "fixture-normal"}, {"IconPixmap", pixmapWire()},
                {"AttentionIconName", "fixture-attention"}, {"AttentionIconPixmap", pixmapWire(24)},
                {"ToolTip", tooltip()}, {"ItemIsMenu", true}, {"Menu", QVariant::fromValue(QDBusObjectPath("/Menu"))}};
            reply = {props};
        } else if (m.member() == QLatin1String("GetLayout")) {
            CHECK(args.size() == 3 && args[0].toInt() == 0 && args[1].toInt() == -1 && args[2].toStringList().isEmpty());
            order.append(m.member());
            if (menuMode == "error") {
                bus.send(m.createErrorReply("org.singlr.Error", "Fixture failure"));
                return true;
            }
            reply = menuMode == "invalid" ? QVariantList{uint(7), QString("bad")} : QVariantList{uint(7), layout()};
            if (menuMode == "delay") {
                QTimer::singleShot(200, this, [bus, m, reply] { bus.send(m.createReply(reply)); });
                return true;
            }
        } else if (m.member() == QLatin1String("AboutToShow")) {
            CHECK(args[0].toInt() == 0);
            order.append(m.member());
            bus.send(m.createErrorReply("org.freedesktop.DBus.Error.UnknownMethod", "optional"));
            return true;
        } else if (m.member() == QLatin1String("Wire")) {
            reply = {layout(), pixmapWire(), tooltip(), menuNode(0)};
        } else if (m.member() == QLatin1String("Dump")) {
            reply = {QVariantMap{{"host", host}, {"order", order}, {"calls", calls}}};
        } else if (m.member() == QLatin1String("Change")) {
            title = args[0].toString();
            status = args[1].toString();
            for (const auto &name : {"NewTitle", "NewIcon", "NewToolTip", "NewAttentionIcon", "NewStatus"}) {
                auto signal = QDBusMessage::createSignal("/Active", itemInterface, QString::fromLatin1(name));
                if (QString::fromLatin1(name) == QLatin1String("NewStatus"))
                    signal << status;
                bus.send(signal);
            }
            bus.send(QDBusMessage::createSignal("/Menu", menuInterface, "LayoutUpdated") << uint(8) << 0);
        } else if (m.member() == QLatin1String("StatusOnly")) {
            status = args[0].toString();
            bus.send(QDBusMessage::createSignal("/Active", itemInterface, "NewStatus") << status);
        } else if (m.member() == QLatin1String("LayoutOnly")) {
            bus.send(QDBusMessage::createSignal("/Menu", menuInterface, "LayoutUpdated") << uint(9) << 0);
        } else if (m.member() == QLatin1String("Unregister")) {
            addresses.removeAll(service + "/Active");
            bus.send(QDBusMessage::createSignal("/StatusNotifierWatcher", watcher, "StatusNotifierItemUnregistered") << service + "/Active");
        } else if (m.member() == QLatin1String("Register")) {
            addresses.append(service + "/Active");
            bus.send(QDBusMessage::createSignal("/StatusNotifierWatcher", watcher, "StatusNotifierItemRegistered") << service + "/Active");
        } else if (m.member() == QLatin1String("Restart")) {
            auto connection = bus;
            connection.unregisterService(watcher);
            CHECK(connection.registerService(watcher));
            host.clear();
        } else if (m.member() == QLatin1String("Activate") || m.member() == QLatin1String("SecondaryActivate")
                   || m.member() == QLatin1String("Scroll") || m.member() == QLatin1String("Event")) {
            calls.insert(m.member(), args);
        } else {
            return false;
        }
        bus.send(m.createReply(reply));
        return true;
    }
};

QDBusMessage invoke(const QString &method, const QVariantList &args = {})
{
    auto m = QDBusMessage::createMethodCall(service, "/Active", "org.singlr.Fixture", method);
    m.setArguments(args);
    const auto reply = QDBusConnection::sessionBus().call(m, QDBus::Block, 2000);
    CHECK(reply.type() == QDBusMessage::ReplyMessage);
    return reply;
}

template<class Predicate> void until(Predicate predicate)
{
    QElapsedTimer time;
    time.start();
    while (!predicate() && time.elapsed() < 5000) {
        QCoreApplication::processEvents();
        QThread::msleep(5);
    }
    CHECK(predicate());
}
QVariant value(QAbstractItemModel *model, const QByteArray &name)
{
    return model->data(model->index(0, 0), model->roleNames().key(name));
}

void wire()
{
    QProcess server;
    server.setProcessChannelMode(QProcess::ForwardedErrorChannel);
    server.start(QCoreApplication::applicationFilePath(), {"server"});
    CHECK(server.waitForStarted());
    CHECK(server.waitForReadyRead());
    CHECK(server.readLine().trimmed() == "READY");
    struct Cleanup { QProcess &p; ~Cleanup() { p.terminate(); p.waitForFinished(); } } cleanup{server};

    const auto args = invoke("Wire").arguments();
    CHECK(args[0].metaType() == QMetaType::fromType<QDBusArgument>());
    const auto nodes = TrayFormat::menu(args[0]);
    CHECK(nodes.size() == 4);
    const auto first = nodes[0].toMap();
    CHECK(first.value("id") == 1 && first.value("label") == "Abrir _archivo");
    CHECK(first.value("enabled").toBool() && first.value("visible").toBool());
    CHECK(first.value("type") == "standard" && first.value("iconName") == "document-open");
    CHECK(nodes[1].toMap().value("type") == "separator");
    const auto options = nodes[2].toMap();
    CHECK(!options.value("enabled").toBool());
    const auto children = options.value("children").toList();
    CHECK(children.size() == 2);
    CHECK(children[0].toMap().value("toggleType") == "checkmark");
    CHECK(children[0].toMap().value("toggleState") == 1);
    CHECK(!children[1].toMap().value("visible").toBool());
    CHECK(children[1].toMap().value("toggleType") == "radio");
    CHECK(children[1].toMap().value("toggleState") == 0);
    CHECK(nodes[3].toMap().value("toggleState") == -1);
    CHECK(TrayFormat::menu(args[3]).isEmpty());
    CHECK(TrayFormat::menu(args[1]).isEmpty()); // wrong structured signature
    CHECK(TrayFormat::image(args[0]).isNull());
    CHECK(TrayFormat::image(args[1]).pixel(0, 0) == 0x80123456u);
    CHECK(TrayFormat::toolTipTitle(args[2]) == QString::fromUtf8("Título de prueba"));

    Tray tray;
    auto *model = tray.items();
    int menuChanges = 0;
    QObject::connect(&tray, &Tray::menuChanged, [&](const QString &s) { CHECK(s == service); ++menuChanges; });
    until([&] { return model->rowCount() == 1; });
    CHECK(value(model, "path") == "/Active");
    CHECK(value(model, "status") == "Active");
    CHECK(value(model, "iconName") == "fixture-normal");
    CHECK(value(model, "toolTipTitle") == QString::fromUtf8("Título de prueba"));
    const QString source = value(model, "iconSource").toUrl().toString();
    CHECK(source.startsWith("image://singlrtray/"));
    std::unique_ptr<QQuickImageProvider> provider(tray.createImageProvider());
    CHECK(provider->requestImage(source.mid(19), nullptr, {}).size() == QSize(32, 32));
    CHECK(value(model, "hasAttentionIcon").toBool());
    QVariantList menuItems;
    int ready = 0, failed = 0;
    QObject::connect(&tray, &Tray::menuReady, &tray, [&](const QString &s, const QString &p, const QVariantList &items) {
        CHECK(s == service && p == "/Menu"); menuItems = items; ++ready;
    });
    QObject::connect(&tray, &Tray::menuFailed, &tray, [&](const QString &, const QString &, const QString &error) {
        CHECK(!error.isEmpty()); ++failed;
    });
    tray.requestMenu(service, "/Menu");
    CHECK(ready == 0);
    until([&] { return ready == 1; });
    CHECK(menuItems.size() == 4);
    tray.requestMenu(service, "/wrong");
    CHECK(failed == 1);
    tray.activate(service, "/Active", 17, 18);
    tray.secondaryActivate(service, "/Active", 19, 20);
    tray.scroll(service, "/Active", -120, "vertical");
    tray.activateMenuItem(service, "/Menu", 4);
    until([&] { return qdbus_cast<QVariantMap>(qdbus_cast<QVariantMap>(invoke("Dump").arguments()[0]).value("calls")).size() == 4; });
    const auto dump = qdbus_cast<QVariantMap>(invoke("Dump").arguments()[0]);
    CHECK(dump.value("host").toString().startsWith("org.kde.StatusNotifierHost-"));
    CHECK(qdbus_cast<QStringList>(dump.value("order")) == QStringList({"AboutToShow", "GetLayout"}));
    for (const auto &mode : {"error", "invalid"}) {
        invoke("MenuMode", {QString::fromLatin1(mode)});
        tray.requestMenu(service, "/Menu");
        const int before = failed;
        until([&] { return failed > before; });
    }
    invoke("MenuMode", {"delay"});
    bool tick = false;
    QTimer::singleShot(20, &tray, [&] { tick = true; });
    tray.requestMenu(service, "/Menu");
    until([&] { return tick; });
    CHECK(ready == 1);
    until([&] { return ready == 2; });
    System system;
    CHECK(!system.overviewAvailable());
    until([&] { return system.overviewAvailable(); });
    system.invokeShortcut("kwin", "Singlr Overview");
    until([&] { return qdbus_cast<QVariantMap>(qdbus_cast<QVariantMap>(invoke("Dump").arguments()[0]).value("calls")).contains("invokeShortcut"); });
    CHECK(qdbus_cast<QVariantList>(qdbus_cast<QVariantMap>(qdbus_cast<QVariantMap>(invoke("Dump").arguments()[0]).value("calls")).value("invokeShortcut")) == QVariantList({"Singlr Overview"}));
    invoke("EffectLoaded", {false});
    QElapsedTimer poll; poll.start();
    while (system.overviewAvailable() && poll.elapsed() < 12000) {
        QCoreApplication::processEvents(); QThread::msleep(5);
    }
    CHECK(!system.overviewAvailable());
    const auto calls = qdbus_cast<QVariantMap>(dump.value("calls"));
    CHECK(qdbus_cast<QVariantList>(calls.value("Activate")) == QVariantList({17, 18}));
    CHECK(qdbus_cast<QVariantList>(calls.value("SecondaryActivate")) == QVariantList({19, 20}));
    CHECK(qdbus_cast<QVariantList>(calls.value("Scroll")) == QVariantList({-120, "vertical"}));
    const auto event = qdbus_cast<QVariantList>(calls.value("Event"));
    CHECK(event.size() == 4 && event[0] == 4 && event[1] == "clicked");
    CHECK(event[2].value<QDBusVariant>().variant().toInt() == 0);
    CHECK(event[3].metaType() == QMetaType::fromType<uint>());
    const int layoutBefore = menuChanges;
    invoke("LayoutOnly");
    until([&] { return menuChanges > layoutBefore; });
    invoke("StatusOnly", {"Passive"});
    until([&] { return model->rowCount() == 0; });
    invoke("StatusOnly", {"Active"});
    until([&] { return model->rowCount() == 1; });
    const int before = menuChanges;
    invoke("Change", {"Changed", "NeedsAttention"});
    until([&] { return value(model, "title") == "Changed" && value(model, "status") == "NeedsAttention"; });
    CHECK(menuChanges > before);
    CHECK(value(model, "iconName") == "fixture-attention");
    CHECK(value(model, "iconSource").toUrl().toString() != source);
    invoke("Change", {"Hidden", "Passive"});
    until([&] { return model->rowCount() == 0; });
    invoke("Change", {"Back", "Active"});
    until([&] { return model->rowCount() == 1 && value(model, "title") == "Back"; });
    invoke("Unregister");
    until([&] { return model->rowCount() == 0; });
    invoke("Register");
    until([&] { return model->rowCount() == 1; });
    invoke("Restart");
    until([&] { return !qdbus_cast<QVariantMap>(invoke("Dump").arguments()[0]).value("host").toString().isEmpty()
                       && model->rowCount() == 1; });

    QQmlEngine engine;
    QQmlExpression absent(engine.rootContext(), nullptr, "typeof SinglrTray");
    CHECK(absent.evaluate() == "undefined");
    engine.rootContext()->setContextProperty("SinglrTray", &tray);
    QQmlExpression present(engine.rootContext(), nullptr, "SinglrTray.items === undefined");
    CHECK(!present.evaluate().toBool() && !present.hasError());
}
}

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    qDBusRegisterMetaType<WirePixmap>();
    qDBusRegisterMetaType<QList<WirePixmap>>();
    try {
        const QString test = argc > 1 ? QString::fromLocal8Bit(argv[1]) : QString();
        if (test == QLatin1String("server")) {
            auto bus = QDBusConnection::sessionBus();
            Fixture fixture;
            CHECK(bus.registerService(service));
            CHECK(bus.registerService(watcher));
            CHECK(bus.registerService("org.kde.KWin"));
            CHECK(bus.registerService("org.kde.kglobalaccel"));
            CHECK(bus.registerVirtualObject("/", &fixture, QDBusConnection::SubPath));
            std::cout << "READY" << std::endl;
            return app.exec();
        }
        if (test == QLatin1String("pixmaps")) pixmaps();
        else if (test == QLatin1String("model")) model();
        else if (test == QLatin1String("wire")) wire();
        else throw std::runtime_error("unknown test");
        std::cout << "PASS " << test.toStdString() << '\n';
    } catch (const std::exception &error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
