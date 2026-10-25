// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <KConfigGroup>
#include <algorithm>

namespace SinglrGlass {
struct Settings {
    bool enabled = false;
    int intensity = 65;
    static Settings read(const KConfigGroup &group) {
        return {group.readEntry("Enabled", false), std::clamp(group.readEntry("Intensity", 65), 0, 100)};
    }
    // Enabled keeps its existing meaning (Liquid optics). Glass uses the same
    // compositor pass for variable diffusion and gentle backdrop tone compression.
    bool liquid = true;
    static Settings readSurface(const KConfigGroup &group, const KConfigGroup &appearance,
                                const KConfigGroup &accessibility) {
        auto settings = read(group);
        const auto material = appearance.readEntry("material", QStringLiteral("glass"));
        settings.liquid = material == QLatin1String("liquid") && settings.enabled;
        settings.enabled = (material == QLatin1String("glass") || settings.liquid)
            && !accessibility.readEntry("reduceTransparency", false);
        settings.intensity = std::clamp(appearance.readEntry("intensity", 65), 0, 100);
        return settings;
    }
    bool active() const { return enabled && intensity > 0; }
};
// A blur request alone must never opt an application into this effect.
inline bool eligible(const QString &resourceClass, bool layerShell, bool hasBlur) {
    return resourceClass == QLatin1String("singlr-shell") && layerShell && hasBlur;
}
}
