"""The external browser palette and installed assets follow the actual shell tokens."""
import json
from pathlib import Path
import re
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


class DesktopDesign(unittest.TestCase):
    def test_browser_is_a_color_theme_with_the_same_shell_palette(self):
        manifest = json.loads((ROOT / 'assets/chrome-theme/manifest.json').read_text(encoding='utf-8'))
        self.assertEqual(set(manifest), {'name', 'description', 'version', 'manifest_version', 'theme'})
        self.assertEqual(manifest['manifest_version'], 3)
        self.assertEqual(set(manifest['theme']), {'colors'})
        tokens = dict(re.findall(r'property color (\w+): "(#[a-fA-F0-9]{6})"', (ROOT / 'shell/ui/Theme.qml').read_text()))
        for key, token in {'frame':'background', 'toolbar':'surface', 'tab_text':'textPrimary',
                           'toolbar_button_icon':'accent', 'omnibox_background':'background'}.items():
            rgb = [int(tokens[token][start:start+2],16) for start in (1,3,5)]
            self.assertEqual(manifest['theme']['colors'][key], rgb)

    def test_svg_assets_parse_and_reference_gradients_exist(self):
        for path in (ROOT / 'assets/icons/Shittim-HUD').rglob('*.svg'):
            with self.subTest(icon=path.name):
                tree = ET.parse(path)
                identifiers = {node.get('id') for node in tree.iter() if node.get('id')}
                for node in tree.iter():
                    for value in node.attrib.values():
                        for reference in re.findall(r'url\(#([^)]+)\)', value):
                            self.assertIn(reference, identifiers)


if __name__ == '__main__': unittest.main()
