"""CB203 page-ready contract for pages/deregister/index. No network and no Xcode."""
from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[2]
STRINGS = ROOT / "docs/release/ui-strings-pages-deregister-index.json"
MODEL = ROOT / "Core/DeregistrationStatusRules.swift"
ROUTES = ROOT / "Core/ChinaReviewedRouteCapability.swift"
EM = "\u2014"
FORBIDDEN = (
    "showsMerchantChoice = true",
    "paymentEnabled = true",
    "payoutEnabled = true",
    "withdrawalEnabled = true",
    "virtualGoodsEnabled = true",
)


class DeregisterIndexPageReadyContract(unittest.TestCase):
    def test_strings_cover_both_locales_and_accessibility_ids(self):
        payload = json.loads(STRINGS.read_text())
        self.assertEqual(payload["page"], "pages/deregister/index")
        self.assertEqual(payload["unknownNumber"], EM)
        states = payload["states"]
        self.assertEqual(set(states), {"loading", "empty", "error", "unknown"})
        self.assertEqual(states["unknown"]["number"], EM)
        self.assertEqual(states["unknown"]["accessibilityIdentifier"], "compliance.unknown")
        self.assertEqual(states["empty"]["accessibilityIdentifier"], "deregisterIndex.empty")
        self.assertEqual(states["loading"]["accessibilityIdentifier"], "compliance.loading")
        self.assertEqual(states["error"]["accessibilityIdentifier"], "compliance.error")
        rows = payload["strings"]
        self.assertGreaterEqual(len(rows), 8)
        keys = []
        for row in rows:
            self.assertEqual(set(row), {"key", "en", "zh-Hans", "accessibilityIdentifier"})
            self.assertTrue(row["key"])
            self.assertTrue(row["en"])
            self.assertTrue(row["zh-Hans"])
            self.assertTrue(row["accessibilityIdentifier"])
            self.assertNotIn("http://", row["en"] + row["zh-Hans"])
            self.assertNotIn("https://", row["en"] + row["zh-Hans"])
            self.assertNotIn("@", row["en"] + row["zh-Hans"])
            self.assertNotIn("ICP", row["en"] + row["zh-Hans"])
            keys.append(row["key"])
        self.assertEqual(len(keys), len(set(keys)))
        by_key = {row["key"]: row for row in rows}
        self.assertEqual(by_key["deregisterIndex.unknownNumber"]["en"], EM)
        self.assertEqual(by_key["deregisterIndex.unknownNumber"]["zh-Hans"], EM)
        self.assertEqual(by_key["deregisterIndex.empty"]["accessibilityIdentifier"], "deregisterIndex.empty")
        for state in states.values():
            self.assertIn(state["key"], by_key)

    def test_model_keeps_unknown_as_em_dash_and_hides_the_missing_result_route(self):
        source = MODEL.read_text()
        added = source.split("public enum DeregisterIndexReadPhase", 1)[1]
        for phase in ("case loading", "case empty", "case error(key: String)", "case unknown", "case ready"):
            self.assertIn(phase, added)
        self.assertIn('public static let unknownMark = "\u2014"', added)
        self.assertIn("if text.uppercased() == \"UNKNOWN\" { return unknownMark }", added)
        self.assertIn('if text == "0" { return "0" }', added)
        self.assertIn('let path = "/api/user/deregister/result"', added)
        self.assertNotIn("resultEndpoint", added)
        self.assertIn("#if DEBUG", source)
        self.assertIn("public enum DeregisterIndexFixtureData", source)
        self.assertLess(source.index("#if DEBUG"), source.index("public enum DeregisterIndexFixtureData"))
        for flag in FORBIDDEN:
            self.assertNotIn(flag, added)
        routes = ROUTES.read_text()
        self.assertNotIn('"/api/user/deregister/result"', routes)
        self.assertIn('"/api/user/deregister/status"', routes)

    def test_existing_status_rules_tests_remain(self):
        tests = (ROOT / "Tests/CoreTests/DeregistrationStatusRulesTests.swift").read_text()
        for name in (
            "testEligibleWithoutBlockersDefaultsToSMSWhenMethodAbsent",
            "testUnknownOrMalformedMethodIsNeverUsable",
            "testCoolingOffClockTreatsMissingOrUnparseableAsNotPassed",
            "testUnknownQuantityIsEmDashNeverZero",
            "testDeregisterIndexPagePhasesDoNotInventNumbers",
        ):
            self.assertIn(f"func {name}()", tests)
        compliance = (ROOT / "Tests/CoreTests/AccountComplianceTests.swift").read_text()
        self.assertIn("func testDeregisterUsesMultipartAndSameEpochCannotCancel()", compliance)
        self.assertIn("func testDeregisterIndexPageReadsExistingStatusAndKeepsUnknownAsEmDash()", compliance)
