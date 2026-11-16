"""Design hand-off r1 (member/club + merchant/creator) kit contract.

Every literal key passed to clubR1(...) / merchantR1(...) exists in its catalog, the catalogs are
in sync with tools/build_design_r1_localizations.py, and no local stand-in for a shared
design-system piece remains (they were replaced at integration).
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

    def test_stand_ins_are_replaced(self):
        # Integration (ui/h-integ-d-r1): every HANDOFF-R1 stand-in now uses the shared design r1 component
        # (CYPillButtonStyle, CYStatusTag, CYSheetHeader / CYResizableSheet) and the stand-in types are gone.
        sources = [*swift_sources(), ROOT / 'App/EditorKitSheet.swift', ROOT / 'App/EditorKitFoundation.swift']
        gone = ('ClubR1PillButtonStyle', 'ClubR1StatusTag', 'ClubR1SheetHeader', 'ClubR1SheetStyle', 'ClubR1SheetSize',
                'clubR1Sheet(', 'MerchantR1ButtonStyle', 'MerchantR1StatusTag', 'MerchantR1Chip', 'EditorKitPillButtonStyle')
        for source in sources:
            text = source.read_text()
            self.assertNotIn('HANDOFF-R1: replace with DS component', text, source.name)
            for name in gone:
                self.assertNotIn(name, text, f'{source.name}: {name}')
        kit = (ROOT / 'App/ClubKit/ClubR1Kit.swift').read_text()
        self.assertIn('var tagState: CYStatusTagState', kit)

    def test_kits_do_not_edit_shared_design_system(self):
        for folder in ('App/ClubKit', 'App/MerchantKit'):
            for source in sorted((ROOT / folder).glob('*.swift')):
                text = source.read_text()
                self.assertNotRegex(text, r'extension\s+CY(Color|Typography|Spacing|Radius)\b', source.name)


if __name__ == '__main__':
    unittest.main()
