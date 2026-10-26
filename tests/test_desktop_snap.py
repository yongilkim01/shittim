"""Run pointer observer logic in real Lua with controlled public Hyprland objects."""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT=Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('lua'),'실제 Lua 인터프리터')
class SnapObserver(unittest.TestCase):
    def test_native_drag_resize_release_and_restore(self):
        prelude='''local binds,commands,actions={},{},{}
local w={address='0xabc',mapped=true,floating=true,pinned=false,workspace={id=1},fullscreen=0,fullscreen_client=0,at={x=300,y=100},size={x=800,y=500}}
local pointer={x=320,y=120}; local callback
hl={exec_cmd=function(cmd) table.insert(commands,cmd) end,
get_active_window=function() return w end,get_cursor_pos=function() return pointer end,
get_monitors=function() return {{id=0,width=1920,height=1080,scale=1,transform=0,x=0,y=0}} end,
timer=function(fn,opts) callback=fn; return {set_enabled=function() end} end,
bind=function(key,fn,opts) assert(opts.non_consuming and opts.transparent and opts.ignore_mods); binds[opts.release and 'release' or 'press']=fn end,
on=function() end,dispatch=function(action) table.insert(actions,action) end,
dsp={event=function(v) return {event=v} end,window={tag=function(v) return v end,resize=function(v) return v end,move=function(v) return v end,fullscreen=function(v) return v end}}}
'''
        body=(ROOT/'config/desktop-snap.lua').read_text().replace('__SHITTIM_SNAP_COMMAND__','"snap"')
        checks='''
-- Text selection without a moving window never snaps.
binds.press(); callback(); pointer={x=1,y=300}; callback(); binds.release();
for _,cmd in ipairs(commands) do assert(not cmd:find('commit')) end
commands={}; pointer={x=320,y=120}; binds.press(); callback()
w.at={x=-19,y=280}; pointer={x=1,y=300}; callback()
assert(commands[#commands]:find('preview 0xabc left 0'))
binds.release(); assert(commands[#commands-1]:find('commit 0xabc left 0'))
assert(tonumber(commands[#commands]:match('(%d+)$'))>tonumber(commands[#commands-1]:match('(%d+)$')))
-- A snapped window returns to its old floating size on the next move.
w.at={x=8,y=48}; w.size={x=952,y=946}; pointer={x=28,y=68}; binds.press(); callback()
w.at={x=110,y=110}; pointer={x=130,y=130}; callback(); assert(#actions>=2 and actions[1].x==800 and actions[1].y==500)
binds.release()
commands={}; pointer={x=130,y=130}; binds.press(); callback(); w.size={x=900,y=700}; callback(); binds.release()
for _,cmd in ipairs(commands) do assert(not cmd:find('commit')) end
-- A managed maximized window restores its own record while dragging, including after reload.
commands={};actions={};w.tags={'shittim-maximized','shittim-restore_300_100_800_500_1'}
w.at={x=8,y=48};w.size={x=1904,y=946};pointer={x=108,y=60};binds.press();callback()
w.at={x=108,y=148};pointer={x=208,y=160};callback()
assert(actions[1].x==800 and actions[1].y==500)
assert(actions[3].tag=='-shittim-maximized' and actions[4].tag=='-shittim-restore_300_100_800_500_1')
assert(actions[5].event=='shittim-window-state,0xabc');binds.release()
'''
        result=subprocess.run(['lua','-'],input=prelude+body+checks,text=True,capture_output=True,timeout=5)
        self.assertEqual(result.returncode,0,result.stderr)


if __name__=='__main__': unittest.main()
