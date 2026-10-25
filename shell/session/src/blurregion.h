#pragma once
#include <QRegion>
#include <algorithm>
#include <cmath>
#include <vector>

namespace SinglrGlass {
// wl_region has integer coordinates and no coverage. Include only whole cells
// inside the QML contour, so native blur never bleeds beyond its antialiased tint.
inline QRegion roundedBlurRegion(QSize size, double radius) {
    radius = std::clamp(radius, 0.0, std::max(0.0, std::min(size.width(), size.height()) / 2.0));
    QRegion result;
    for (int y = 0; y < size.height(); ++y) {
        const double dy = std::max({radius - y, y + 1.0 - (size.height() - radius), 0.0});
        const int inset = int(std::ceil(radius - std::sqrt(std::max(0.0, radius * radius - dy * dy))));
        if (size.width() > 2 * inset) result += QRect(inset, y, size.width() - 2 * inset, 1);
    }
    return result;
}

// The radius is not carried by wl_region. Recover it exactly from the corner rows,
// which roundedBlurRegion() rasterizes deterministically: try candidate radii
// (quarter-pixel steps) and keep the first whose corner insets match.
inline int cornerInset(double radius, int row) {
    const double dy = std::max(radius - row, 0.0);
    return int(std::ceil(radius - std::sqrt(std::max(0.0, radius * radius - dy * dy))));
}
inline double radiusFromInsets(const std::vector<int> &insets, double maxRadius) {
    // Several radii can rasterize to the same cells; Singlr's radius tokens are whole
    // pixels, so prefer an integer match, else the middle of the matching range.
    double first = -1, last = -1, integer = -1;
    for (double r = 0.0; r <= maxRadius + 1e-6; r += 0.25) {
        bool match = cornerInset(r, int(insets.size())) == 0;
        for (int row = 0; row < int(insets.size()) && match; ++row)
            match = cornerInset(r, row) == insets[row];
        if (!match) continue;
        if (first < 0) first = r;
        last = r;
        if (r == std::floor(r)) integer = r;
    }
    if (integer >= 0) return integer;
    return first < 0 ? double(insets.size()) : std::round((first + last) * 2.0) / 4.0;
}
}
