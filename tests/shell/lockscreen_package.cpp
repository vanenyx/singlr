// SPDX-License-Identifier: GPL-2.0-or-later
#include <QCoreApplication>
#include <cstdio>
#include <KPackage/Package>
#include <KPackage/PackageLoader>
int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    auto package = KPackage::PackageLoader::self()->loadPackage(QStringLiteral("Plasma/Shell"));
    package.setPath(QStringLiteral("org.singlr.desktop"));
    const auto lock = package.filePath("lockscreenmainscript");
    const auto logout = package.filePath("logoutmainscript");
    if (!package.isValid() || !lock.contains("org.singlr.desktop/contents/lockscreen/LockScreen.qml")
        || package.metadata().value(QStringLiteral("X-Plasma-APIVersion")).toInt() < 2
        || package.fallbackPackage().metadata().pluginId() != "org.kde.plasma.desktop"
        || !logout.contains("org.kde.plasma.desktop/")) {
        fprintf(stderr, "FAIL fallback logout=%s api=%s\n", qPrintable(logout), qPrintable(package.metadata().value(QStringLiteral("X-Plasma-APIVersion"))));
        return 1;
    }
    puts("PASS KPackage API 2, Singlr lockscreen and KDE fallback");
}
