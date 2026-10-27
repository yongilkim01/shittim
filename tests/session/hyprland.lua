-- Isolated test compositor, using the same Lua API as the desktop configuration.
hl.monitor({output="",mode="1280x800@60",position="0x0",scale=1})
hl.config({animations={enabled=false},misc={disable_hyprland_logo=true,disable_splash_rendering=true}})
