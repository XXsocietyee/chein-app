"""CB203 page-ready contract for pages/deregister/index. No network and no Xcode."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
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
    def test_model_names_state_keys_and_unknown_mark(self):
        added = MODEL.read_text().split("public enum DeregisterIndexReadPhase", 1)[1]
        for phase in ("case loading", "case empty", "case error(key: String)", "case unknown", "case ready"):
            self.assertIn(phase, added)
        self.assertIn(f'public static let unknownMark = "{EM}"', added)
        self.assertNotEqual(EM, "0")
        for key in ("deregisterIndex.empty", "compliance.loading", "compliance.unknown", "compliance.failed"):
            self.assertIn(f'"{key}"', added)
        self.assertNotIn("http://", added)
        self.assertNotIn("https://", added)

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
        self.assertNotIn('"/api/user/deregister/result": .liveInProduction', routes)
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
