"""Check local imports against Quickshell's entrypoint directory boundary."""
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]


class QmlImports(unittest.TestCase):
    def check_entrypoint(self, entrypoint):
        config_root = entrypoint.parent.resolve()
        pending = [entrypoint]
        visited = set()
        while pending:
            source = pending.pop().resolve()
            if source in visited:
                continue
            visited.add(source)
            self.assertTrue(source.is_file(), str(source))
            text = source.read_text(encoding='utf-8')
            for relative in re.findall(r'^\s*import\s+"([^"]+)"', text, re.MULTILINE):
                destination = (source.parent / relative).resolve()
                self.assertTrue(
                    destination == config_root or config_root in destination.parents,
                    '{}: import "{}" escapes config root {}'.format(source, relative, config_root))
                self.assertTrue(destination.exists(), str(destination))
                if destination.is_dir():
                    pending.extend(path for path in destination.glob('*.qml')
                                   if path.name[0].isupper())
                elif destination.suffix == '.qml':
                    pending.append(destination)

    def test_production_imports_stay_inside_config_root(self):
        self.check_entrypoint(ROOT / 'shell/shell.qml')

    def test_verification_uses_an_entrypoint_with_resolvable_imports(self):
        script = (ROOT / 'scripts/verify-control-center.sh').read_text(encoding='utf-8')
        match = re.search(r'quickshell --path "\$SHITTIM_ROOT/([^"\n]+)"', script)
        self.assertIsNotNone(match, 'Quickshell verification command is missing')
        self.check_entrypoint(ROOT / match.group(1))


if __name__ == '__main__':
    unittest.main()
