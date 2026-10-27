#pragma once
#include "design.hpp"

namespace ShittimHUD {
struct HoverRect { double x, y, width, height; };
struct HoverColor { double r, g, b, a; };

inline bool contains(const HoverRect& rect, double x, double y) {
    return x >= rect.x && x < rect.x + rect.width && y >= rect.y && y < rect.y + rect.height;
}

template <class Draw>
void drawHoverFrame(HoverRect rect, double scale, double opacity, Draw draw) {
    const double inset = 1.5 * scale;
    rect = {rect.x + inset, rect.y + inset, rect.width - 2 * inset, rect.height - 2 * inset};
    if (rect.width <= 0 || rect.height <= 0) return;
    draw(rect, HoverColor{Design::surfaceR, Design::surfaceG, Design::surfaceB, opacity});
    const auto edges = [&](double thickness, HoverColor color) {
        draw(HoverRect{rect.x, rect.y, rect.width, thickness}, color);
        draw(HoverRect{rect.x, rect.y + rect.height - thickness, rect.width, thickness}, color);
        draw(HoverRect{rect.x, rect.y + thickness, thickness, rect.height - 2 * thickness}, color);
        draw(HoverRect{rect.x + rect.width - thickness, rect.y + thickness, thickness, rect.height - 2 * thickness}, color);
    };
    edges(2 * scale, HoverColor{Design::accentR, Design::accentG, Design::accentB, 0.14 * opacity});
    edges(scale, HoverColor{Design::accentR, Design::accentG, Design::accentB, 0.85 * opacity});
}
} // namespace ShittimHUD
