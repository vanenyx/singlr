#include "trayformat.h"

#include <QDBusVariant>
#include <QtEndian>
#include <limits>

namespace TrayFormat {
QImage image(const QList<Pixmap> &pixmaps, int target)
{
    const Pixmap *best = nullptr;
    qint64 distance = std::numeric_limits<qint64>::max();
    for (const auto &p : pixmaps) {
        // Validate before multiplication/allocation. Ignore broken candidates.
        if (p.width <= 0 || p.height <= 0 || p.width > 4096 || p.height > 4096
            || qint64(p.width) * p.height * 4 != p.bytes.size())
            continue;
        const qint64 d = qAbs(qint64(qMax(p.width, p.height)) - target);
        if (d < distance || (d == distance && best && p.width > best->width)) {
            best = &p;
            distance = d;
        }
    }
    if (!best)
        return {};
    QImage result(best->width, best->height, QImage::Format_ARGB32);
    if (result.isNull())
        return {};
    for (int y = 0; y < best->height; ++y) {
        auto *line = reinterpret_cast<QRgb *>(result.scanLine(y));
        const auto *source = reinterpret_cast<const uchar *>(best->bytes.constData()) + y * best->width * 4;
        for (int x = 0; x < best->width; ++x)
            line[x] = qFromBigEndian<quint32>(source + x * 4);
    }
    return result;
}

QImage image(const QVariant &wire, int target)
{
    if (wire.metaType() != QMetaType::fromType<QDBusArgument>())
        return {};
    const auto arg = wire.value<QDBusArgument>();
    if (arg.currentSignature() != QLatin1String("a(iiay)"))
        return {};
    QList<Pixmap> pixmaps;
    arg.beginArray();
    while (!arg.atEnd()) {
        Pixmap p{};
        arg.beginStructure();
        arg >> p.width >> p.height >> p.bytes;
        arg.endStructure();
        pixmaps.append(p);
    }
    arg.endArray();
    return image(pixmaps, target);
}

QString toolTipTitle(const QVariant &wire)
{
    if (wire.metaType() != QMetaType::fromType<QDBusArgument>())
        return {};
    const auto arg = wire.value<QDBusArgument>();
    if (arg.currentSignature() != QLatin1String("(sa(iiay)ss)"))
        return {};
    QString icon, title, description;
    arg.beginStructure();
    arg >> icon;
    arg.asVariant(); // consume the tooltip icon array
    arg >> title >> description;
    arg.endStructure();
    return title;
}

QString label(const QString &text)
{
    QString result;
    for (qsizetype i = 0; i < text.size(); ++i) {
        if (text[i] != QLatin1Char('_'))
            result += text[i];
        else if (i + 1 < text.size() && text[i + 1] == QLatin1Char('_')) {
            result += QLatin1Char('_');
            ++i;
        }
    }
    return result;
}

namespace {
QVariantMap node(const QVariant &wire, int depth, int &budget)
{
    if (depth > 64 || --budget < 0 || wire.metaType() != QMetaType::fromType<QDBusArgument>())
        return {};
    const auto arg = wire.value<QDBusArgument>();
    if (arg.currentSignature() != QLatin1String("(ia{sv}av)"))
        return {};
    int id = 0;
    QVariantMap props;
    QVariantList children;
    arg.beginStructure();
    arg >> id >> props;
    arg.beginArray();
    while (!arg.atEnd()) {
        QDBusVariant child;
        arg >> child;
        const auto parsed = node(child.variant(), depth + 1, budget);
        if (!parsed.isEmpty())
            children.append(parsed);
    }
    arg.endArray();
    arg.endStructure();
    return {{QStringLiteral("id"), id},
            {QStringLiteral("label"), label(props.value(QStringLiteral("label")).toString())},
            {QStringLiteral("enabled"), props.value(QStringLiteral("enabled"), true)},
            {QStringLiteral("visible"), props.value(QStringLiteral("visible"), true)},
            {QStringLiteral("type"), props.value(QStringLiteral("type")).toString() == QLatin1String("separator")
                                       ? QStringLiteral("separator") : QStringLiteral("standard")},
            {QStringLiteral("toggleType"), props.value(QStringLiteral("toggle-type"), QString())},
            {QStringLiteral("toggleState"), props.value(QStringLiteral("toggle-state"), -1)},
            {QStringLiteral("iconName"), props.value(QStringLiteral("icon-name"), QString())},
            {QStringLiteral("children"), children}};
}
}

QVariantList menu(const QVariant &wire)
{
    int budget = 10000;
    return node(wire, 0, budget).value(QStringLiteral("children")).toList();
}
}
