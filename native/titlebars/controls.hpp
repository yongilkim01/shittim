#pragma once

#include <cairo.h>
#include <cmath>
#include <string_view>

// These paths are independent of font selection and Unicode glyph metrics.
namespace ShittimHUD {
inline int controlIndex(std::string_view icon) {
    if (icon == "−") return 0;
    if (icon == "□") return 1;
    if (icon == "×") return 2;
    if (icon == "restore") return 3;
    return -1;
}

inline bool isControl(std::string_view icon) {
    return controlIndex(icon) >= 0;
}

inline std::string_view displayIcon(std::string_view icon, bool maximized) {
    return icon == "□" && maximized ? "restore" : icon;
}

inline void drawControl(cairo_t* cr, std::string_view icon, double slot) {
    const double width = slot * 2.0 / 3.0; // 16 logical pixels in a 24px button.
    const double stroke = slot / 15.0;     // 1.6 logical pixels, for all three paths.
    const double left = (slot - width) / 2.0;
    const double right = slot - left;
    const double halfStroke = stroke / 2.0;
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_BEST);
    cairo_set_line_width(cr, stroke);
    cairo_set_line_cap(cr, CAIRO_LINE_CAP_BUTT);
    cairo_set_line_join(cr, CAIRO_LINE_JOIN_MITER);
    if (icon == "−") {
        cairo_move_to(cr, left, slot / 2.0);
        cairo_line_to(cr, right, slot / 2.0);
    } else if (icon == "□") {
        cairo_rectangle(cr, left + halfStroke, left + halfStroke, width - stroke, width - stroke);
    } else if (icon == "restore") {
        const double offset = width / 4.0;
        const double side = width - offset - stroke;
        cairo_rectangle(cr, left + halfStroke, left + offset + halfStroke, side, side);
        cairo_move_to(cr, left + offset + halfStroke, left + offset - halfStroke);
        cairo_line_to(cr, left + offset + halfStroke, left + halfStroke);
        cairo_line_to(cr, right - halfStroke, left + halfStroke);
        cairo_line_to(cr, right - halfStroke, right - offset - halfStroke);
        cairo_line_to(cr, right - offset + halfStroke, right - offset - halfStroke);
    } else if (icon == "×") {
        const double inset = halfStroke / std::sqrt(2.0);
        cairo_move_to(cr, left + inset, left + inset);
        cairo_line_to(cr, right - inset, right - inset);
        cairo_move_to(cr, right - inset, left + inset);
        cairo_line_to(cr, left + inset, right - inset);
    }
    cairo_stroke(cr);
}

template <class Color, class Upload>
auto controlTexture(std::string_view icon, double slot, const Color& color, Upload upload) {
    const int pixels = static_cast<int>(std::ceil(slot));
    auto* surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, pixels, pixels);
    auto* cr = cairo_create(surface);
    cairo_set_source_rgba(cr, color.r, color.g, color.b, color.a);
    drawControl(cr, icon, slot);
    cairo_surface_flush(surface);
    auto texture = upload(surface);
    cairo_destroy(cr);
    cairo_surface_destroy(surface);
    return texture;
}
} // namespace ShittimHUD
