"""Page-ready contract for pages/publish/activity/index.

Checks the readiness model, the debug fixture, and the EN/zh-Hans string file.
Does not compile Swift, run xcodebuild, or claim an Xcode Cloud result.
"""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SWIFT = ROOT / "Core/ActivityPublishingWizard.swift"
STRINGS = ROOT / "docs/release/ui-strings-pages-publish-activity-index.json"
EM = "—"


def readiness_source():
    text = SWIFT.read_text()
    start = text.index("public enum ActivityPublishingPageReadiness")
    return text[start:]


class ActivityPublishingPageReadinessContract(unittest.TestCase):
    def test_model_keeps_four_states_and_hides_missing_routes(self):
        source = readiness_source()
        for token in ["case loading", "case empty", "case error", "case unknown", 'unknownDisplay = "—"']:
            self.assertIn(token, source)
        for name in ["showsMerchantChoice", "paymentEnabled", "payoutEnabled", "withdrawalEnabled", "virtualGoodsEnabled"]:
            self.assertIn(f"var {name}: Bool {{ false }}", source)
            self.assertNotIn(f"{name} = true", source)
            self.assertNotIn(f"var {name}: Bool {{ true }}", source)
        self.assertIn("createRequestRecoveryOffered: Bool { false }", source)
        self.assertNotIn("api/activity/publish", SWIFT.read_text())
        self.assertNotIn(".liveInProduction =", source)
        self.assertIn("#if DEBUG", source)
        self.assertLess(source.index("#if DEBUG"), source.index("enum ActivityPublishingFixtureData"))
        self.assertIn("#endif", source)
        self.assertNotIn("https://", source)
        self.assertNotIn("sk-", source)

    def test_string_file_has_english_chinese_and_accessibility_ids(self):
        document = json.loads(STRINGS.read_text())
        self.assertEqual(document["page"], "pages/publish/activity/index")
        self.assertGreaterEqual(len(document["strings"]), 40)
        for key, value in document["strings"].items():
            self.assertIn("en", value, key)
            self.assertIn("zh-Hans", value, key)
            self.assertTrue(value["en"].strip(), key)
            self.assertTrue(value["zh-Hans"].strip(), key)
        self.assertEqual(document["strings"]["activityPublishing.count.unknown"]["en"], EM)
        self.assertEqual(document["strings"]["activityPublishing.count.unknown"]["zh-Hans"], EM)
        self.assertEqual(document["strings"]["activityPublishing.count.zero"]["en"], "0")
        identifiers = document["accessibilityIdentifiers"]
        self.assertGreaterEqual(len(identifiers), 12)
        ids = []
        for item in identifiers:
            self.assertIn("id", item)
            self.assertIn("en", item)
            self.assertIn("zh-Hans", item)
            self.assertTrue(item["id"].strip())
            self.assertTrue(item["en"].strip())
            self.assertTrue(item["zh-Hans"].strip())
            ids.append(item["id"])
        self.assertEqual(len(ids), len(set(ids)))
        for required in [
            "publishModes.activity.wizard.heading",
            "publishModes.activity.review",
            "publishModes.activity.result",
            "publishModes.activity.wizard.validation",
        ]:
            self.assertIn(required, ids)


if __name__ == "__main__":
    unittest.main()
