"""Source wiring only; no SwiftUI or server verification."""
from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[2]

class TeamInvitationExpiryLabelTests(unittest.TestCase):
    def test_only_expiry_semantics_in_wallet_team_detail(self):
        source = (ROOT / 'App/TicketWalletTeamView.swift').read_text()
        self.assertIn('detail.team.expireTime', source)
        self.assertIn('"team.invitationExpiry"', source)
        self.assertIn('"team.invitationExpiryUnknown"', source)
        self.assertNotIn('"team.sessionStart"', source)
        self.assertNotIn('"team.timeUnknown"', source)

    def test_both_catalogs_have_matching_explicit_translations(self):
        catalogs = [json.loads((ROOT / path).read_text())['strings'] for path in
                    ('Resources/TeamLocalizations.fragment.json', 'Resources/Localizable.xcstrings')]
        expected = {
            'team.invitationExpiry': {'en': 'Invitation expires', 'zh-Hans': '邀请到期时间'},
            'team.invitationExpiryUnknown': {'en': 'Invitation expiry not provided', 'zh-Hans': '邀请到期时间未提供'},
        }
        for key, values in expected.items():
            self.assertEqual(catalogs[0][key], catalogs[1][key])
            for lang, value in values.items():
                self.assertEqual(catalogs[0][key]['localizations'][lang]['stringUnit']['value'], value)

if __name__ == '__main__':
    unittest.main()
