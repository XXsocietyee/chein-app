"""Contract for pages/privacy/index non-view page-ready artifacts. No network and no Xcode."""
import json
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
POLICY = ROOT / "Core/UsageConsentPolicy.swift"
STRINGS = ROOT / "docs/release/ui-strings-pages-privacy-index.json"
ROUTES = ROOT / "Core/ChinaReviewedRouteCapability.swift"
VIEW = ROOT / "App/PrivacyProtectionView.swift"

FORBIDDEN_TRUE = (
    "showsMerchantChoice = true",
    "paymentEnabled = true",
    "payoutEnabled = true",
    "withdrawalEnabled = true",
    "virtualGoodsEnabled = true",
)


def policy_text():
    return POLICY.read_text(encoding="utf-8")


class PagesPrivacyIndexPageReadyTests(unittest.TestCase):
    def test_strings_are_bilingual_and_match_accessibility_constants(self):
        document = json.loads(STRINGS.read_text(encoding="utf-8"))
        self.assertEqual(document["page"], "pages/privacy/index")
        self.assertEqual(document["screen"], "App/PrivacyProtectionView.swift")
        rows = document["strings"]
        self.assertGreaterEqual(len(rows), 20)
        identifiers = []
        for row in rows:
            self.assertTrue(row["en"])
            self.assertTrue(row["zh-Hans"])
            self.assertNotEqual(row["en"], "0")
            identifiers.append(row["accessibilityIdentifier"])
        self.assertEqual(len(identifiers), len(set(identifiers)))
        unknown = next(row for row in rows if row["key"] == "privacy.page.state.unknown")
        self.assertEqual(unknown["en"], "\u2014")
        self.assertEqual(unknown["zh-Hans"], "\u2014")
        self.assertEqual(unknown["accessibilityIdentifier"], "privacy.page.state.unknown")
        declared = set(re.findall(
            r'public static let \w+ = "([^"]+)"',
            policy_text().split("public enum PrivacyProtectionPageAccessibility", 1)[1].split("}", 1)[0],
        ))
        self.assertEqual(set(identifiers), declared)

    def test_model_has_states_and_does_not_invent_a_live_route(self):
        source = policy_text()
        for state in ("case loading", "case empty", "case error", "case unknown", "case ready"):
            self.assertIn(state, source)
        self.assertIn('public static let unknownDisplay = "\u2014"', source)
        self.assertIn("String(value) == trimmed", source)
        self.assertNotIn("?? 0", source)
        self.assertNotIn("HTTPTransport", source)
        self.assertIn("public static let liveRecordingApproved = false", source)
        self.assertNotIn("https://", source)
        for forbidden in FORBIDDEN_TRUE:
            self.assertNotIn(forbidden, source)
        start = source.index("#if DEBUG")
        end = source.index("#endif", start)
        block = source[start:end]
        self.assertIn("public enum PrivacyProtectionPageFixtureData", block)
        self.assertNotIn("public enum PrivacyProtectionPageFixtureData", source[end:])
        routes = ROUTES.read_text(encoding="utf-8")
        self.assertIn('"/api/compliance/usage-records": .missing', routes)
        self.assertNotIn('"/api/compliance/usage-records": .liveInProduction', routes)
        for name in ("paymentEnabled", "payoutEnabled", "withdrawalEnabled", "virtualGoodsEnabled"):
            self.assertIn(f"public static let {name} = false", routes)
        welcome = (ROOT / "App/WelcomeView.swift").read_text(encoding="utf-8")
        self.assertIn("static let showsMerchantChoice = false", welcome)

    def test_existing_view_identifiers_stay_in_the_catalog(self):
        view = VIEW.read_text(encoding="utf-8")
        catalog = json.loads(STRINGS.read_text(encoding="utf-8"))
        identifiers = {row["accessibilityIdentifier"] for row in catalog["strings"]}
        for identifier in re.findall(r'\.accessibilityIdentifier\("([^"]+)"\)', view):
            self.assertIn(identifier, identifiers)
        self.assertNotIn("URLRequest", view)
        self.assertNotIn("/api/", view)


if __name__ == "__main__":
    unittest.main()
