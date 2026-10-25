#pragma once

#include <QDBusArgument>
#include <QImage>
#include <QVariant>

namespace TrayFormat {
struct Pixmap {
    int width;
    int height;
    QByteArray bytes;
};
QImage image(const QList<Pixmap> &pixmaps, int target = 32);
QImage image(const QVariant &wire, int target = 32);
QString toolTipTitle(const QVariant &wire);
QString label(const QString &text);
// Returns the children of DBusMenu's invisible root, never the root itself.
QVariantList menu(const QVariant &wire);
}
