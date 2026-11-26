"""Static wiring for mini-program club/create → club/apply. Not Swift compiler or runtime evidence."""
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path): return (ROOT / path).read_text()


class ClubCreateHostApplicationContracts(unittest.TestCase):
    def test_non_leader_create_links_to_existing_host_status_read(self):
        view = read('App/ClubOperationsViews.swift')
        self.assertIn('if value.accountRole != "club", let hostApplication {', view)
        self.assertIn('ClubCreateHostApplicationLink(identity: identity, governance: hostApplication)', view)
        # The no-permission state keeps distinct leader-required / club-limit copy (mini-program club/create states).
        # verify-r1 2.3: the club-limit copy now carries the real count (club.ops.clubLimit.count).
        self.assertIn('if value.accountRole != "club" { Text("club.ops.leaderRequired.apply") }', view)
        self.assertIn('Text("club.ops.clubLimit.count \\(value.ownedClubIDs.count)")', view)
        link = read('App/ClubCreateHostApplicationLink.swift')
        self.assertIn('ClubGovernanceReadView(operation: .hostStatus, scope: .init()', link)
        self.assertNotIn('send(', link)
        self.assertIn('case .hostApply: return "api/club/become-leader"', read('Core/ClubGovernanceCommands.swift'))
        self.assertIn('hostApplication: management?.governance)', read('App/ClubHomeView.swift'))
        # CLB-r9-create-02 (MP create js:114-118, 192-200): a non-host is sent on to apply once per visit.
        self.assertIn('.modifier(ClubCreateHostAutoOpen(active: hostAutoOpenActive, identity: identity, governance: hostApplication))', view)
        self.assertIn('struct ClubCreateHostAutoOpen: ViewModifier', link)

    def test_fixture_opt_in_and_copy(self):
        fixture = read('App/ClubOperationsFixtureSupport.swift')
        self.assertIn('"--uitesting-club-operations-host-apply"', fixture)
        catalog = json.loads(read('Resources/Localizable.xcstrings'))['strings']
        self.assertEqual(catalog['club.ops.applyHost']['localizations']['zh-Hans']['stringUnit']['value'], '前往申请')
        for key, value in json.loads(read('Resources/ClubCreateHostApplicationLocalizations.fragment.json'))['strings'].items():
            self.assertEqual(catalog[key], value)


if __name__ == '__main__':
    unittest.main()
