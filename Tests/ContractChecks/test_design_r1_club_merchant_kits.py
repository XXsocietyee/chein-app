"""Design hand-off r1 (member/club + merchant/creator) kit contract.

Every literal key passed to clubR1(...) / merchantR1(...) exists in its catalog, the catalogs are
in sync with tools/build_design_r1_localizations.py, and each local stand-in for a shared
design-system piece carries the HANDOFF-R1 replacement marker.
"""
import json
import re
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CALL = {
    'clubR1': ('r1club', ROOT / 'Resources/DesignR1Club.xcstrings'),
    'merchantR1': ('r1merchant', ROOT / 'Resources/DesignR1Merchant.xcstrings'),
}
MARKER = '// HANDOFF-R1: replace with DS component from ui/d-r1-foundation-player'


def swift_sources():
    return sorted([*ROOT.glob('App/*.swift'), *ROOT.glob('App/ClubKit/*.swift'), *ROOT.glob('App/MerchantKit/*.swift')])


class DesignR1KitContract(unittest.TestCase):
    def test_catalogs_are_generated(self):
        result = subprocess.run([sys.executable, '-B', str(ROOT / 'tools/build_design_r1_localizations.py'), '--check'],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_literal_keys_exist(self):
        missing = []
        for function, (prefix, path) in CALL.items():
            keys = set(json.loads(path.read_text())['strings'])
            pattern = re.compile(r'\b' + function + r'\(\s*"([A-Za-z0-9_.]+)"')
            interpolated = re.compile(r'\b' + function + r'\(\s*"([A-Za-z0-9_.]*)\\\(')
            for source in swift_sources():
                text = source.read_text()
                for key in pattern.findall(text):
                    if f'{prefix}.{key}' not in keys:
                        missing.append(f'{source.relative_to(ROOT)}: {key}')
                for stem in interpolated.findall(text):
                    if not any(k.startswith(f'{prefix}.{stem}') for k in keys):
                        missing.append(f'{source.relative_to(ROOT)}: {stem}*')
        self.assertEqual(missing, [])

    def test_stand_ins_are_marked(self):
        kit = (ROOT / 'App/ClubKit/ClubR1Kit.swift').read_text()
        for name in ('ClubR1PillButtonStyle', 'ClubR1Status', 'ClubR1SheetHeader', 'ClubR1SheetStyle'):
            index = kit.index(f'struct {name}:') if f'struct {name}:' in kit else kit.index(f'enum {name}:')
            self.assertIn(MARKER, kit[max(0, index - 400):index], name)

    def test_kits_do_not_edit_shared_design_system(self):
        for folder in ('App/ClubKit', 'App/MerchantKit'):
            for source in sorted((ROOT / folder).glob('*.swift')):
                text = source.read_text()
                self.assertNotRegex(text, r'extension\s+CY(Color|Typography|Spacing|Radius)\b', source.name)


if __name__ == '__main__':
    unittest.main()
