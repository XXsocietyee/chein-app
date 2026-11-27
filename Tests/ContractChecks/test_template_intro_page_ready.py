#!/usr/bin/env python3
"""Page-ready checks for pages/publish/template-intro/index. Source only."""
from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[2]
STRINGS = ROOT / "docs/release/ui-strings-pages-publish-template-intro-index.json"
MODEL = ROOT / "Core/TemplateAuthoringIntroExamples.swift"
FIXTURE = ROOT / "Core/TemplateAuthoringSyntheticFixtures.swift"
PRIOR = ROOT / "Tests/CoreTests/TemplateAuthoringIntroExamplesTests.swift"


class TemplateIntroPageReadyContract(unittest.TestCase):
    def test_strings_have_en_and_zh_hans_and_identifiers(self):
        catalog = json.loads(STRINGS.read_text())
        self.assertEqual(catalog["page"], "pages/publish/template-intro/index")
        self.assertGreaterEqual(len(catalog["strings"]), 12)
        # mp-r3-publish: the MP intro shows covers only (no category caption), so the retired
        # `creatorIntro.example.category.{index}` left the catalog; four identifiers remain.
        self.assertGreaterEqual(len(catalog["accessibilityIdentifiers"]), 4)
        for key, entry in catalog["strings"].items():
            self.assertEqual(set(entry), {"en", "zh-Hans"}, key)
            self.assertTrue(entry["en"] and entry["zh-Hans"], key)
            blob = entry["en"] + entry["zh-Hans"]
            self.assertNotIn("http://", blob)
            self.assertNotIn("https://", blob)
            self.assertNotIn("ICP", blob)
        self.assertEqual(catalog["strings"]["templateIntro.count.unknown"], {"en": "—", "zh-Hans": "—"})
        identifiers = {item["id"] for item in catalog["accessibilityIdentifiers"]}
        for item in (
            "templateAuthor.begin",
            "publishParity.intro.value",
            "creatorIntro.retry",
            "creatorIntro.example.{index}",
        ):
            self.assertIn(item, identifiers)
        self.assertNotIn("creatorIntro.example.category.{index}", identifiers)
        for item in catalog["accessibilityIdentifiers"]:
            self.assertEqual(item["locales"], ["en", "zh-Hans"])

    def test_model_states_and_fixture_stay_debug_only(self):
        source = MODEL.read_text()
        self.assertIn("case loading, empty, error, ready", source)
        self.assertIn('unknownText = "—"', source)
        self.assertNotIn("?? 0", source)
        self.assertNotIn(".value(0)", source)
        for name in (
            "showsMerchantChoice",
            "paymentEnabled",
            "payoutEnabled",
            "withdrawalEnabled",
            "virtualGoodsEnabled",
        ):
            self.assertNotIn(name, source)
        self.assertNotIn("/api/", source)
        fixture = FIXTURE.read_text()
        self.assertTrue(fixture.startswith("#if DEBUG\n"))
        self.assertTrue(fixture.rstrip().endswith("#endif"))
        self.assertLess(fixture.index("#if DEBUG"), fixture.index("enum TemplateAuthoringIntroFixtureData"))
        self.assertLess(fixture.index("enum TemplateAuthoringIntroFixtureData"), fixture.rindex("#endif"))
        self.assertEqual(PRIOR.read_text().count("func test"), 9)


if __name__ == "__main__":
    unittest.main()
