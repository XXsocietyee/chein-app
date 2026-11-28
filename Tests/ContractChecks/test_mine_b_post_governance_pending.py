"""mp-mine-b: Settings → 帖文处置与申诉 shows the MP pg-warn (pendingUnknown) per row and reads back an unknown submit, as MP post-governance."""
import json
import unittest
from pathlib import Path
W=Path(__file__).resolve().parents[2]
V=(W/'App/SettingsPostGovernanceView.swift').read_text()
C=(W/'Core/SquareGovernanceCoordinator.swift').read_text()
S=json.loads((W/'Resources/Localizable.xcstrings').read_text())['strings']
class PostGovernancePendingTests(unittest.TestCase):
 def test_core_reads_journal_only(self):
  self.assertIn('public func appealOutcomeUnconfirmed(enforcementID: Int, snapshot: SquareGovernanceSnapshot) -> Bool',C)
  self.assertIn('journal.contains("appeal:\\(enforcementID)", identity: snapshot.identity)',C)
 def test_row_warning_replaces_dead_appeal(self):
  self.assertIn('if row.canAppeal && unconfirmed(row) {',V)
  self.assertIn('Text("mpd.postGov.pendingUnknown")',V)
  self.assertIn('settings.postGov.pending.',V)
 def test_unknown_submit_reads_back(self):
  self.assertIn('notice = "mpd.postGov.confirming"',V)
  self.assertIn('notice = "mpd.postGov.unconfirmed"',V)
  self.assertNotIn('notice = "mpd.postGov.unknown"',V)
 def test_copy_both_languages(self):
  for k in ('mpd.postGov.pendingUnknown','mpd.postGov.confirming','mpd.postGov.unconfirmed'):
   loc=S[k]['localizations']
   self.assertTrue(loc['en']['stringUnit']['value']);self.assertTrue(loc['zh-Hans']['stringUnit']['value'])
  self.assertTrue(S['mpd.postGov.pendingUnknown']['localizations']['zh-Hans']['stringUnit']['value'].startswith('上次申诉的提交结果未确认'))
if __name__=='__main__':unittest.main()
