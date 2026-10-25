"""Actual GIO enumeration, file mutations and the private file-manager protocol."""
import importlib.util
import json
import os
from pathlib import Path
import select
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import Mock, patch

ROOT=Path(__file__).resolve().parents[1]
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,ROOT/'scripts'/path)
    value=importlib.util.module_from_spec(spec);spec.loader.exec_module(value);return value
TOOL=module('files_service','files-service.py')
CONFIG=module('files_config','files-config.py')


class FileBoundaries(unittest.TestCase):
    @unittest.skipUnless(sys.platform=='linux','실제 GIO Desktop Entry 인수 처리')
    def test_desktop_entry_preserves_quoted_repository_path_and_uri_arguments(self):
        with tempfile.TemporaryDirectory() as temporary:
            home=Path(temporary);root=home/'repo 한글 "quote" $value `tick` %percent \\slash'
            (root/'scripts').mkdir(parents=True)
            output=home/'arguments.json'
            (root/'scripts/files-client.py').write_text('import json,os,sys\nfrom pathlib import Path\nPath(os.environ["FILES_RECORD"]).write_text(json.dumps(sys.argv[1:]))\n')
            env=dict(os.environ,HOME=str(home),XDG_CONFIG_HOME=str(home/'.config'),XDG_DATA_HOME=str(home/'.local/share'),XDG_STATE_HOME=str(home/'.local/state'),FILES_RECORD=str(output))
            with patch.dict(os.environ,env):
                config=CONFIG.files.Config(root,home)
                desktop=home/'test.desktop'
                desktop.write_text(CONFIG.entry(config).replace('/usr/bin/python3',CONFIG.desktop_quote(sys.executable),1))
            value=(home/'한글 ; $(literal)').as_uri()
            # Parse and launch with GIO in a separate process to avoid XDG cache leakage.
            code='import importlib.util,sys; s=importlib.util.spec_from_file_location("launcher",sys.argv[1]);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);g,l,d=m.load_gio();a=d.new_from_filename(sys.argv[2]);assert a is not None;assert a.launch_uris([sys.argv[3]],None)'
            subprocess.run([sys.executable,'-c',code,str(ROOT/'scripts/launcher-service.py'),str(desktop),value],env=env,check=True,capture_output=True,timeout=5)
            deadline=time.monotonic()+5
            while not output.exists() and time.monotonic()<deadline:time.sleep(.02)
            self.assertTrue(output.exists());self.assertEqual(json.loads(output.read_text()),[str(home/'한글 ; $(literal)')])

    @unittest.skipUnless(sys.platform=='linux','Linux 사용자 세션의 flock')
    def test_client_uses_one_daemon_and_passes_locations_as_json(self):
        client=module('files_client','files-client.py')
        with tempfile.TemporaryDirectory() as temporary,patch.dict(os.environ,XDG_RUNTIME_DIR=temporary):
            calls=[Mock(returncode=1),Mock(returncode=0),Mock(returncode=0,stdout='requested')]
            with patch.object(client,'call',side_effect=calls) as ipc,patch.object(client.subprocess,'run') as run:
                client.open_locations(['/tmp/한글 $(literal)'])
                self.assertEqual(run.call_args.args[0],['quickshell','--daemonize','--path',str(ROOT/'shell/files.qml')])
                self.assertEqual(json.loads(ipc.call_args.args[1])['uri'],Path('/tmp/한글 $(literal)').as_uri())
            with patch.object(client,'call',return_value=Mock(returncode=0,stdout='requested')),patch.object(client.subprocess,'run') as run:
                client.open_locations([]);run.assert_not_called()

    def test_uri_validation_never_accepts_commands_or_embedded_credentials(self):
        self.assertEqual(TOOL.location('/tmp/한글 공백',Path('/tmp/home')),'file:///tmp/%ED%95%9C%EA%B8%80%20%EA%B3%B5%EB%B0%B1')
        for value in ('javascript:alert(1)','sftp://user:password@host/path','file://remote/path','file:///tmp/%00bad','bad\nuri'):
            with self.subTest(value=value),self.assertRaises(ValueError):TOOL.location(value,Path('/tmp/home'))

    def test_install_backs_up_pin_and_preserves_other_preferences_and_reexecution(self):
        with tempfile.TemporaryDirectory() as temporary:
            home=Path(temporary);env=dict(HOME=str(home),XDG_CONFIG_HOME=str(home/'.config'),XDG_DATA_HOME=str(home/'.local/share'),XDG_STATE_HOME=str(home/'.local/state'))
            with patch.dict(os.environ,env):
                config=CONFIG.files.Config(ROOT,home)
                pin=config.config/'shittim/dock.json';pin.parent.mkdir(parents=True)
                pin.write_text(json.dumps({'favorites':['kitty.desktop','nemo.desktop'],'extra':123}))
                CONFIG.setup(config)
                self.assertEqual(json.loads(pin.read_text())['favorites'],['kitty.desktop','org.shittim.Files.desktop'])
                self.assertEqual(json.loads(pin.read_text())['extra'],123)
                pin.write_text(json.dumps({'favorites':['nemo.desktop'],'extra':456}))
                CONFIG.setup(config)
                self.assertEqual(json.loads(pin.read_text())['favorites'],['nemo.desktop'])
                self.assertIn('StartupWMClass=org.shittim.Files', (config.data/'applications/org.shittim.Files.desktop').read_text())

    @unittest.skipUnless(sys.platform=='linux','실제 GIO 파일 처리')
    def test_real_gio_navigation_mutations_and_protocol_exit(self):
        with tempfile.TemporaryDirectory() as temporary:
            home=Path(temporary);config=home/'.config';config.mkdir()
            (config/'user-dirs.dirs').write_text('XDG_DESKTOP_DIR="$HOME/Desktop"\n')
            (home/'Desktop').mkdir();(home/'한글 폴더').mkdir();(home/'file $(literal).txt').write_text('hello');(home/'.hidden').write_text('hidden')
            env=dict(os.environ,HOME=str(home),XDG_CONFIG_HOME=str(config),XDG_DATA_HOME=str(home/'.local/share'),XDG_STATE_HOME=str(home/'.local/state'))
            process=subprocess.Popen([sys.executable,str(ROOT/'scripts/files-service.py')],env=env,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,bufsize=0)
            pending=bytearray()
            def receive(event,request=None):
                deadline=time.monotonic()+10
                while time.monotonic()<deadline:
                    if b'\n' in pending:
                        line,_,tail=pending.partition(b'\n');pending[:]=tail;message=json.loads(line)
                        if message['event']==event and (request is None or message.get('request')==request):return message
                    if select.select([process.stdout],[],[],0.2)[0]:
                        chunk=os.read(process.stdout.fileno(),65536)
                        if not chunk: self.fail('backend exited: '+process.stderr.read().decode())
                        pending.extend(chunk)
                self.fail('no '+event+' response')
            def send(action,request,**values):process.stdin.write((json.dumps(dict(action=action,tab=1,request=request,**values),ensure_ascii=False)+'\n').encode());process.stdin.flush()
            try:
                self.assertEqual(receive('ready')['home'],home.as_uri())
                send('browse',1,uri=home.as_uri());listing=receive('listing',1)
                self.assertTrue(listing['writable']);self.assertEqual(listing['name'],'Home')
                entries={item['name']:item for item in listing['entries']}
                self.assertEqual(entries['Desktop']['icons'],['user-desktop'])
                self.assertTrue(entries['.hidden']['hidden']);self.assertTrue(entries['한글 폴더']['directory'])
                send('rename',2,ids=[entries['file $(literal).txt']['id']],name='변경된 이름.txt');receive('done',2)
                self.assertTrue((home/'변경된 이름.txt').is_file())
                send('folder',3,name='실제 새 폴더');receive('done',3);self.assertTrue((home/'실제 새 폴더').is_dir())
                send('browse',4,uri=home.as_uri());entries={item['name']:item for item in receive('listing',4)['entries']}
                send('trash',5,ids=[entries['변경된 이름.txt']['id']]);receive('done',5)
                self.assertFalse((home/'변경된 이름.txt').exists())
                send('browse',6,uri=(home/'missing').as_uri());self.assertEqual(receive('error',6)['error'],'NotFound')
                process.stdin.close();process.wait(timeout=5);self.assertEqual(process.returncode,0)
            finally:
                if process.poll() is None:process.kill();process.wait()
                for stream in (process.stdin,process.stdout,process.stderr):
                    if not stream.closed:stream.close()


if __name__=='__main__':unittest.main()
