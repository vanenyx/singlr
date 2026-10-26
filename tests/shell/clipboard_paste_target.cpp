#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QClipboard>
#include <QImage>
#include <QMimeData>
#include <QSettings>
#include <QStandardPaths>
class ClipboardProbe : public QObject {
    Q_OBJECT
public:
    using QObject::QObject;
    Q_INVOKABLE void seedImage() {
        QImage image(64, 48, QImage::Format_RGB32); image.fill(Qt::blue);
        auto *data = new QMimeData;
        data->setImageData(image); data->setData("x-kde-force-image-copy", "1");
        QGuiApplication::clipboard()->setMimeData(data);
    }
    Q_INVOKABLE void inspectPaste() {
        const auto *mime = QGuiApplication::clipboard()->mimeData();
        if (!mime || !mime->hasImage()) return;
        const auto image = qvariant_cast<QImage>(mime->imageData());
        const bool valid = image.size() == QSize(64,48) && image.pixelColor(10,10) == Qt::blue;
        QSettings state(QStandardPaths::writableLocation(QStandardPaths::GenericStateLocation) + "/clipboard-target.ini", QSettings::IniFormat);
        state.setValue("imageReceived", valid); state.sync();
    }
};
int main(int argc, char **argv) {
    QGuiApplication app(argc, argv);
    if (argc < 2) return 2;
    app.setApplicationName("singlr-paste-target");
    app.setDesktopFileName(app.arguments().contains("--terminal") ? "dev.warp.Warp" : "org.singlr.PasteTarget");
    QQmlApplicationEngine engine;
    ClipboardProbe probe;
    engine.rootContext()->setContextProperty("pasteProbe", &probe);
    engine.load(QUrl::fromLocalFile(QString::fromLocal8Bit(argv[1])));
    if (engine.rootObjects().isEmpty()) return 3;
    return app.exec();
}
#include "clipboard_paste_target.moc"
