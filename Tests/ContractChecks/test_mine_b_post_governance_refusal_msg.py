"""mp-mine-b: 帖文处置与申诉 refusal shows the server msg like MP requestError(res, '申诉未提交')."""
import unittest
from pathlib import Path
W=Path(__file__).resolve().parents[2]
S=(W/'Core/SquareGovernanceService.swift').read_text()
C=(W/'Core/SquareGovernanceContracts.swift').read_text()
V=(W/'App/SettingsPostGovernanceView.swift').read_text()
class PostGovernanceRefusalMessageTests(unittest.TestCase):
 def test_failure_carries_message(self):self.assertIn('case appealRefused(message: String?)',C)
 def test_service_releases_then_throws_message(self):
  i=S.index('case .rejected:\n                release()')
  self.assertLess(i,S.index('throw SquareGovernanceFailure.appealRefused(message: Self.refusalMessage(body))'))
 def test_safe_filter(self):
  self.assertIn('static func refusalMessage(',S)
  self.assertIn('raw.count <= 60',S)
 def test_view_shows_message_keeps_form(self):
  self.assertIn('catch SquareGovernanceFailure.appealRefused(let message)',V)
  self.assertIn('notice = Self.refusalNotice(message, locale: locale)',V)
  self.assertIn('return "mpd.postGov.submitFailed"',V)
if __name__=='__main__':unittest.main()
