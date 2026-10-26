// CPU raster test of the actual paths used by the compositor plugin. No font or display needed.
#include "../native/titlebars/controls.hpp"
#include <cassert>
#include <algorithm>
#include <array>
#include <filesystem>
#include <iostream>

struct Color { double r, g, b, a; };

int main(int argc, char** argv) {
    const std::array<std::string_view, 3> icons = {"−", "□", "×"};
    assert(!ShittimHUD::isControl("other"));
    for (double scale : {1.0, 1.25, 1.5, 2.0}) {
        std::array<int, 3> widths{};
        for (size_t i = 0; i < icons.size(); ++i) {
            assert(ShittimHUD::isControl(icons[i]));
            int width = ShittimHUD::controlTexture(icons[i], 24.0 * scale, Color{0, 217.0 / 255.0, 245.0 / 255.0, 1}, [&](cairo_surface_t* surface) {
                assert(cairo_surface_status(surface) == CAIRO_STATUS_SUCCESS);
                int size = cairo_image_surface_get_width(surface), stride = cairo_image_surface_get_stride(surface);
                auto* pixels = cairo_image_surface_get_data(surface);
                int left = size, right = -1, top = size, bottom = -1;
                for (int y = 0; y < size; ++y) for (int x = 0; x < size; ++x) {
                    unsigned pixel = reinterpret_cast<unsigned*>(pixels + y * stride)[x];
                    if ((pixel >> 24) < 128) continue;
                    left = std::min(left, x); right = std::max(right, x);
                    top = std::min(top, y); bottom = std::max(bottom, y);
                    assert((pixel & 0xff0000) == 0); // Same cyan foreground for all three symbols.
                }
                assert(left > 0 && right < size - 1 && top > 0 && bottom < size - 1);
                assert(std::abs((left + right + 1) / 2.0 - 12.0 * scale) <= 0.5);
                assert(std::abs((top + bottom + 1) / 2.0 - 12.0 * scale) <= 0.5);
                if (i == 0) assert(bottom - top + 1 <= std::ceil(1.6 * scale));
                if (argc > 1) {
                    std::filesystem::create_directories(argv[1]);
                    auto path = std::filesystem::path(argv[1]) / (std::to_string(i) + "-" + std::to_string(scale) + ".png");
                    assert(cairo_surface_write_to_png(surface, path.string().c_str()) == CAIRO_STATUS_SUCCESS);
                }
                return right - left + 1;
            });
            widths[i] = width;
            assert(std::abs(width - 16.0 * scale) <= 1.0);
        }
        assert(*std::max_element(widths.begin(), widths.end()) - *std::min_element(widths.begin(), widths.end()) <= 1);
        std::cout << "scale=" << scale << " widths=" << widths[0] << ',' << widths[1] << ',' << widths[2] << '\n';
    }
}
