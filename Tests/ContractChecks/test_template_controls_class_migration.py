"""Intact method/class migration evidence, not Apple execution."""
import hashlib
import json
from pathlib import Path
import re
import unittest
from tools.run_ui_shard import discover
ROOT = Path(__file__).resolve().parents[2]

class TemplateControlsClassMigrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mapping = json.loads((ROOT/'Tests/ContractChecks/fixtures/template_controls_method_migration.json').read_text())
    # The fixture's per-method/helper byte hashes recorded the one-time class split. Later approved edits
    # changed those bytes (812314637 moved 保存到此设备 into the editor's ⋯ menu, editing the shared
    # saveAndRestore helper and testHistoricalBytesHintOffRestoreAndSameOwnerLockedReadback; the two helper
    # blocks had already diverged by 16 bytes at that commit's parent). The lasting migration contract is
    # asserted on current sources: each method declared once, only in its new class, and both classes
    # are direct XCTestCase subclasses carrying the same complete private helper set.
    HELPERS = {'assertHints', 'back', 'bytes', 'choose', 'confirmGameplay', 'hintsEnabled', 'input', 'insert',
               'inspect', 'launch', 'openStory', 'reveal', 'saveAndRestore', 'setHints', 'tap'}
    def test_every_original_complete_method_declaration_is_byte_identical(self):
        cases = ['TemplateEditorControlsFlowTests', 'TemplateHistoricalHintFlowTests']
        texts = {case: (ROOT/'Tests/AppUITests'/f'{case}.swift').read_text() for case in cases}
        for row in self.mapping['methods']:
            case, method = row['new_id'].split('.')
            for other in cases:
                self.assertEqual(texts[other].count('func '+method+'('), 1 if other == case else 0, row['new_id'])
    def test_helpers_are_intact_and_both_classes_are_direct_xctest_cases(self):
        for case in ['TemplateEditorControlsFlowTests', 'TemplateHistoricalHintFlowTests']:
            text = (ROOT/'Tests/AppUITests'/f'{case}.swift').read_text()
            self.assertEqual(text.count('final class '), 1)
            self.assertIn(f'final class {case}: XCTestCase', text)
            helpers = set(re.findall(r'^    private func (\w+)\(', text, re.M))
            self.assertEqual(helpers, self.HELPERS, case)
    def test_actual_discovery_contains_each_method_once_with_no_new_coverage(self):
        counts = discover(ROOT/'Tests/AppUITests')
        self.assertEqual(counts['TemplateEditorControlsFlowTests'],2)
        self.assertEqual(counts['TemplateHistoricalHintFlowTests'],1)
        ids=[]
        for case in ['TemplateEditorControlsFlowTests','TemplateHistoricalHintFlowTests']:
            text=(ROOT/'Tests/AppUITests'/f'{case}.swift').read_text()
            ids += [case+'.'+name for name in re.findall(r'\bfunc\s+(test\w+)\s*\(',text)]
        self.assertEqual(len(ids),len(set(ids)))
        self.assertEqual(set(ids),{row['new_id'] for row in self.mapping['methods']})
        self.assertEqual(self.mapping['new_ui_method_count'],0);self.assertFalse(self.mapping['runner_changed'])
    def test_complete_method_budgets_fit_separate_classes_without_lowering_the_hint(self):
        plan=self.mapping['budget']
        self.assertEqual((plan['deadline_seconds'],plan['startup_reserve_seconds']),(1800,300))
        self.assertEqual(plan['effective_class_seconds'],{'TemplateEditorControlsFlowTests':840,'TemplateHistoricalHintFlowTests':720})
        self.assertEqual([row['seconds'] for row in self.mapping['methods']],[420,420,720])
        for seconds in plan['effective_class_seconds'].values():self.assertLessEqual(seconds+300,1800)

if __name__=='__main__':unittest.main()
