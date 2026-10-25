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
    bool active() const { return enabled && intensity > 0; }
};
// A blur request alone must never opt an application into this effect.
inline bool eligible(const QString &resourceClass, bool layerShell, bool hasBlur) {
    return resourceClass == QLatin1String("singlr-shell") && layerShell && hasBlur;
}
}
