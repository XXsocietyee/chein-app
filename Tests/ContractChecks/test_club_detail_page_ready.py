"""CB242 page-ready contract for pages/club/detail/index. Source and JSON only."""
import json
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
STRINGS = ROOT / "docs/release/ui-strings-pages-club-detail-index.json"
MODEL = ROOT / "Core/ClubDetailTabs.swift"
TESTS = ROOT / "Tests/CoreTests/ClubDetailPageReadyTests.swift"
SOURCES = [
    ROOT / "Core/ClubDetailTabs.swift",
    ROOT / "App/ClubDetailView.swift",
    ROOT / "App/ClubDetailTabBar.swift",
    ROOT / "App/ClubDetailEventsSection.swift",
    ROOT / "App/ClubReadScreen.swift",
]


class ClubDetailPageReadyContract(unittest.TestCase):
    def test_strings_match_catalog_in_both_languages(self):
        document = json.loads(STRINGS.read_text())
        catalog = json.loads((ROOT / "Resources/Localizable.xcstrings").read_text())["strings"]
        self.assertEqual(document["page"], "pages/club/detail/index")
        self.assertEqual(document["unknownNumber"]["mark"], "\u2014")
        self.assertGreaterEqual(len(document["strings"]), 20)
        seen = set()
        for item in document["strings"]:
            key = item["key"]
            self.assertNotIn(key, seen)
            seen.add(key)
            entry = catalog[key]["localizations"]
            self.assertEqual(item["en"], entry["en"]["stringUnit"]["value"])
            self.assertEqual(item["zh-Hans"], entry["zh-Hans"]["stringUnit"]["value"])
            self.assertTrue(item["en"].strip())
            self.assertTrue(item["zh-Hans"].strip())
            self.assertNotIn("http", item["en"].lower())
            self.assertNotIn("http", item["zh-Hans"].lower())
            identifier = item.get("accessibilityIdentifier")
            if identifier is not None:
                self.assertIn(identifier, document["accessibilityIdentifiers"])

    def test_accessibility_identifiers_are_real_literals(self):
        document = json.loads(STRINGS.read_text())
        source = "\n".join(path.read_text() for path in SOURCES)
        self.assertGreaterEqual(len(document["accessibilityIdentifiers"]), 20)
        for identifier in document["accessibilityIdentifiers"]:
            self.assertRegex(identifier, r"^[a-z][A-Za-z0-9.]+$")
            self.assertIn('"%s"' % identifier, source)

    def test_model_keeps_states_unknown_dash_and_debug_fixture(self):
        model = MODEL.read_text()
        self.assertIn("case loading", model)
        self.assertIn("case empty", model)
        self.assertIn("case error(titleKey: String)", model)
        self.assertIn('public static let unknownMark = "\\u{2014}"', model)
        self.assertIn("ClubDetailPageFixtureData", model)
        debug = model.split("#if DEBUG", 1)[1]
        self.assertIn("enum ClubDetailPageFixtureData", debug.split("#endif", 1)[0])
        self.assertNotIn("showsMerchantChoice = true", model)
        for flag in ("paymentEnabled", "payoutEnabled", "withdrawalEnabled", "virtualGoodsEnabled"):
            self.assertIn("ReleaseMoneyWriteSwitch.%s" % flag, model)
            self.assertNotRegex(model, r"%s\s*=\s*true" % flag)
        switches = (ROOT / "Core/ChinaReviewedRouteCapability.swift").read_text()
        for flag in ("paymentEnabled", "payoutEnabled", "withdrawalEnabled", "virtualGoodsEnabled"):
            self.assertIn("public static var %s: Bool { testDerivation?" % flag, switches)
        self.assertIn('"/api/club/channels": .liveInProduction', switches)
        welcome = (ROOT / "App/WelcomeView.swift").read_text()
        self.assertIn("static let showsMerchantChoice = false", welcome)
        # CLB-detail-42 (MP pages/club/detail header): a missing 主理人 / 城市 reads 待补充 on the live header
        # (App/ClubDetailView.swift ClubOverviewFacts on 概览, mp-club r3) through a catalog key; the old model grid stays gone.
        self.assertIn('pendingKey = "club.detail.factPending"', model)
        catalog = json.loads((ROOT / "Resources/Localizable.xcstrings").read_text())["strings"]
        self.assertEqual(catalog["club.detail.factPending"]["localizations"]["zh-Hans"]["stringUnit"]["value"], "待补充")
        self.assertIn("ClubDetailHeaderFact.pendingKey", (ROOT / "App/ClubDetailView.swift").read_text())
        self.assertNotIn("ClubDetailOverviewFactsGrid", model)

    def test_swift_tests_were_added_without_removing_existing_ones(self):
        tests = TESTS.read_text()
        names = re.findall(r"func (test\w+)", tests)
        self.assertGreaterEqual(len(names), 6)
        self.assertEqual(len(names), len(set(names)))
        self.assertIn("testUnknownMarkIsAnEmDashAndNotZero", names)
        self.assertTrue((ROOT / "Tests/CoreTests/ClubDetailTabTests.swift").is_file())
        self.assertTrue((ROOT / "Tests/CoreTests/ClubDetailEntryGateTests.swift").is_file())
        self.assertNotIn("http://", tests)
        self.assertNotIn("https://", tests)


if __name__ == "__main__":
    unittest.main()
