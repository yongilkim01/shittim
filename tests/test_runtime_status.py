"""Deployment checks distinguish edited code, a stale running shell and optional plugins."""
import importlib.util
import json
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import Mock, patch

ROOT=Path(__file__).resolve().parents[1]
SPEC=importlib.util.spec_from_file_location('runtime_status_test',ROOT/'scripts/runtime-status.py')
STATUS=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(STATUS)
SPEC2=importlib.util.spec_from_file_location('design_generation_test',ROOT/'scripts/design-tokens.py')
DESIGN=importlib.util.module_from_spec(SPEC2);SPEC2.loader.exec_module(DESIGN)


class RuntimeStatus(unittest.TestCase):
    def test_source_fingerprint_is_stable_across_line_endings_and_detects_code_edits(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);(root/'shell').mkdir();path=root/'shell/shell.qml'
            path.write_bytes(b'ShellRoot {\n}\n');original=STATUS.fingerprint(root)
            path.write_bytes(b'ShellRoot {\r\n}\r\n');self.assertEqual(STATUS.fingerprint(root),original)
            (root/'.env').write_text('not part of a diagnostic digest')
            self.assertEqual(STATUS.fingerprint(root),original)
            path.write_text('ShellRoot { property bool changed:true }')
            self.assertNotEqual(STATUS.fingerprint(root),original)

    def test_running_old_code_is_an_error_but_absent_optional_plugin_is_only_a_warning(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);(root/'config').mkdir();(root/'shell').mkdir()
            (root/'config/compatibility.json').write_text(json.dumps(dict(protocol=1,runtimeContract='fixture-v1',titlebars={'a'*40:'b'*40})))
            state=dict(protocol=1,contract='fixture-v1',configRoot=str(root/'shell'),fingerprint=STATUS.fingerprint(root))
            plugin=Mock();plugin.query.side_effect=lambda name,*_:dict(commit='a'*40,abiHash='fixture') if name=='version' else []
            plugin.read_manifest.return_value=None
            tool=SimpleNamespace(files=SimpleNamespace(Config=lambda **_:SimpleNamespace(config=root/'user-config')),plugin=plugin)
            def run(*args):
                if args[0]=='git':return '' if args[-1]=='--porcelain' else 'revision'
                return json.dumps(state)
            with patch.object(STATUS,'run',side_effect=run),patch.object(STATUS.importlib.util,'module_from_spec',return_value=tool),patch.object(STATUS.importlib.util,'spec_from_file_location',return_value=SimpleNamespace(loader=Mock())):
                current=STATUS.inspect(root)
                self.assertTrue(current['ok']);self.assertTrue(any(c['name']=='titlebar-binary' and c['state']=='warning' for c in current['checks']))
                state['fingerprint']='old-code'
                stale=STATUS.inspect(root);self.assertFalse(stale['ok'])
                self.assertEqual(next(c['state'] for c in stale['checks'] if c['name']=='shell'),'error')

    def test_all_generated_design_outputs_match_their_source(self):
        for name, expected in DESIGN.outputs().items():
            self.assertEqual((ROOT/name).read_text(encoding='utf-8'),expected,name)


if __name__=='__main__':unittest.main()
