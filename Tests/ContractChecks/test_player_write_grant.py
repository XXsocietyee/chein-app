"""Shipped China player writes live on the reviewed leases, not a parallel allow-list."""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class PlayerWriteGrantContracts(unittest.TestCase):
    def test_writers_are_inside_the_reviewed_gate(self):
        source = (ROOT / "App/AppCompositionRoot.swift").read_text()
        leases = (ROOT / "App/ReviewedPlayerWriteLeases.swift").read_text()
        self.assertNotIn("PlayerWriteAdmission", source)
        self.assertNotIn("PlayerWriteCatalog", source)
        self.assertNotIn("playerWriteCatalog", source)
        self.assertNotIn("PlayerWriteAdmission", leases)
        paths = leases.split("// player-write-paths-begin", 1)[1].split("// player-write-paths-end", 1)[0]
        for path in [
            "api/im/send", "api/im/send-receipt", "api/club/post/create", "api/club/post/delete",
            "api/club/post/like", "api/club/post/report", "api/club/post/comment/create",
            "api/club/post/comment/delete", "api/club/post/repost", "api/v1/community/posts",
            "api/v1/community/guidelines/ack", "api/v1/community/media/register", "api/v1/community/drafts",
            "api/v1/community/reports", "api/v1/community/appeals", "api/user/update", "api/common/uploadOSS",
            "api/registration/create", "api/team/command", "api/team/command/query", "api/team/command/cancel",
            "api/play/arrive", "api/play/answer", "api/play/checkin", "api/play/photo", "api/play/sensor-result",
            "api/play/puzzle/reveal", "api/play/help", "api/play/advanced/start", "api/play/advanced/action",
            "api/topic/chapter/finish", "api/play/run-session/save", "api/play/journey/opening/complete",
            "api/play/orient/session", "api/play/scan-entry", "api/roam/checkin", "api/roam/stamp/exchange",
            "api/city/nodes/{}/favorite", "api/topic/like",
            "api/orient/scoring/appeal", "api/orient/scoring/dispute",
        ]:
            self.assertIn('"' + path + '"', paths)
        for banned in [
            "api/registration/pay", "api/registration/cancel-refund", "api/withdrawal/create",
            "api/login", "api/merchant/", "api/club/settlement/withdraw", "api/mod-commerce",
            "api/roam/presence", "api/club/roles/assign", "api/club/roles/revoke",
            "api/orient/scoring/session/{}/sync", "api/orient/scoring/session/{}/settle",
            "/purchase", "/payout",
        ]:
            # h-ugc: "api/merchant/reviews/report" is a player reporting a review, not a merchant write.
            self.assertNotIn(banned, paths.replace('"api/merchant/reviews/report"', ""))
        route = leases.split("func acceptsPlayerWrite", 1)[1].split("@MainActor final class ReviewedProductionGateLeases", 1)[0]
        self.assertIn("ReleaseMoneyWriteSwitch.blocks", route)
        # fix/1128-cn-pay P0-1: paid creates are admitted with payChannel=APP only while the payment switch is on.
        self.assertIn("registrationCreateBody(request, paymentsOpen: ReleaseMoneyWriteSwitch.paymentEnabled)", route)
        self.assertIn('return paymentsOpen && (channel as? String) == "APP"', route)
        self.assertIn("stableCommunityRequestID", route)
        self.assertIn("api/roam/presence", route)
        self.assertIn("api/club/roles/", route)
        self.assertIn("playerWriters", source)
        self.assertIn("clubCommunityWriteService", source)
        self.assertNotIn("reviewedInjection", (ROOT / "App/AppSession.swift").read_text())
        coordinator = (ROOT / "Core/RegistrationCoordinator.swift").read_text()
        # fix/1128-cn-pay P0-1: a paid quote is blocked only while payments are closed; paid creates send APP.
        self.assertIn("amount > .zero, !paymentsOpen() { return .blocked(.paymentRequired) }", coordinator)
        self.assertIn("usesAppPaymentChannel: Self.sendsAppPaymentChannel(quote: quote, participant: participant)", coordinator)
        self.assertIn("case paymentRequired", coordinator)
        team = (ROOT / "Core/TeamHTTPService.swift").read_text()
        self.assertIn("savedRequestIDs[key] = nil", team)
        self.assertIn("return .unknown", team)
        launch = (ROOT / "App/RegionalLaunchConfiguration.swift").read_text()
        reviewed = launch.split("static func reviewedDeployment", 1)[1].split("static func reviewedComposition", 1)[0]
        market = launch.split("static func reviewedMarketDeployment", 1)[1].split("static func reviewedMarketComposition", 1)[0]
        self.assertIn("playerWritesEnabled: true", reviewed)
        self.assertNotIn("playerWritesEnabled: true", market)
        self.assertIn("productionGatesEnabled: false", market)


if __name__ == "__main__":
    unittest.main()
