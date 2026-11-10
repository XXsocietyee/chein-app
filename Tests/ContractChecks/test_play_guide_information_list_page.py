"""Source contract for the play-guide list page model. Does not compile Swift."""
from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODEL = ROOT / "Core/ProfileGuideRead.swift"
STRINGS = ROOT / "docs/release/ui-strings-subpackageA-pages-infomation-infomation.json"
DASH = "\u2014"


class PlayGuideInformationListPageContract(unittest.TestCase):
    def setUp(self):
        self.source = MODEL.read_text()
        self.catalog = json.loads(STRINGS.read_text())

    def test_model_keeps_four_states_and_the_existing_list_path(self):
        for token in ("case loading", "case empty", "case error", "case unknown", "case ready"):
            self.assertIn(token, self.source)
        self.assertIn("static let listPath = ProfileGuideReadRoute.listPath", self.source)
        self.assertIn("static let routeMarkedLive = false", self.source)
        self.assertEqual(self.source.count("api/common/infomation_list"), 1)
        self.assertIn('unknownMark = "\\u{2014}"', self.source)
        self.assertNotIn("documentCount: .value(usable.count)", self.source)
        self.assertNotIn("documentCount: .value(rows.count)", self.source)

    def test_closed_flags_and_routes_are_not_introduced(self):
        for forbidden in (
            "showsMerchantChoice",
            "paymentEnabled",
            "payoutEnabled",
            "withdrawalEnabled",
            "virtualGoodsEnabled",
            "infomation_delete",
            "https://",
        ):
            self.assertNotIn(forbidden, self.source)

    def test_strings_have_both_languages_and_accessibility_identifiers(self):
        strings = self.catalog["strings"]
        self.assertGreater(len(strings), 0)
        keys = []
        for item in strings:
            self.assertTrue(item["en"])
            self.assertTrue(item["zh-Hans"])
            self.assertNotIn("http://", item["en"])
            self.assertNotIn("http://", item["zh-Hans"])
            keys.append(item["key"])
        self.assertEqual(len(keys), len(set(keys)))
        unknown = next(item for item in strings if item["key"] == "playGuide.list.count.unknown")
        self.assertEqual(unknown["en"], DASH)
        self.assertEqual(unknown["zh-Hans"], DASH)
        self.assertNotEqual(unknown["en"], "0")
        identifiers = self.catalog["accessibilityIdentifiers"]
        for identifier in (
            "social.guide",
            "social.guide.docsEmpty",
            "social.guide.documentCount",
            "social.information.{id}",
            "social.issue",
        ):
            self.assertIn(identifier, identifiers)
        self.assertTrue(any(item.get("accessibilityIdentifier") for item in strings))


if __name__ == "__main__":
    unittest.main()
