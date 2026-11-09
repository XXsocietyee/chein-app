"""Contract guards for pages/template/index page-ready model work.

They do not compile Swift, run XCTest, or claim an Xcode Cloud result.
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EM = "\u2014"
MODEL = ROOT / "Core" / "TemplateBrowserPort.swift"
CONTRACT = ROOT / "Core" / "DiscoveryContracts.swift"
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

    def test_model_names_phase_accessibility_and_unknown(self):
        source = text(MODEL)
        self.assertIn(f'unknownDisplay = "{EM}"', source)
        self.assertIn('unknownAccessibilityIdentifier = "pages.template.index.unknown"', source)
        for phase in ("loading", "empty", "error", "ready"):
            self.assertIn(f'return "pages.template.index.{phase}"', source)


if __name__ == "__main__":
    unittest.main()
