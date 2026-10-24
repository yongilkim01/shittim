-- Shittim floating desktop. Loaded after the original user configuration.
-- Static rule: existing floating dialogs and fullscreen requests keep their sizing.
hl.window_rule({
    name = "shittim-normal-floating",
    match = { class = ".+", float = false, fullscreen = false,
              fullscreen_state_client = 0, content = "none" },
    float = true,
    size = { "(monitor_w*0.78)", "(monitor_h*0.72)" },
    center = true,
})
hl.config({
    general = { resize_on_border = true, extend_border_grab_area = 8, hover_icon_on_border = true, border_size = 1,
                snap = { enabled = true, window_gap = 10, monitor_gap = 10 },
                col = { active_border = "rgb(00d9f5)", inactive_border = "rgb(145263)" } },
    decoration = { rounding = 0, shadow = { enabled = false } },
    input = { follow_mouse = 0 },
})

-- These bindings implement the requested desktop policy, replacing these keys only.
local function bind(key, dispatcher, options)
    hl.unbind(key)
    hl.bind(key, dispatcher, options or {})
end
bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })
bind("SUPER + C", hl.dsp.window.close())
bind("SUPER + V", hl.dsp.window.float({ action = "toggle" }))
bind("SUPER + UP", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
