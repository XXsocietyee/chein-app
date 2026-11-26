"""Contract for pages/privacy/index non-view page-ready artifacts. No network and no Xcode."""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
POLICY = ROOT / "Core/UsageConsentPolicy.swift"
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
    def test_accessibility_constants_name_states_and_unknown(self):
        declared = re.findall(
            r'public static let \w+ = "([^"]+)"',
            policy_text().split("public enum PrivacyProtectionPageAccessibility", 1)[1].split("}", 1)[0],
        )
        self.assertGreaterEqual(len(declared), 20)
        self.assertEqual(len(declared), len(set(declared)))
        for identifier in (
            "privacy.page.state.loading",
            "privacy.page.state.empty",
            "privacy.page.state.error",
            "privacy.page.state.unknown",
            "privacy.page.state.ready",
        ):
            self.assertIn(identifier, declared)
        self.assertIn('public static let unknownDisplay = "\u2014"', policy_text())
        self.assertNotEqual("\u2014", "0")

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
        self.assertIn('"/api/compliance/usage-records": .liveInProduction', routes)
        self.assertNotIn('"/api/compliance/usage-records": .missing', routes)
        for name in ("paymentEnabled", "payoutEnabled", "withdrawalEnabled", "virtualGoodsEnabled"):
            self.assertIn(f"public static var {name}: Bool {{ testDerivation?", routes)
        welcome = (ROOT / "App/WelcomeView.swift").read_text(encoding="utf-8")
        self.assertIn("static let showsMerchantChoice = false", welcome)

    def test_existing_view_identifiers_stay_on_the_model(self):
        view = VIEW.read_text(encoding="utf-8")
        declared = set(re.findall(
            r'public static let \w+ = "([^"]+)"',
            policy_text().split("public enum PrivacyProtectionPageAccessibility", 1)[1].split("}", 1)[0],
        ))
        found = re.findall(r'\.accessibilityIdentifier\("([^"]+)"\)', view)
        self.assertGreaterEqual(len(found), 1)
        for identifier in found:
            self.assertIn(identifier, declared)
        self.assertNotIn("URLRequest", view)
        self.assertNotIn("/api/", view)


if __name__ == "__main__":
    unittest.main()
