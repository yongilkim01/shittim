"""Focus IPC failures remain explicit; the probe never writes input or changes focus."""
import importlib.util
import json
from pathlib import Path
import subprocess
import unittest
from unittest.mock import Mock

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('focus_diagnostics', ROOT/'scripts/window-diagnostics.py')
TOOL = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(TOOL)


class FocusDiagnostics(unittest.TestCase):
    def test_old_or_unresponsive_shell_is_not_reported_as_working(self):
        for value in ('{}', 'error', '[]'):
            runner = Mock(return_value=subprocess.CompletedProcess([], 0, value))
            self.assertEqual(TOOL.desktop_focus(runner=runner), {'protocol': 0})
        for error in (FileNotFoundError(), subprocess.TimeoutExpired('quickshell', 2), subprocess.CalledProcessError(1, 'quickshell')):
            self.assertEqual(TOOL.desktop_focus(runner=Mock(side_effect=error)), {'protocol': 0})

    def test_probe_reads_the_running_instance_with_separate_arguments(self):
        value = {'protocol': 1, 'surfaces': [{'requested': True, 'windowActive': True}]}
        runner = Mock(return_value=subprocess.CompletedProcess([], 0, json.dumps(value)))
        self.assertEqual(TOOL.desktop_focus('startInputTrace', runner), value)
        command = runner.call_args.args[0]
        self.assertEqual(command[:3], ['quickshell', 'ipc', '--path'])
        self.assertEqual(command[3], str(ROOT/'shell/shell.qml'))
        self.assertEqual(command[4:], ['call', 'desktop', 'startInputTrace'])
        self.assertNotIn('shell', runner.call_args.kwargs)


if __name__ == '__main__': unittest.main()
