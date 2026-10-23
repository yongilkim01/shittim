"""Installer file operations against temporary homes; no system installation."""
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('config_tool', Path(__file__).resolve().parents[1] / 'scripts/config-tool.py')
TOOL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TOOL)


class InstallerFiles(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.root = self.base / 'repo with spaces'
        self.home = self.base / 'home'
        self.root.mkdir()
        self.home.mkdir()
        (self.root / 'dotfiles').mkdir()
        (self.root / 'shell').mkdir()
        (self.root / 'shell/shell.qml').write_text('import Quickshell\nShellRoot {}\n')
        self.env = patch.dict(os.environ, {'HOME': str(self.home), 'XDG_CONFIG_HOME': str(self.home / '.config'), 'XDG_STATE_HOME': str(self.home / '.local/state'), 'SHELL': '/bin/bash', 'ZDOTDIR': ''})
        self.env.start()
        self.addCleanup(self.env.stop)
        self.config = TOOL.Config(self.root, self.home)

    def file(self, base, relative, text):
        path = base / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding='utf-8')
        return path

    def symlink(self, target, destination):
        destination.parent.mkdir(parents=True, exist_ok=True)
        try:
            destination.symlink_to(target, target_is_directory=target.is_dir())
        except OSError as error:
            if os.name == 'nt':
                self.skipTest('Windows 심볼릭 링크 권한 없음: ' + str(error))
            raise

    def test_capture_missing_and_sensitive_files(self):
        good = self.file(self.config.config, 'hypr/hyprland.lua', 'hl.env("XCURSOR_SIZE", "24")\n')
        self.file(self.config.config, 'hypr/private.lua', 'local api_key = "example"\n')
        self.file(self.config.config, 'kitty/kitty.conf', 'font_family Hack Nerd Font Mono\n')
        self.file(self.config.config, 'fcitx5/profile', '[Groups/0]\nName=Default\n')
        self.file(self.config.config, 'NetworkManager/system-connections/wifi.nmconnection', 'psk=example')
        self.file(self.home, '.ssh/id_rsa', 'BEGIN PRIVATE KEY')
        before = good.read_bytes()
        self.config.capture()
        self.assertEqual(good.read_bytes(), before)
        self.assertTrue((self.root / 'dotfiles/hypr/hyprland.lua').is_file())
        self.assertFalse((self.root / 'dotfiles/hypr/private.lua').exists())
        self.assertEqual(len(self.config.inventory()), 3)

    def test_capture_update_requires_flag_and_keeps_backup(self):
        original = self.file(self.root, 'dotfiles/kitty/kitty.conf', 'font_size 12\n')
        self.file(self.config.config, 'kitty/kitty.conf', 'font_size 14\n')
        self.config.capture()
        self.assertEqual(original.read_text(), 'font_size 12\n')
        self.config.capture(update=True)
        self.assertEqual(original.read_text(), 'font_size 14\n')
        backups = list(self.config.backups.rglob('kitty.conf'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), 'font_size 12\n')

    def test_dry_run_does_not_create_state_or_copy_files(self):
        self.file(self.config.config, 'kitty/kitty.conf', 'font_size 14\n')
        dry = TOOL.Config(self.root, self.home, dry=True)
        dry.capture()
        dry.write(self.home / '.profile', 'profile\n')
        self.assertFalse((self.home / '.profile').exists())
        self.assertFalse(dry.state.exists())
        self.assertEqual(list((self.root / 'dotfiles').iterdir()), [])

    def test_unknown_files_and_secrets_abort_inventory(self):
        for relative, text in [('hypr/unsafe.lua', 'local password="example"'), ('hypr/unknown.sh', 'echo example'), ('kitty/kitty.conf', 'https://user:example@host/path'), ('hypr/hyprland.lua', '-- Managed by Shittim\n')]:
            with self.subTest(relative=relative):
                path = self.file(self.root / 'dotfiles', relative, text)
                with self.assertRaises(ValueError):
                    self.config.inventory()
                path.unlink()

    def test_symlink_backup_repair_and_repeated_link(self):
        source = self.file(self.root / 'dotfiles', 'kitty/kitty.conf', 'font_size 14\n')
        target = self.file(self.config.config, 'kitty/kitty.conf', 'font_size 11\n')
        probe = self.home / 'probe'
        self.symlink(source, probe)
        probe.unlink()
        self.config.link_dotfiles()
        self.assertTrue(target.is_symlink())
        self.assertEqual(target.resolve(), source.resolve())
        self.assertEqual(list(self.config.backups.rglob('kitty.conf'))[0].read_text(), 'font_size 11\n')
        self.config.link_dotfiles()
        self.assertEqual(len(list(self.config.backups.rglob('kitty.conf'))), 1)
        target.unlink()
        target.symlink_to(self.home / 'missing')
        # A separate run gets its own private backup directory.
        repair = TOOL.Config(self.root, self.home)
        repair.link_dotfiles()
        self.assertEqual(target.resolve(), source.resolve())

    def test_directory_symlink_preserves_unmanaged_files(self):
        external = self.base / 'existing kitty'
        extra = self.file(external, 'extra.conf', 'keep me\n')
        self.file(external, 'kitty.conf', 'font_size 11\n')
        self.symlink(external, self.config.config / 'kitty')
        self.file(self.root / 'dotfiles', 'kitty/kitty.conf', 'font_size 14\n')
        self.config.link_dotfiles()
        self.assertEqual(extra.read_text(), 'keep me\n')
        self.assertEqual((external / 'kitty.conf').read_text(), 'font_size 11\n')
        self.assertEqual((self.config.config / 'kitty/extra.conf').read_text(), 'keep me\n')

    def test_capture_external_symlink_is_excluded(self):
        outside = self.file(self.base, 'external.conf', 'font_size 11\n')
        self.symlink(outside, self.config.config / 'kitty/kitty.conf')
        self.config.capture()
        self.assertEqual(self.config.inventory(), [])

    def test_profile_is_idempotent_and_preserves_existing_settings(self):
        path = self.file(self.home, '.bash_profile', 'export EDITOR=vim\n')
        profile, expected = self.config.profile()
        self.assertEqual(path, profile)
        self.assertIn('/dev/tty1', expected)
        self.assertIn('SSH_CONNECTION', expected)
        self.assertIn('disable-autostart', expected)
        self.config.write(profile, expected)
        self.assertEqual(self.config.profile()[1], expected)
        self.assertTrue(expected.startswith('export EDITOR=vim\n'))

    def test_complex_session_launcher_is_not_overwritten(self):
        original = 'exec uwsm start hyprland.desktop\n'
        path = self.file(self.home, '.bash_profile', original)
        with self.assertRaises(ValueError):
            self.config.profile()
        self.assertEqual(path.read_text(), original)

    def test_capture_managed_main_collects_original(self):
        self.file(self.config.config, 'hypr/hyprland.lua', '-- Managed by Shittim\ndofile("base")\n')
        self.file(self.config.config, 'hypr/shittim-base.lua', '-- user settings\n')
        self.config.capture()
        self.assertEqual((self.root / 'dotfiles/hypr/hyprland.lua').read_text(), '-- user settings\n')
        self.assertFalse((self.root / 'dotfiles/hypr/shittim-base.lua').exists())

    @patch.object(TOOL.subprocess, 'run')
    @patch.object(TOOL.subprocess, 'check_output', return_value='D2Koding Nerd Font Mono\n')
    def test_autostart_repeat_and_verify_drift(self, _output, _run):
        original = self.file(self.config.config, 'hypr/hyprland.lua', '-- real user settings\n')
        self.config.autostart()
        self.assertEqual((self.config.config / 'hypr/shittim-base.lua').read_text(), '-- real user settings\n')
        self.assertIn('hl.exec_cmd', original.read_text())
        self.config.verify()
        first_backups = sorted(str(p) for p in self.config.backups.rglob('*'))
        self.config.autostart()
        self.assertEqual(sorted(str(p) for p in self.config.backups.rglob('*')), first_backups)
        self.file(self.config.config, 'systemd/user/shittim.service', 'broken\n')
        with self.assertRaises(ValueError):
            self.config.verify()

    def test_state_inside_repository_is_rejected(self):
        with patch.dict(os.environ, {'XDG_STATE_HOME': str(self.root / 'state')}):
            with self.assertRaises(ValueError):
                TOOL.Config(self.root, self.home)

    @patch.object(TOOL.subprocess, 'run')
    @patch.object(TOOL.subprocess, 'check_output', return_value='D2Koding Nerd Font Mono\n')
    def test_fresh_install_uses_package_default(self, _output, _run):
        default = self.file(self.base, 'package/hyprland.lua', '-- package default fixture\n')
        probe = self.home / 'probe'
        self.symlink(default, probe)
        probe.unlink()
        with patch.object(TOOL, 'DEFAULT_HYPRLAND', default):
            self.config.autostart()
            self.assertEqual((self.config.config / 'hypr/shittim-base.lua').resolve(), default.resolve())
            self.assertEqual(list((self.root / 'dotfiles').iterdir()), [])
            self.config.verify()


if __name__ == '__main__':
    unittest.main()
