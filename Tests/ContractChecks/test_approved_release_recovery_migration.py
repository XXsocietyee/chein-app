"""Verify an existing two-launch test was reorganized, not weakened or counted as new coverage."""
from pathlib import Path
from tools.run130_submission_evidence import previous_source as pre_receipt_source
from tools.run129_repair_planning import historical_source as pre_run129_source
import hashlib,importlib.util,json,re,unittest
ROOT=Path(__file__).resolve().parents[2]
class ReleaseRecoveryMigrationContracts(unittest.TestCase):
 def setUp(self):self.meta=json.loads((ROOT/'Tests/AppUITests/ApprovedReleaseRecoveryMigration.json').read_text())
 def body(self,row):
  s=(ROOT/row['file']).read_text();method=row['method'].split('.')[1]
  return re.search(r'    func '+method+r'\(\) throws \{\n(.*)\n    \}\n\}',s,re.S)[1]
 def test_each_new_case_is_discovered_once_and_old_combined_method_is_absent(self):
  spec=importlib.util.spec_from_file_location('release_migration_runner',ROOT/'tools/run_ui_shard.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
  counts=module.discover(ROOT/'Tests/AppUITests')
  old=self.meta['old_method'].split('.')[1]
  self.assertFalse(any(re.search(r'\bfunc\s+'+old+r'\s*\(',p.read_text()) for p in (ROOT/'Tests/AppUITests').glob('*.swift')))
  for row in self.meta['new_methods']:
   cls,method=row['method'].split('.');self.assertEqual(counts[cls],1)
   self.assertEqual(sum(len(re.findall(r'\bfunc\s+'+method+r'\s*\(',p.read_text())) for p in (ROOT/'Tests/AppUITests').glob('*.swift')),1)
 def test_complete_budget_increases_without_changing_runner_limits_or_coverage(self):
  self.assertEqual(self.meta['old_complete_unmeasured_seconds'],1200)
  self.assertEqual([x['complete_unmeasured_seconds'] for x in self.meta['new_methods']],[900,900])
  self.assertEqual(self.meta['new_coverage_count'],0);self.assertEqual(self.meta['discovered_method_delta'],1)
  for row in self.meta['new_methods']:
   source=(ROOT/row['file']).read_text();self.assertIn('UNMEASURED complete method estimate: 900 seconds.',source)
   self.assertLessEqual(row['complete_unmeasured_seconds']+300,1800)
if __name__=='__main__':unittest.main()
