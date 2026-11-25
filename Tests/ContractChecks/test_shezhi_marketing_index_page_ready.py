"""CB278 page-ready contract for pages/shezhi/marketing/index. No network and no Xcode."""
from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[2]
NOTE = ROOT / "docs/release/page-ready/pages-shezhi-marketing-index.md"
MODEL = ROOT / "Core/MerchantMarketingConsentOriginal.swift"
ROUTES = ROOT / "Core/ChinaReviewedRouteCapability.swift"
JOURNEY = ROOT / "Tests/CoreTests/MarketingOriginalSettingsJourneyTests.swift"
EM = "\u2014"
FORBIDDEN = (
    "showsMerchantChoice = true",
    "paymentEnabled = true",
    "payoutEnabled = true",
    "withdrawalEnabled = true",
    "virtualGoodsEnabled = true",
    "nsPrivacyTracking = true",
)
PRESENT_KEYS = (
    "compliance.loading",
    "compliance.marketing.empty",
    "compliance.marketing.unknown",
    "compliance.channel.IN_APP",
    "compliance.channel.COUPON",
    "marketingOriginal.current.unconfirmed",
    "marketingOriginal.outcome.unknown",
)
IDENTIFIER_ONLY = (
    "compliance.marketing.refresh",
    "compliance.marketing.confirm",
    "compliance.error",
)


def catalogs():
    names = (
        "Localizable.xcstrings",
        "AccountCompliance.xcstrings",
        "MarketingConsentOriginalPresentation.xcstrings",
    )
    keys = set()
    for name in names:
        payload = json.loads((ROOT / "Resources" / name).read_text())
        keys |= set(payload["strings"])
    return keys


class ShezhiMarketingIndexPageReadyContract(unittest.TestCase):
    def test_model_keeps_unknown_as_em_dash_and_hides_the_unlisted_result_route(self):
        source = MODEL.read_text()
        added = source.split("public enum ShezhiMarketingIndexReadPhase", 1)[1]
        for phase in ("case loading", "case empty", "case error(key: String)", "case unknown", "case ready"):
            self.assertIn(phase, added)
        self.assertIn('public static let unknownMark = "\u2014"', added)
        self.assertIn('if text == "0" { return "0" }', added)
        self.assertIn('public static let listPath = "/api/merchant/crm/marketing-consents"', added)
        self.assertIn('public static let resultPath = "/api/merchant/crm/marketing-consents/result"', added)
        # pages/shezhi/components/marketing-consent/index.js:33 uses this list path.
        # `nonisolated` only marks the Swift static; the path string is the same.
        self.assertIn("public nonisolated static let path=\"api/merchant/crm/marketing-consents\"", source)
        self.assertNotIn("resultEndpoint", added)
        self.assertIn("does not load or write marketing consent", added)
        for flag in FORBIDDEN:
            self.assertNotIn(flag, added)
        routes = ROUTES.read_text()
        self.assertIn('"/api/merchant/crm/marketing-consents": .liveInProduction', routes)
        self.assertNotIn('"/api/merchant/crm/marketing-consents/result": .liveInProduction', routes)
        self.assertIn("public static let paymentEnabled = false", routes)
        self.assertIn("public static let virtualGoodsEnabled = false", routes)

    def test_note_lists_missing_keys_and_existing_copy_stays_bilingual(self):
        note = NOTE.read_text()
        self.assertIn("Missing catalog keys: none.", note)
        self.assertIn(EM, note)
        self.assertIn("pages/shezhi/marketing/index", note)
        keys = catalogs()
        for key in PRESENT_KEYS:
            self.assertIn(key, keys)
            self.assertIn(key, note)
        for ident in IDENTIFIER_ONLY:
            self.assertNotIn(ident, keys)
            self.assertIn(ident, note)

    def test_existing_marketing_journey_tests_remain(self):
        tests = JOURNEY.read_text()
        for name in (
            "testExplicitConfirmationUsesSameUUIDFromDurableIntentThroughBothResultReads",
            "testMatchingCurrentWithoutOriginalReceiptNeverResolvesUnknown",
            "testLostPostRetainsOriginalAcrossJournalRecreationAndFreshEpochGETOnlyRecovery",
            "testShezhiMarketingIndexPageReadsLoadedStateWithoutAnotherRequest",
            "testUnknownQuantityIsEmDashNeverZero",
            "testPhasesKeepUnknownCountsAsEmDashAndLoadedEmptyAsZero",
            "testReceiptUnknownIdentifiersStayEmDashAndLiteralZeroRequestIdStays",
            "testListRouteStaysTheExistingLiveContractAndResultStaysUnmarked",
        ):
            self.assertIn(f"func {name}()", tests)
