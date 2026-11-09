"""Contract guards for pages/template/index page-ready model work.

They do not compile Swift, run XCTest, or claim an Xcode Cloud result.
"""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EM = "\u2014"
MODEL = ROOT / "Core" / "TemplateBrowserPort.swift"
CONTRACT = ROOT / "Core" / "DiscoveryContracts.swift"
STRINGS = ROOT / "docs" / "release" / "ui-strings-pages-template-index.json"
CATALOG = ROOT / "Resources" / "Localizable.xcstrings"
FLAGS = (
    "showsMerchantChoice",
    "paymentEnabled",
    "payoutEnabled",
    "withdrawalEnabled",
    "virtualGoodsEnabled",
)


def text(path):
    return path.read_text(encoding="utf-8")


class PagesTemplateIndexPageReadyTests(unittest.TestCase):
    def test_model_states_and_existing_reads_stay_hidden_where_required(self):
        source = text(MODEL)
        self.assertIn(f'unknownDisplay = "{EM}"', source)
        for phase in ("loading", "empty", "error", "ready"):
            self.assertIn(f"case .{phase}", source)
        for flag in FLAGS:
            self.assertIn(f"public let {flag} = false", source)
            self.assertNotIn(f"{flag} = true", source)
        self.assertIn("public let topicTemplateUseHidden = true", source)
        self.assertNotIn("topic-template/use", source)
        self.assertNotIn("https://", source)
        self.assertNotIn("http://", source)
        self.assertNotIn("showsMerchantChoice = true", source)
        self.assertIn("service.topicTemplates()", source)
        self.assertIn("service.templateHome()", source)
        self.assertIn("service.playTemplates(", source)
        debug = source.split("#if DEBUG", 1)[1].split("#endif", 1)[0]
        self.assertIn("enum TemplateIndexFixtureData", debug)
        self.assertNotIn("https://", debug)
        lowered = source.lower()
        for banned in ("icp", "ugc", "support@", "beian"):
            self.assertNotIn(banned, lowered)

    def test_missing_chapter_is_not_treated_as_a_known_zero(self):
        contracts = text(CONTRACT)
        self.assertIn("public let chapterCountIncluded: Bool", contracts)
        self.assertIn("chapterCountIncluded = false", contracts)
        model = text(MODEL)
        self.assertIn("item.chapterCountIncluded && item.chapterCount >= 0", model)
        self.assertIn("TemplateIndexCount.unknownDisplay", model)

    def test_string_table_is_bilingual_and_named_for_accessibility(self):
        rows = json.loads(STRINGS.read_text(encoding="utf-8"))["entries"]
        self.assertGreaterEqual(len(rows), 8)
        catalog = json.loads(CATALOG.read_text(encoding="utf-8"))["strings"]
        seen = set()
        for row in rows:
            key = row["key"]
            self.assertTrue(row["en"] and row["zh-Hans"] and row["accessibilityIdentifier"], key)
            self.assertNotIn(key, seen)
            seen.add(key)
            if key in catalog:
                locs = catalog[key]["localizations"]
                self.assertEqual(locs["en"]["stringUnit"]["value"], row["en"], key)
                self.assertEqual(locs["zh-Hans"]["stringUnit"]["value"], row["zh-Hans"], key)
        unknown = next(row for row in rows if row["key"] == "pages.template.index.unknown")
        self.assertEqual(unknown["en"], EM)
        self.assertEqual(unknown["zh-Hans"], EM)
        self.assertEqual(unknown["accessibilityIdentifier"], "pages.template.index.unknown")
        for phase in ("loading", "empty", "error", "ready"):
            match = next(row for row in rows if row["key"] == f"pages.template.index.{phase}")
            self.assertEqual(match["accessibilityIdentifier"], f"pages.template.index.{phase}")


if __name__ == "__main__":
    unittest.main()
