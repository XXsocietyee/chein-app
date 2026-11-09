"""Contract for pages/index/index copy and accessibility identifiers."""
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
STRINGS = ROOT / "docs/release/ui-strings-pages-index-index.json"
CONTRACTS = ROOT / "Core/HomeFeedContracts.swift"
FIXTURE = ROOT / "Core/HomeFeedSyntheticFixtures.swift"
UNKNOWN = "—"


class PagesIndexIndexStrings(unittest.TestCase):
    def setUp(self):
        self.doc = json.loads(STRINGS.read_text())

    def test_catalog_names_the_home_feed_and_both_languages(self):
        self.assertEqual(self.doc["page"], "pages/index/index")
        self.assertEqual(self.doc["title"], {"en": "Home", "zh-Hans": "首页"})
        self.assertGreaterEqual(len(self.doc["strings"]), 1)
        self.assertGreaterEqual(len(self.doc["accessibilityIdentifiers"]), 1)
        for group in (self.doc["strings"], self.doc["accessibilityIdentifiers"]):
            for key, value in group.items():
                self.assertEqual(set(value), {"en", "zh-Hans"}, key)
                self.assertTrue(value["en"].strip(), key)
                self.assertTrue(value["zh-Hans"].strip(), key)
                self.assertNotIn("http://", value["en"] + value["zh-Hans"])
                self.assertNotIn("https://", value["en"] + value["zh-Hans"])

    def test_unknown_is_an_em_dash_in_the_catalog_and_the_model(self):
        unknown = self.doc["strings"]["homeFeed.unknown"]
        self.assertEqual(unknown, {"en": UNKNOWN, "zh-Hans": UNKNOWN})
        self.assertEqual(self.doc["accessibilityIdentifiers"]["homeFeed.unknown"], unknown)
        self.assertNotEqual(UNKNOWN, "0")
        self.assertNotEqual(UNKNOWN, "-")
        source = CONTRACTS.read_text()
        self.assertIn(f'public static let unknownText = "{UNKNOWN}"', source)
        for state in ("loading", "empty", "error", "unknown", "ready"):
            self.assertIn(f"case {state}", source)
        for key in ("homeFeed.loading", "homeFeed.empty", "homeFeed.loadError", "homeIndex.loading", "homeIndex.empty", "homeIndex.error"):
            self.assertIn(key, self.doc["strings"])
        for identifier in (
            "homeFeed.empty",
            "homeFeed.loadMore",
            "homeFeed.configurationUnavailable",
            "homeIndex.state.loading",
            "homeIndex.state.empty",
            "homeIndex.state.error",
            "homeIndex.state.retry",
        ):
            self.assertIn(identifier, self.doc["accessibilityIdentifiers"])

    def test_fixture_data_stays_debug_only_and_omits_a_price(self):
        source = FIXTURE.read_text()
        self.assertTrue(source.startswith("#if DEBUG"))
        self.assertIn("public enum HomeFeedFixtureData", source)
        self.assertIn("missingFactsActivity", source)
        self.assertNotIn("minAmout", source.split("missingFactsActivity", 1)[1])
        self.assertTrue(source.rstrip().endswith("#endif"))


if __name__ == "__main__":
    unittest.main()
