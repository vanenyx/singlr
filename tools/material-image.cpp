// SPDX-License-Identifier: GPL-2.0-or-later
// Headless PNG crop/zoom using Qt, without PIL or a display connection.
#include <QCoreApplication>
#include <QImage>
#include <QTextStream>

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    const auto args = app.arguments();
    if (args.size() == 4 && args[1] == "--solid") {
        if (args[3] != "white" && args[3] != "black") return 2;
        QImage image(16, 16, QImage::Format_RGB32);
        image.fill(args[3] == "white" ? Qt::white : Qt::black);
        return image.save(args[2], "PNG") ? 0 : 1;
    }
    if (args.size() != 8) {
        QTextStream(stderr) << "Usage: singlr-material-image INPUT OUTPUT X Y WIDTH HEIGHT ZOOM\n";
        return 2;
    }
    int values[5];
    for (int i = 0; i < 5; ++i) {
        bool ok = false;
        values[i] = args[i + 3].toInt(&ok);
        if (!ok || values[i] < (i < 2 ? 0 : 1)) return 2;
    }
    const QRect rect(values[0], values[1], values[2], values[3]);
    QImage input(args[1]);
    if (input.isNull() || !input.rect().contains(rect) || values[4] > 16
        || qint64(rect.width()) * rect.height() * values[4] * values[4] > 64000000) {
        QTextStream(stderr) << "Invalid PNG, crop outside image, or zoom too large\n";
        return 2;
    }
    // Nearest neighbour preserves the actual edge pixels for inspection.
    return input.copy(rect).scaled(rect.size() * values[4], Qt::IgnoreAspectRatio,
                                  Qt::FastTransformation).save(args[2], "PNG") ? 0 : 1;
}
