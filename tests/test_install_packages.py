"""Run the package installer with fake commands; never install system packages."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(sys.platform == 'linux' and shutil.which('bash'), 'Linux Bash에서 설치 명령을 격리하여 검사')
class PackageInstaller(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.commands = self.base / 'bin'; self.commands.mkdir()
        self.record = self.base / 'commands.log'
        shutil.copyfile(ROOT / 'scripts/install-packages.sh', self.base / 'install-packages.sh')
        (self.base / 'common.sh').write_text('''set -Eeuo pipefail
SHITTIM_DRY_RUN=0
no_extra_args() { :; }
require_user() { :; }
require_arch() { :; }
require_command() { command -v "$1" >/dev/null; }
load_packages() { SHITTIM_PACKAGES=(fixture-one fixture-two); }
check_session_versions() { :; }
info() { printf '%s\\n' "$*"; }
die() { printf '%s\\n' "$*" >&2; exit 1; }
''')
        self.command('sudo', '#!/bin/bash\nexec "$@"\n')
        self.command('systemctl', '#!/bin/bash\nexit 0\n')
        self.command('pacman', '#!' + sys.executable + '''
import os, signal, sys
from pathlib import Path
signal.signal(signal.SIGPIPE, signal.SIG_DFL)
with Path(os.environ['SHITTIM_TEST_RECORD']).open('a') as output:
    output.write(' '.join(sys.argv[1:]) + '\\n')
if sys.argv[1] == '-Si':
    os.write(1, ('Repository      : ' + os.environ.get('SHITTIM_TEST_REPO', 'extra') + '\\n').encode())
    for _ in range(256):
        os.write(1, b'Description     : ' + b'x' * 4096 + b'\\n')
    sys.exit(int(os.environ.get('SHITTIM_TEST_INFO_STATUS', '0')))
''')
        self.env = dict(os.environ, PATH=str(self.commands) + os.pathsep + os.environ['PATH'],
                        SHITTIM_TEST_RECORD=str(self.record), SHITTIM_WITH_POWER_PROFILES='0')

    def command(self, name, text):
        path = self.commands / name; path.write_text(text); path.chmod(0o755)

    def run_installer(self):
        return subprocess.run(['bash', str(self.base / 'install-packages.sh')], env=self.env,
                              capture_output=True, text=True, timeout=10)

    def test_large_package_metadata_is_consumed_without_sigpipe(self):
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stderr)
        commands = self.record.read_text().splitlines()
        self.assertIn('-Si -- fixture-one', commands)
        self.assertIn('-Si -- fixture-two', commands)
        self.assertIn('-S --needed -- fixture-one fixture-two', commands)

    def test_unofficial_repository_does_not_install_packages(self):
        self.env['SHITTIM_TEST_REPO'] = 'untrusted'
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('공식 패키지를 찾지 못했습니다', result.stderr)
        self.assertFalse(any(line.startswith('-S ') for line in self.record.read_text().splitlines()))

    def test_failed_package_query_is_not_hidden_by_output_parser(self):
        self.env['SHITTIM_TEST_INFO_STATUS'] = '1'
        result = self.run_installer()
        self.assertEqual(result.returncode, 1)
        self.assertFalse(any(line.startswith('-S ') for line in self.record.read_text().splitlines()))


if __name__ == '__main__':
    unittest.main()
