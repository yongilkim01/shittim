"""Pinned source modification, ABI guards, and compositor replacement/rollback."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch, call

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('titlebar_tool_for_plugin_test', ROOT / 'scripts/titlebar-tool.py')
TOOL = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(TOOL)
PLUGIN = TOOL.plugin
VERSION = dict(commit='a' * 40, abiHash='test-abi')


class TitlebarPlugin(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)
        environment = patch.dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.home/'config'),
                                 XDG_DATA_HOME=str(self.home/'data'), XDG_STATE_HOME=str(self.home/'state'))
        environment.start(); self.addCleanup(environment.stop)
        self.config = TOOL.files.Config(ROOT, self.home)
        self.library = self.config.data/'shittim/titlebars/test/hyprbars.so'
        self.library.parent.mkdir(parents=True); self.library.write_bytes(b'test binary')
        self.data = dict(library=str(self.library), **VERSION, renderer=PLUGIN.identity(self.config), sha256=PLUGIN.digest(self.library))

    def manifest(self):
        PLUGIN.manifest_path(self.config).write_text(json.dumps(self.data), encoding='utf-8')

    def test_abi_renderer_and_binary_must_match_before_load(self):
        self.manifest()
        self.assertEqual(PLUGIN.read_manifest(self.config, VERSION), self.data)
        for version in (dict(VERSION, abiHash='other'), dict(VERSION, commit='b'*40)):
            with self.assertRaisesRegex(ValueError, '다시 빌드'): PLUGIN.read_manifest(self.config, version)
        self.data['renderer']='old'; self.manifest()
        with self.assertRaisesRegex(ValueError, '다시 빌드'): PLUGIN.read_manifest(self.config, VERSION)
        self.data['renderer']=PLUGIN.identity(self.config); self.manifest(); self.library.write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, '바이너리'): PLUGIN.read_manifest(self.config, VERSION)

    def test_manifest_cannot_load_library_outside_managed_directory(self):
        outside=self.home/'foreign.so';outside.write_bytes(b'test binary')
        self.data['library']=str(outside);self.manifest()
        with self.assertRaisesRegex(ValueError, '바이너리'): PLUGIN.read_manifest(self.config, VERSION)

    def test_unexpected_upstream_is_rejected(self):
        directory=self.home/'source';directory.mkdir()
        source=directory/'barDeco.cpp';source.write_text('upstream changed')
        with self.assertRaisesRegex(ValueError, '렌더링 소스'): PLUGIN.patch_source(directory,self.config)
        self.assertEqual(source.read_text(),'upstream changed')

    def test_header_mismatch_stops_before_download_or_plugin_changes(self):
        with patch.object(PLUGIN.subprocess,'run',return_value=Mock(stdout='-I/nonexistent')) as run:
            with self.assertRaisesRegex(ValueError, '헤더'): PLUGIN.build(self.config,VERSION,'b'*40)
        self.assertEqual(run.call_count,1)
        self.assertFalse(PLUGIN.manifest_path(self.config).exists())

    def test_compile_failure_preserves_previous_manifest_and_library(self):
        self.manifest();before=PLUGIN.manifest_path(self.config).read_bytes()
        include=self.home/'include';header=include/'hyprland/src/version.h';header.parent.mkdir(parents=True)
        header.write_text('#define GIT_COMMIT_HASH "'+VERSION['commit']+'"')
        def run(args,**kwargs):
            if args[0]=='pkg-config': return Mock(stdout='-I'+str(include))
            if args[0]=='git' and args[-1]=='HEAD': return Mock(stdout='b'*40)
            if args[0]=='make': raise subprocess.CalledProcessError(2,args)
            return Mock(returncode=0)
        with patch.object(PLUGIN.subprocess,'run',side_effect=run) as commands,patch.object(PLUGIN,'patch_source'):
            with self.assertRaisesRegex(ValueError, '빌드 실패'): PLUGIN.build(self.config,VERSION,'b'*40)
        self.assertTrue(all(command.args[0][0] not in ('hyprctl','hyprpm') for command in commands.call_args_list))
        self.assertEqual(PLUGIN.manifest_path(self.config).read_bytes(),before)
        self.assertEqual(self.library.read_bytes(),b'test binary')

    @unittest.skipIf(os.name=='nt','Linux 플러그인 로드 잠금 검사')
    def test_stock_plugin_is_disabled_before_custom_plugin_load_and_recorded(self):
        self.manifest()
        responses=[[dict(name='hyprbars',version='1.0')],[],[dict(name='hyprbars',version=self.data['renderer'])]]
        with patch.object(PLUGIN,'query',side_effect=responses),patch.object(PLUGIN,'command') as commands:
            PLUGIN.load(self.config,VERSION)
        self.assertEqual(commands.call_args_list,[call('hyprpm','disable','hyprbars'),call('hyprpm','reload'),
                          call('hyprctl','plugin','load',str(self.library)),call('hyprctl','reload')])
        self.assertEqual(json.loads(PLUGIN.loaded_record(self.config).read_text()),self.data)

    @unittest.skipIf(os.name=='nt','Linux 플러그인 로드 잠금 검사')
    def test_repeated_load_does_not_reload_or_duplicate_any_plugin(self):
        self.manifest()
        with patch.object(PLUGIN,'query',return_value=[dict(name='hyprbars',version=self.data['renderer']),dict(name='other-plugin')]),patch.object(PLUGIN,'command') as commands:
            PLUGIN.load(self.config,VERSION)
        commands.assert_not_called()

    @unittest.skipIf(os.name=='nt','Linux 플러그인 로드 잠금 검사')
    def test_failed_load_restores_stock_plugin(self):
        self.manifest()
        def command(*args):
            if args[:3]==('hyprctl','plugin','load'): raise ValueError('permission denied')
        with patch.object(PLUGIN,'query',side_effect=[[dict(name='hyprbars',version='1.0')],[]]),patch.object(PLUGIN,'command',side_effect=command) as commands,patch.object(PLUGIN.subprocess,'run'):
            with self.assertRaisesRegex(ValueError,'permission denied'): PLUGIN.load(self.config,VERSION)
        self.assertEqual(commands.call_args_list[-2:],[call('hyprpm','enable','hyprbars'),call('hyprpm','reload')])
        self.assertFalse(PLUGIN.loaded_record(self.config).exists())

    @unittest.skipIf(os.name=='nt','Linux 플러그인 로드 잠금 검사')
    def test_reload_failure_restores_previous_vector_plugin(self):
        self.manifest()
        previous=dict(self.data,renderer='shittim-vector-previous')
        PLUGIN.loaded_record(self.config).write_text(json.dumps(previous))
        def command(*args):
            if args==('hyprpm','reload'): raise ValueError('header mismatch')
        with patch.object(PLUGIN,'query',return_value=[dict(name='hyprbars',version=previous['renderer'])]),patch.object(PLUGIN,'command',side_effect=command) as commands:
            with self.assertRaisesRegex(ValueError,'header mismatch'): PLUGIN.load(self.config,VERSION)
        self.assertEqual(commands.call_args_list[-1],call('hyprctl','plugin','load',previous['library']))
        self.assertEqual(json.loads(PLUGIN.loaded_record(self.config).read_text()),previous)

    def test_custom_unload_uses_recorded_managed_path_only(self):
        self.config.state.mkdir(parents=True)
        record=PLUGIN.loaded_record(self.config);record.write_text(json.dumps(self.data))
        plugins=[dict(name='hyprbars',version=self.data['renderer'])]
        with patch.object(PLUGIN,'command') as commands:
            self.assertEqual(PLUGIN.unload_custom(self.config,plugins),self.data)
            commands.assert_called_once_with('hyprctl','plugin','unload',str(self.library))
            commands.reset_mock();self.data['library']=str(self.home/'foreign.so');record.write_text(json.dumps(self.data))
            with self.assertRaisesRegex(ValueError,'경로'): PLUGIN.unload_custom(self.config,plugins)
            commands.assert_not_called()

    def test_ipc_text_error_is_not_a_successful_load(self):
        with patch.object(PLUGIN.subprocess,'run',return_value=Mock(stdout='plugin not loaded')):
            with self.assertRaisesRegex(ValueError,'요청 실패'): PLUGIN.command('hyprctl','plugin','load','/tmp/example.so')

    def test_verify_rejects_stock_renderer_when_vector_build_exists(self):
        self.manifest()
        with patch.object(PLUGIN,'query',return_value=VERSION):
            with self.assertRaisesRegex(ValueError,'로드되지'): PLUGIN.verify(self.config,[dict(name='hyprbars',version='1.0')])
            PLUGIN.verify(self.config,[dict(name='hyprbars',version=self.data['renderer'])])

    @unittest.skipUnless(shutil.which('g++') and shutil.which('pkg-config'),'C++·Cairo 래스터 검사 도구 필요')
    def test_actual_native_paths_and_hover_publisher(self):
        flags=subprocess.run(['pkg-config','--cflags','--libs','cairo'],check=True,capture_output=True,text=True).stdout
        import shlex
        executable=self.home/'control-test'
        subprocess.run(['g++','-std=c++23',str(ROOT/'tests/titlebar-controls.cpp'),*shlex.split(flags),'-o',str(executable)],check=True,timeout=60)
        subprocess.run([str(executable)],check=True,timeout=10)
        executable=self.home/'hover-test'
        subprocess.run(['g++','-std=c++23',str(ROOT/'tests/titlebar-hover.cpp'),*shlex.split(flags),'-o',str(executable)],check=True,timeout=60)
        subprocess.run([str(executable)],check=True,timeout=10)


if __name__=='__main__': unittest.main()
