"""PAGE-READY source contract for pages/club/notify/index. Does not run Swift or Xcode."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def text(path):
    return (ROOT / path).read_text()


class ClubNotifyPageReady(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core = text("Core/ClubOpsNotifyPresentation.swift")
        cls.tests = text("Tests/CoreTests/ClubNotifyPageTests.swift")
        cls.contracts = text("Core/ClubGovernanceContracts.swift")
        cls.commands = text("Core/ClubGovernanceCommands.swift")
        cls.welcome = text("App/WelcomeView.swift")
        cls.search = text("App/HomeSearchTabParityViews.swift")
        cls.money = text("Core/ChinaReviewedRouteCapability.swift")

    def test_page_uses_existing_routes_and_stays_off_player_entry(self):
        self.assertEqual(self.core.count("public static let includedInPlayerFirstEntry = false"), 2)
        self.assertEqual(self.core.count("public static let routeMarkedLive = false"), 2)
        self.assertEqual(self.core.count("public static let sendMarkedLive = false"), 2)
        self.assertEqual(self.core.count("public static let retryMarkedLive = false"), 2)
        self.assertIn("public static let readOperation = ClubGovernanceRead.audienceCounts", self.core)
        self.assertIn("public static let readOperation = ClubGovernanceRead.notificationStatus", self.core)
        self.assertIn("public static let broadcastSend = ClubGovernanceMutation.sendNotification", self.core)
        self.assertIn("public static let broadcastRetry = ClubGovernanceMutation.retryNotification", self.core)
        self.assertIn('case .audienceCounts: return "api/club/event-notification/audience-counts"', self.contracts)
        self.assertIn('case .notificationStatus: return "api/club/event-notification/status"', self.contracts)
        self.assertIn('case .sendNotification: return "api/club/event-notification/send"', self.commands)
        self.assertIn('case .retryNotification: return "api/club/event-notification/retry"', self.commands)
        self.assertNotIn("api/club/notices", self.core)
        self.assertNotIn("ClubNotifyPage", self.welcome)
        self.assertNotIn("event-notification", self.welcome)
        self.assertNotIn("pages/club/notify", self.welcome)
        self.assertNotIn("ClubNotifyPage", self.search)
        self.assertNotIn("pages/club/notify", self.search)
        self.assertIn("static let showsMerchantChoice = false", self.welcome)
        for name in ("paymentEnabled", "payoutEnabled", "withdrawalEnabled", "virtualGoodsEnabled"):
            self.assertIn("public static var %s: Bool { testDerivation?" % name, self.money)

    def test_unknown_counts_are_an_em_dash_and_broadcast_stays_gated(self):
        self.assertIn('public static let unknownDisplay = "\u2014"', self.core)
        self.assertIn("case .null: return 0", self.core)
        self.assertIn("A missing or non-integer input stays unknown. It is not treated as 0.", self.core)
        self.assertIn('permissions?.allows(ClubGovernanceRead.audienceCounts.permission, scope: scope) == true', self.core)
        self.assertIn('permissions?.allows("club:event:operate", scope: scope) == true', self.core)
        self.assertIn("guard capability.canRead else { return .loading(clientCapabilityPresent: false) }", self.core)
        for forbidden in ("URLSession", "transport", "UserDefaults", "https://", "chengyinhub.com"):
            self.assertNotIn(forbidden, self.core)
        for name in (
            "testNotifyPageStaysHiddenWithoutTheBroadcastGrant",
            "testAudienceLoadingEmptyReadyAndLiteralZero",
            "testUnknownAudienceCountsAreEmDashNeverZero",
            "testDeliveryUnknownIsEmDashWhileLiteralZeroStaysZero",
            "testLoadUsesTheExistingReadsAndDoesNotSend",
        ):
            self.assertIn("func " + name, self.tests)
        self.assertIn("XCTAssertEqual(access.sends, 0)", self.tests)
        self.assertIn("XCTAssertTrue(counts.sent.isEmpty)", self.tests)
        self.assertIn("XCTAssertEqual(legacy.totalCount, 0)", self.tests)


if __name__ == "__main__":
    unittest.main()
