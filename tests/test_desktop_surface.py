"""Desktop boundaries, persisted layout, and real GIO files in a temporary home."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import select
import sys
import tempfile
import time
import unittest
from unittest.mock import Mock, patch

ROOT=Path(__file__).resolve().parents[1]
SPEC=importlib.util.spec_from_file_location('desktop_surface',ROOT/'scripts/desktop-service.py')
TOOL=importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(TOOL)
SPEC2=importlib.util.spec_from_file_location('dock_settings',ROOT/'scripts/dock-settings.py')
DOCK=importlib.util.module_from_spec(SPEC2); SPEC2.loader.exec_module(DOCK)


class DesktopSafety(unittest.TestCase):
    def test_component_and_uri_validation(self):
        self.assertEqual(TOOL.component('한글 공백 $(not executed).txt'),'한글 공백 $(not executed).txt')
        for name in ('','..','../escape','a/b','a\\b','a\0b'):
            with self.assertRaises(ValueError): TOOL.component(name)
        for uri in ('https://host/file','file://remote/file','file:///tmp/%00bad','/tmp/path','file:///tmp/a?b'):
            with self.assertRaises(ValueError): TOOL.local_uri(uri)
        self.assertEqual(TOOL.local_uri('file:///tmp/a%20b'),'file:///tmp/a%20b')

    def test_layout_is_private_atomic_per_monitor_and_bounded(self):
        with self.assertRaises(ValueError): TOOL.Layout(ROOT/'desktop-layout.json')
        with tempfile.TemporaryDirectory() as temporary:
            path=Path(temporary)/'desktop-layout.json'; layout=TOOL.Layout(path)
            self.assertEqual(layout.read(),{})
            layout.move('monitor 1',{'file:///tmp/a':[10,20]})
            layout.move('monitor 2',{'home':[1,2]})
            self.assertEqual(layout.read()['monitor 1']['file:///tmp/a'],[10,20])
            self.assertEqual(list(path.parent.glob('tmp*')),[])
            for value in ([float('nan'),0],[-1,0],['bad',0]):
                with self.assertRaises(ValueError): layout.move('monitor',{'home':value})
            self.assertNotIn('monitor',layout.read())

    def test_nemo_transfer_uses_typed_arguments_without_shell(self):
        desktop=object.__new__(TOOL.Desktop); desktop.gio=Mock(); desktop.glib=Mock()
        desktop.transfer(['file:///tmp/a%20b'],'file:///tmp/target',True)
        call=desktop.gio.bus_get_sync.return_value.call_sync.call_args.args
        self.assertEqual(call[:4],('org.Nemo','/org/Nemo','org.Nemo.FileOperations','MoveURIs'))
        desktop.glib.Variant.assert_called_once_with('(ass)',(['file:///tmp/a%20b'],'file:///tmp/target'))
        with self.assertRaises(ValueError): desktop.transfer(['https://host/file'],'file:///tmp/target')

    def test_dock_pin_unpin_order_and_invalid_config_preservation(self):
        with tempfile.TemporaryDirectory() as temporary:
            default=Path(temporary)/'default.json'; personal=Path(temporary)/'user/dock.json'
            default.write_text(json.dumps({'favorites':['a.desktop'],'windowClasses':{'a.desktop':['custom-class']},'other':'preserved'}))
            apps={'a.desktop':None,'b.desktop':None}
            with patch.object(DOCK,'paths',return_value=(default,personal)):
                self.assertEqual(DOCK.update_settings('pin','b.desktop',apps)['favorites'],['a.desktop','b.desktop'])
                self.assertEqual(DOCK.update_settings('reorder','b.desktop',apps,0)['favorites'],['b.desktop','a.desktop'])
                self.assertEqual(DOCK.update_settings('unpin','a.desktop',apps)['favorites'],['b.desktop'])
                self.assertEqual(DOCK.read_settings()['windowClasses']['a.desktop'],['custom-class'])
                self.assertEqual(json.loads(personal.read_text())['other'],'preserved')
                before=personal.read_bytes()
                with self.assertRaises(ValueError): DOCK.update_settings('pin','sh -c bad',apps)
                self.assertEqual(before,personal.read_bytes())
                personal.write_text('broken')
                with self.assertRaises(ValueError): DOCK.update_settings('pin','b.desktop',apps)
                self.assertEqual(personal.read_text(),'broken')

    @unittest.skipUnless(sys.platform=='linux','실제 GIO 파일 처리')
    def test_service_watches_files_saves_positions_and_exits_on_stdin_close(self):
        with tempfile.TemporaryDirectory() as temporary:
            home=Path(temporary); desktop=home/'Desktop'; desktop.mkdir(); config=home/'.config'; config.mkdir()
            (config/'user-dirs.dirs').write_text('XDG_DESKTOP_DIR="$HOME/Desktop"\n')
            env=dict(os.environ,HOME=str(home),XDG_CONFIG_HOME=str(config),XDG_DATA_HOME=str(home/'.local/share'),XDG_STATE_HOME=str(home/'.local/state'))
            process=subprocess.Popen([sys.executable,str(ROOT/'scripts/desktop-service.py')],env=env,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,bufsize=0)
            def cleanup():
                if process.poll() is None: process.kill(); process.wait()
                process.stdin.close(); process.stdout.close(); process.stderr.close()
            self.addCleanup(cleanup)
            pending=bytearray()
            def receive(predicate):
                deadline=time.monotonic()+5
                while time.monotonic()<deadline:
                    if b'\n' in pending:
                        line,_,tail=pending.partition(b'\n'); pending[:]=tail
                        value=json.loads(line)
                        if predicate(value): return value
                    elif select.select([process.stdout],[],[],0.1)[0]:
                        chunk=os.read(process.stdout.fileno(),65536)
                        if not chunk: self.fail('desktop service exited')
                        pending.extend(chunk)
                self.fail('desktop service response timed out')
            initial=receive(lambda value:value.get('event')=='desktop'); self.assertEqual(len(initial['entries']),3)
            (desktop/'new.txt').write_text('content')
            receive(lambda value:value.get('event')=='desktop' and any(entry['name']=='new.txt' for entry in value['entries']))
            process.stdin.write((json.dumps({'action':'positions','screen':'test','positions':{'home':[10,20]}})+'\n').encode())
            response=receive(lambda value:value.get('event')=='positions'); self.assertEqual(response['positions']['test']['home'],[10,20])
            process.stdin.close(); self.assertEqual(process.wait(timeout=5),0)

    @unittest.skipUnless(sys.platform=='linux','실제 GIO 파일 처리')
    def test_real_gio_catalogue_rename_trash_and_protected_shortcuts(self):
        with tempfile.TemporaryDirectory() as temporary:
            home=Path(temporary); desktop=home/'Desktop'; desktop.mkdir()
            file=desktop/'한글 공백.txt'; file.write_text('content'); (desktop/'.hidden').write_text('hidden')
            config=home/'.config'; config.mkdir()
            (config/'user-dirs.dirs').write_text('XDG_DESKTOP_DIR="$HOME/Desktop"\n')
            env=dict(os.environ,HOME=str(home),XDG_CONFIG_HOME=str(config),XDG_DATA_HOME=str(home/'.local/share'),XDG_STATE_HOME=str(home/'.local/state'))
            code='''import importlib.util,sys,pathlib
from gi.repository import Gio,GLib
s=importlib.util.spec_from_file_location('desktop',sys.argv[1]); m=importlib.util.module_from_spec(s); s.loader.exec_module(m)
events=[]; d=m.Desktop(Gio,GLib,events.append); d.refresh()
assert len(d.entries)==4 and 'home' in d.entries and 'trash' in d.entries
key=next(key for key in d.entries if key.startswith('file:'))
try: d.operation({'action':'trash','ids':['home']}); raise AssertionError('protected shortcut')
except ValueError: pass
d.operation({'action':'rename','ids':[key],'name':'이름 변경.txt'})
d.refresh(); key=next(key for key in d.entries if key.startswith('file:'))
assert d.entries[key]['name']=='이름 변경.txt'
d.operation({'action':'trash','ids':[key]}); d.refresh(); assert len(d.entries)==3
assert list((pathlib.Path.home()/'.local/share/Trash/files').iterdir())
'''
            result=subprocess.run([sys.executable,'-c',code,str(ROOT/'scripts/desktop-service.py')],env=env,capture_output=True,text=True,timeout=15)
            self.assertEqual(result.returncode,0,result.stderr)


if __name__=='__main__': unittest.main()
