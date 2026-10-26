"""Export only the window-check schema and reuse scoped Git publishing."""
import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('share_window_report', ROOT/'scripts/share-window-diagnostics.py')
TOOL = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(TOOL)


class WindowReport(unittest.TestCase):
    def report(self):
        return {'settings': {'input:follow_mouse': 2, 'input:float_switch_override_focus': 0, 'token': 'private-data'},
            'problems': ['private-data'], 'samples': [{'time': 1000, 'active': '0xabc', 'cursor': {'x': 200, 'y': 100},
                'keyboardText': 'private-data', 'windows': [{'address': '0xabc', 'class': 'org.shittim.Files', 'title': 'private-data',
                    'at': [200, 100], 'size': [800, 500], 'monitor': 0, 'workspace': 1, 'floating': True, 'mapped': True, 'hidden': False,
                    'fullscreen': 0, 'fullscreenClient': 0, 'tags': ['private-data', 'shittim-maximized', 'shittim-restore_200_100_800_500_1']}],
                'monitors': [{'id': 0, 'name': 'private-data', 'x': 0, 'y': 0, 'width': 1920, 'height': 1080,
                    'scale': 1.25, 'transform': 0, 'focused': True, 'reserved': [0, 40, 0, 72]}]}]}

    def test_export_keeps_geometry_and_omits_unapproved_data(self):
        source = self.report(); before = json.dumps(source)
        result = TOOL.clean_report(source)
        self.assertNotIn('private-data', json.dumps(result))
        self.assertEqual(json.dumps(source), before)
        self.assertEqual(result['samples'][0]['time'], 0)
        self.assertEqual(result['samples'][0]['windows'][0]['size'], [800, 500])
        self.assertEqual(len(result['samples'][0]['windows'][0]['tags']), 2)

    def test_invalid_coordinate_or_arbitrary_strings_are_not_published(self):
        for value in (float('nan'), float('inf'), 'secret', True):
            source = self.report(); source['samples'][0]['windows'][0]['at'][0] = value
            with self.assertRaises(ValueError): TOOL.clean_report(source)
        source = self.report(); source['samples'][0]['windows'][0]['class'] = '/home/private/document'
        self.assertEqual(TOOL.clean_report(source)['samples'][0]['windows'][0]['class'], '<other>')

    def test_publish_only_stages_and_commits_the_selected_window_report(self):
        replies = ['main', '', 'https://github.com/yongilkim01/shittim.git', '', '', '', '', 'diagnostics/windows-latest.json', '', 'abc1234']
        with patch.object(TOOL.DIAG, 'git', side_effect=replies) as git, patch.object(TOOL.DIAG.subprocess, 'run') as run:
            TOOL.DIAG.publish(TOOL.REPORT, 'chore: share laptop window diagnostics')
        self.assertIn(('add', '--', TOOL.REPORT.as_posix()), [call.args for call in git.call_args_list])
        self.assertIn(('commit', '-m', 'chore: share laptop window diagnostics', '--', TOOL.REPORT.as_posix()), [call.args for call in git.call_args_list])
        self.assertEqual(run.call_args.args[0], ['git', 'push', 'origin', 'HEAD:refs/heads/main'])

    def test_same_report_does_not_create_another_commit_or_push(self):
        replies = ['main', '', 'https://github.com/yongilkim01/shittim.git', '', '', '', '', '']
        with patch.object(TOOL.DIAG, 'git', side_effect=replies) as git, patch.object(TOOL.DIAG.subprocess, 'run') as run:
            TOOL.DIAG.publish(TOOL.REPORT, 'chore: share laptop window diagnostics')
        self.assertFalse(any(call.args[0]=='commit' for call in git.call_args_list)); run.assert_not_called()

    def test_retry_pushes_existing_report_commit_after_a_failed_upload(self):
        replies = ['main', '', 'https://github.com/yongilkim01/shittim.git', '', '', 'diagnostics/windows-latest.json', '', '', 'abc1234']
        with patch.object(TOOL.DIAG, 'git', side_effect=replies) as git, patch.object(TOOL.DIAG.subprocess, 'run') as run:
            TOOL.DIAG.publish(TOOL.REPORT, 'chore: share laptop window diagnostics')
        self.assertFalse(any(call.args[0]=='commit' for call in git.call_args_list))
        self.assertEqual(run.call_args.args[0], ['git', 'push', 'origin', 'HEAD:refs/heads/main'])


if __name__=='__main__': unittest.main()
