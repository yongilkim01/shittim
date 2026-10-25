-- Managed by Shittim. Optional compositor decorations, not a QML overlay.
hl.on("hyprland.start", function() hl.exec_cmd("hyprpm reload") end)
if not (hl.plugin and hl.plugin.hyprbars and hl.plugin.hyprbars.add_button) then return end
hl.config({
    plugin = { hyprbars = {
        enabled = true, bar_height = 24, bar_color = "rgb(020f15)",
        col = { text = "rgb(d5f8ff)" }, bar_text_size = 10,
        bar_text_font = "Hack Nerd Font Mono", bar_text_align = "left",
        bar_part_of_window = true, bar_precedence_over_border = false,
        bar_padding = 10, bar_button_padding = 10, bar_buttons_alignment = "right",
        bar_blur = false, icon_on_hover = false,
        on_double_click = __MAXIMIZE__,
    } },
})
-- Right to left; actions use the existing Shittim window controller.
hl.plugin.hyprbars.add_button({ bg_color = "rgba(00000000)", fg_color = "rgb(00d9f5)", size = 14, icon = "×", action = __CLOSE__ })
hl.plugin.hyprbars.add_button({ bg_color = "rgba(00000000)", fg_color = "rgb(00d9f5)", size = 14, icon = "□", action = __MAXIMIZE__ })
hl.plugin.hyprbars.add_button({ bg_color = "rgba(00000000)", fg_color = "rgb(00d9f5)", size = 14, icon = "−", action = __HIDE__ })
-- Apps without a custom headerbar can use the compositor titlebar on next launch.
hl.env("GTK_CSD", "0")
