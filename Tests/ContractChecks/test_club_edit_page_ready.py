"""CB243 pages/club/edit/index non-view contract. Does not execute Swift."""
import json
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
PAGE = "pages/club/edit/index"


class ClubEditPageReadyContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.model = (ROOT / "Core/ClubOperationsContracts.swift").read_text(encoding="utf-8")
        cls.fixtures = (ROOT / "Core/ClubOperationsSyntheticFixtures.swift").read_text(encoding="utf-8")
        cls.tests = (ROOT / "Tests/CoreTests/ClubEditPageTests.swift").read_text(encoding="utf-8")
        cls.dissolve = (ROOT / "Tests/CoreTests/ClubEditDissolveTests.swift").read_text(encoding="utf-8")
        cls.catalog = json.loads((ROOT / "docs/release/ui-strings-pages-club-edit-index.json").read_text(encoding="utf-8"))
        cls.xcstrings = json.loads((ROOT / "Resources/Localizable.xcstrings").read_text(encoding="utf-8"))["strings"]
        cls.routes = (ROOT / "Core/ChinaReviewedRouteCapability.swift").read_text(encoding="utf-8")

    def test_strings_are_bilingual_and_identified(self):
        self.assertEqual(self.catalog["page"], PAGE)
        self.assertEqual(self.catalog["native"], "App/ClubOperationsViews.swift")
        rows = self.catalog["strings"]
        self.assertGreaterEqual(len(rows), 30)
        keys = []
        for row in rows:
            self.assertEqual(set(row), {"key", "en", "zh-Hans", "accessibilityIdentifier"})
            self.assertTrue(row["en"].strip())
            self.assertTrue(row["zh-Hans"].strip())
            self.assertTrue(row["accessibilityIdentifier"].strip())
            item = self.xcstrings[row["key"]]["localizations"]
            self.assertEqual(row["en"], item["en"]["stringUnit"]["value"])
            self.assertEqual(row["zh-Hans"], item["zh-Hans"]["stringUnit"]["value"])
            keys.append(row["key"])
        for required in ["club.ops.manage", "club.ops.dissolve", "club.ops.unknownValue", "club.ops.readFailed", "club.ops.membersUnavailable", "club.ops.checking"]:
            self.assertIn(required, keys)
        unknown = next(row for row in rows if row["key"] == "club.ops.unknownValue")
        self.assertEqual(unknown["en"], "—")
        self.assertEqual(unknown["zh-Hans"], "—")
        blob = json.dumps(self.catalog, ensure_ascii=False)
        for banned in ["http://", "https://", "ICP", "京ICP", "support@"]:
            self.assertNotIn(banned, blob)

    def test_model_states_unknown_mark_and_player_first_gate(self):
        for state in ["case loading, empty, error, unknown, ready"]:
            self.assertIn(state, self.model)
        self.assertIn('public static let unknownMark = "—"', self.model)
        self.assertIn("known.map(String.init) ?? ClubEditPage.unknownMark", self.model)
        self.assertIn("if let int = try? container.decode(Int.self), int >= 0", self.model)
        self.assertIn("String(int) == trimmed", self.model)
        self.assertIn("if surface == .playerFirst { showsEdit = false; showsDissolve = false }", self.model)
        self.assertIn("case playerFirst", self.model)
        self.assertIn("guard let detailBody else { return make(read: .unknown", self.model)
        self.assertIn("ClubEditDissolveAccess.isAvailable", self.model)
        self.assertIn("ClubGovernanceMutation.dissolve.path", self.model)
        self.assertIn("ClubGovernanceRead.dissolutionBlockers.path", self.model)
        self.assertIn("ClubOperationsCommand.update", self.model)
        page = self.model.split("public struct ClubEditPage", 1)[1]
        for flag in ["showsMerchantChoice", "paymentEnabled", "payoutEnabled", "withdrawalEnabled", "virtualGoodsEnabled"]:
            self.assertNotIn(flag, page)
        for banned in ["https://", "http://", "api/club/dissolve", "api/club/update-mine"]:
            self.assertNotIn(banned, page)
        routes = set(re.findall(r'"(api/club/[^" ]+)"', self.model))
        self.assertEqual(len(routes), 6)

    def test_debug_fixture_data_keeps_unknown_distinct_from_zero(self):
        self.assertTrue(self.fixtures.startswith("#if DEBUG"))
        self.assertIn("public enum ClubEditFixtureData", self.fixtures)
        self.assertLess(self.fixtures.index("public enum ClubEditFixtureData"), self.fixtures.rindex("#endif"))
        for unsafe in ["URLSession", "https://", "http://", "UserDefaults"]:
            self.assertNotIn(unsafe, self.fixtures)
        literals = dict(re.findall(r'public static let (\w+) = #"(.*)"#', self.fixtures))
        unknown = json.loads(literals["unknownQuota"])
        explicit = json.loads(literals["explicitZero"])
        missing = json.loads(literals["missingQuota"])
        self.assertEqual(unknown["memberReservedQuota"], "UNKNOWN")
        self.assertEqual(unknown["memberCount"], "UNKNOWN")
        self.assertIs(explicit["memberReservedQuota"], 0)
        self.assertIs(explicit["memberCount"], 0)
        self.assertNotIn("memberReservedQuota", missing)
        self.assertNotIn("memberCount", missing)
        self.assertEqual(json.loads(literals["blockersEmpty"]), {"deposits": [], "settlements": []})
        self.assertNotIn("settlements", json.loads(literals["blockersMissing"]))

    def test_existing_dissolve_tests_and_live_routes_stay(self):
        self.assertIn("func testDissolveEntryIsOwnerOnly(", self.dissolve)
        self.assertIn("func testDissolveCommandNeedsExplicitConfirmationAndCarriesClubID(", self.dissolve)
        for name in [
            "testLoadingEmptyAndErrorUseTheEmDashAndHideActions",
            "testExplicitZeroStaysZeroAndUnknownQuotaStaysAnEmDash",
            "testPlayerFirstEntryHidesEditAndDissolve",
            "testCoordinatorReadbackDoesNotInventANumberFromTheSnapshot",
        ]:
            self.assertIn("func " + name + "(", self.tests)
        self.assertIn('"/api/club/update-mine": .liveInProduction', self.routes)
        self.assertIn('"/api/club/dissolve": .liveInProduction', self.routes)
        self.assertIn('.init(missing: "/api/club/update", production: "/api/club/update-mine")', self.routes)

    def test_views_project_and_manifest_were_not_the_edit_surface(self):
        # Naming the mini-program page in a comment is not a new route.
        self.assertNotIn('"/pages/club/edit', self.model)
        self.assertNotIn("showsMerchantChoice = true", self.model)
        self.assertNotIn("paymentEnabled = true", self.model)
        self.assertNotIn("payoutEnabled = true", self.model)
        self.assertNotIn("withdrawalEnabled = true", self.model)
        self.assertNotIn("virtualGoodsEnabled = true", self.model)


if __name__ == "__main__":
    unittest.main()
