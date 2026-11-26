"""Inline club leaderboard rows open the member the mini-program opens. Source check only."""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
KEYS = (
    "club.detail.leaderboard.member.open",
    "club.detail.leaderboard.member.public",
    "club.detail.leaderboard.member.customer",
    "club.detail.leaderboard.member.hint",
)


def strings(path):
    return json.loads(path.read_text())["strings"]


class ClubDetailLeaderboardMemberTests(unittest.TestCase):
    def test_fragment_matches_roster_catalog(self):
        fragment = strings(ROOT / "Resources/ClubDetailLeaderboardMember.fragment.json")
        catalog = strings(ROOT / "Resources/ClubPublicRoster.xcstrings")
        self.assertEqual(set(fragment), set(KEYS))
        for key in KEYS:
            for lang in ("en", "zh-Hans"):
                self.assertEqual(
                    fragment[key]["localizations"][lang]["stringUnit"]["value"],
                    catalog[key]["localizations"][lang]["stringUnit"]["value"],
                )
            self.assertEqual(set(fragment[key]["localizations"]), {"en", "zh-Hans"})

    def test_row_opens_public_profile_and_owner_customer_choice(self):
        source = (ROOT / "App/ClubDetailR8Mounts.swift").read_text()
        board = source.split("struct ClubInlineLeaderboardRows:", 1)[1].split("private enum ClubCloud14HTTPS", 1)[0]
        for token in (
            "row.memberID > 0",
            "club.isOwner || club.viewerIsAdmin",
            "SocialPublicProfileView(memberID: target.memberID",
            "operation: .customer",
            "club.detail.leaderboard.member.public",
            "club.detail.leaderboard.member.customer",
            "tableName: \"ClubPublicRoster\"",  # native-r2 club round 2: confirmationDialog Text(..., tableName:)
        ):
            self.assertIn(token, board)
        gap = board.split("if let hidden = row.hiddenCount", 1)[1].split("} else {", 1)[0]
        self.assertNotIn("open(", gap)
        detail = (ROOT / "App/ClubDetailView.swift").read_text()
        self.assertIn("ClubInlineLeaderboardRows(model: r8Leaderboard, club: club, identity: reader.clubIdentity, governance: governance)", detail)


if __name__ == "__main__":
    unittest.main()
