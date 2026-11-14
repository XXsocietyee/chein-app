"""Source and catalog checks for the full leaderboard page. Not an Xcode build."""
import json
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
CATALOG = ROOT / "docs/release/ui-strings-subpackageP3-pages-growthcenter-leaderboard-index.json"
EM = "—"


class GrowthLeaderboardPageReadyContract(unittest.TestCase):
    def setUp(self):
        self.catalog = json.loads(CATALOG.read_text())
        self.model = (ROOT / "Core/GrowthLeaderboardStanding.swift").read_text()
        self.view = (ROOT / "App/GrowthLeaderboardView.swift").read_text()
        self.components = (ROOT / "App/GrowthCenterComponents.swift").read_text()
        self.fixtures = (ROOT / "Core/GrowthCenterSyntheticFixtures.swift").read_text()

    def test_catalog_has_english_and_chinese_and_unknown_is_an_em_dash(self):
        self.assertEqual(self.catalog["page"], "subpackageP3/pages/growthcenter/leaderboard/index")
        self.assertEqual(self.catalog["unknownDisplay"], EM)
        self.assertNotEqual(self.catalog["unknownDisplay"], "0")
        keys = []
        for row in self.catalog["strings"]:
            self.assertEqual(set(row), {"key", "en", "zh-Hans"})
            self.assertTrue(row["key"] and row["en"] and row["zh-Hans"])
            keys.append(row["key"])
        self.assertEqual(len(keys), len(set(keys)))
        unknown = next(row for row in self.catalog["strings"] if row["key"] == "growth.unknown")
        self.assertEqual(unknown["en"], EM)
        self.assertEqual(unknown["zh-Hans"], EM)
        self.assertNotIn("https://", CATALOG.read_text())
        self.assertNotIn("http://", CATALOG.read_text())

    def test_accessibility_identifiers_match_the_existing_page(self):
        expected = [
            "growth.board.metric",
            "growth.board.period",
            "growth.board.me.\\(rank)",
            "growth.board.empty",
            "growthExplore.openHome",
            "growth.board.row.\\(index)",
            "growth.board.refresh",
            "growth.issue",
            "growth.retry",
            "growth.normal.leaderboard.hold",
        ]
        self.assertEqual(self.catalog["accessibilityIdentifiers"], expected)
        for identifier in expected:
            swift = identifier.replace("\\\\", "\\")
            combined = self.view + self.components
            self.assertTrue(
                f'.accessibilityIdentifier("{swift}")' in combined
                or f'messageIdentifier: "{swift}"' in combined
                or f'actionIdentifier: "{swift}"' in combined,
                identifier,
            )

    def test_model_keeps_loading_empty_error_and_unknown_and_hides_missing_boards(self):
        self.assertIn("case loading", self.model)
        self.assertIn("case empty(viewer: GrowthLeaderboardViewerFact?)", self.model)
        self.assertIn("case error(GrowthCenterIssue)", self.model)
        self.assertIn("case unknown", self.model)
        self.assertIn('public static let unknownDisplay = "—"', self.model)
        self.assertNotIn("?? 0", self.model)
        self.assertIn("case .productionBoard: return true", self.model)
        self.assertIn("case .anonymousBoard, .seasonBoard, .worldBoard, .teamBoard: return false", self.model)
        self.assertIn("case .seasonBoard, .worldBoard, .teamBoard: return nil", self.model)
        self.assertIn("return RePoint04GrowthLeaderboard.productionPath", self.model)
        self.assertIn("return RePoint04GrowthLeaderboard.unservedPath", self.model)
        self.assertIn("try await self.reader.leaderboard(query: requested)", self.model)
        self.assertNotIn("leaderboardContract: .anonymous", self.model)
        for flag in ["showsMerchantChoice", "paymentEnabled", "payoutEnabled", "withdrawalEnabled", "virtualGoodsEnabled"]:
            self.assertNotIn(flag, self.model)
        self.assertNotRegex(self.model, r"https?://")
        self.assertIn("guard me.rank.map({ $0 <= 0 }) ?? true else { return self }", self.model)

    def test_debug_fixture_data_already_covers_the_board(self):
        self.assertTrue(self.fixtures.startswith("#if DEBUG"))
        self.assertIn("public enum GrowthCenterSyntheticFixtures", self.fixtures)
        self.assertIn("public static let boardJSON", self.fixtures)
        self.assertIn("public static let emptyBoardJSON", self.fixtures)
        self.assertIn("#endif", self.fixtures)


if __name__ == "__main__":
    unittest.main()
