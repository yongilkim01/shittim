"""Completion means observed state, not just a successful dispatcher response."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
SPEC=importlib.util.spec_from_file_location('contract_windows',ROOT/'scripts/window-service.py')
TOOL=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(TOOL)


class WindowContract(unittest.TestCase):
    def test_maximize_waits_for_geometry_after_tag_acknowledgement(self):
        windows=TOOL.Windows()
        before=dict(address='0xabc',closed=False,at=[200,100],size=[400,300],floating=True,maximized=False)
        tagged=dict(before,maximized=True)
        applied=dict(tagged,at=[8,48],size=[1264,680])
        observations=iter([before,tagged,applied])
        windows.observe=lambda _:next(observations)
        def action(*_):windows.expected_geometry=(8,48,1264,680);return {'mode':'maximized'}
        windows.action=action
        with patch.object(TOOL.time,'sleep') as sleep:
            result=windows.execute('maximize','abc')
        self.assertTrue(result['verified']);self.assertEqual(result['state'],applied);sleep.assert_called_once()

    def test_timeout_returns_observed_state_without_repeating_mutation(self):
        windows=TOOL.Windows();state=dict(address='0xabc',closed=False,hidden=False)
        windows.observe=lambda _:state
        calls=[];windows.action=lambda *_:calls.append('hide')
        with patch.object(TOOL.time,'monotonic',side_effect=[0,3]):
            with self.assertRaisesRegex(ValueError,'OutcomeUnknown') as caught:windows.execute('hide','abc')
        self.assertEqual(calls,['hide']);self.assertEqual(caught.exception.state,state)

    def test_close_ack_is_not_falsely_reported_as_window_closed(self):
        windows=TOOL.Windows();windows.observe=lambda _:dict(address='0xabc',closed=False)
        windows.action=lambda *_:None
        result=windows.execute('close','abc')
        self.assertTrue(result['accepted']);self.assertFalse(result['verified']);self.assertFalse(result['state']['closed'])

    def test_request_identity_and_failure_envelope(self):
        import contextlib
        import io
        import json
        import os
        import tempfile
        with tempfile.TemporaryDirectory() as temporary, patch.dict(os.environ,XDG_RUNTIME_DIR=temporary):
            with patch.object(TOOL.sys,'argv',['window-service.py','hide','abc','--request','test-7']):
                with patch.object(TOOL.Windows,'execute',side_effect=ValueError('WindowClosed')):
                    output=io.StringIO()
                    with contextlib.redirect_stdout(output):code=TOOL.main()
        result=json.loads(output.getvalue())
        self.assertEqual(code,1);self.assertEqual(result['version'],1);self.assertEqual(result['request'],'test-7')
        self.assertEqual(result['status'],'failure');self.assertEqual(result['code'],'WindowClosed');self.assertFalse(result['retryable'])


if __name__=='__main__':unittest.main()
