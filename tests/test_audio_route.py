"""Per-application output routing: only real streams and sinks, argument lists, and clear failure codes."""
import importlib.util
import json
from pathlib import Path
import unittest
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('audio_route', ROOT / 'scripts/audio-route.py')
ROUTE = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(ROUTE)

DUMP = [
    {'id': 40, 'type': 'PipeWire:Interface:Node', 'info': {'props': {'media.class': 'Audio/Sink', 'object.serial': 40}}},
    {'id': 41, 'type': 'PipeWire:Interface:Node', 'info': {'props': {'media.class': 'Audio/Sink', 'object.serial': 4100}}},
    {'id': 53, 'type': 'PipeWire:Interface:Node', 'info': {'props': {'media.class': 'Stream/Output/Audio', 'object.serial': 53}}},
    {'id': 54, 'type': 'PipeWire:Interface:Node', 'info': {'props': {'media.class': 'Stream/Input/Audio', 'object.serial': 54}}},
    {'id': 7, 'type': 'PipeWire:Interface:Link', 'info': {}},
]


class FakeRunner:
    def __init__(self, dump=DUMP, dump_code=0, metadata_code=0):
        self.calls, self.dump, self.dump_code, self.metadata_code = [], dump, dump_code, metadata_code

    def __call__(self, args):
        self.calls.append(args)
        if args[0] == 'pw-dump':
            return SimpleNamespace(returncode=self.dump_code, stdout=json.dumps(self.dump), stderr='')
        return SimpleNamespace(returncode=self.metadata_code, stdout='', stderr='')


class AudioRoute(unittest.TestCase):
    def test_move_sets_target_object_by_serial(self):
        runner = FakeRunner()
        self.assertEqual(ROUTE.move('53', '4100', runner), {'state': 'moved', 'stream': 53, 'target': '4100'})
        self.assertEqual(runner.calls[-1], ['pw-metadata', '-n', 'default', '53', 'target.object', '4100', 'Spa:Id'])

    def test_default_removes_the_pin(self):
        runner = FakeRunner()
        ROUTE.move('53', 'default', runner)
        self.assertEqual(runner.calls[-1], ['pw-metadata', '-n', 'default', '-d', '53', 'target.object'])

    def test_only_playback_streams_and_sinks(self):
        for stream, target, code in (('54', '40', 'StreamNotFound'), ('40', '40', 'StreamNotFound'), ('999', '40', 'StreamNotFound'),
                                     ('53', '53', 'TargetNotFound'), ('53', '41', 'TargetNotFound')):
            runner = FakeRunner()
            with self.assertRaisesRegex(ROUTE.RouteError, code):
                ROUTE.move(stream, target, runner)
            self.assertFalse(any(call[0] == 'pw-metadata' for call in runner.calls))

    def test_arguments_are_never_commands(self):
        for stream, target in (('1;rm -rf /', '40'), ('53', '$(id)'), ('', '40'), ('53', '-d'), ('12345678901', '40')):
            runner = FakeRunner()
            with self.assertRaisesRegex(ROUTE.RouteError, 'InvalidArguments'):
                ROUTE.move(stream, target, runner)
            self.assertEqual(runner.calls, [])

    def test_failures(self):
        with self.assertRaisesRegex(ROUTE.RouteError, 'PipeWireUnavailable'):
            ROUTE.move('53', '40', FakeRunner(dump_code=1))
        with self.assertRaisesRegex(ROUTE.RouteError, 'MetadataFailed'):
            ROUTE.move('53', '40', FakeRunner(metadata_code=1))
        self.assertEqual(ROUTE.main(['move', '53']), 2)


if __name__ == '__main__':
    unittest.main()
