"""Shipped China player writes stay off the money, merchant, and password routes."""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class PlayerWriteGrantContracts(unittest.TestCase):
    def test_admission_is_the_approved_player_set(self):
        source = (ROOT / "App/AppCompositionRoot.swift").read_text()
        start = source.index("private enum PlayerWriteAdmission")
        block = source[start:source.index("private enum ChapterWriteExit")]
        for path in [
            "api/im/send", "api/im/read", "api/im/mute", "api/im/delete", "api/im/report", "api/im/block",
            "api/im/start", "api/creativesquare/action", "api/creativesquare/like", "api/creativesquare/bookmark",
            "api/comment/add", "api/comment/delete", "api/comment/like", "api/club/join", "api/club/quit",
            "api/club/post/delete", "api/user/update", "api/user/follow/action",
            "api/registration/create", "api/registration/cancel", "api/team/create", "api/team/join", "api/team/quit",
            "api/roam/checkin", "api/roam/finish", "api/roam/stamp/exchange", "api/play/answer", "api/play/arrive",
            "api/play/advanced/start", "api/topic/create", "api/capsules/create", "api/compliance/consents",
            "api/exploration-goals/create", "api/verify/dyncode/issue",
        ]:
            self.assertIn('"' + path + '"', block)
        for pattern in [
            "/api/city/nodes/{}/favorite", "/api/official/events/{}/arrivals",
            "/api/play/preference/{}", "/api/play/orient/session/task/{}/result",
        ]:
            self.assertIn('"' + pattern + '"', block)
        for banned in [
            "api/registration/pay", "api/registration/cancel-refund", "api/withdrawal/create",
            "api/login", "api/merchant/", "api/club/settlement/withdraw", "api/mod-commerce",
            "api/team/command", "api/club/apply", "api/play/help", "api/audit/appeal",
        ]:
            self.assertNotIn(banned, block)
        self.assertIn("ReleaseMoneyWriteSwitch.blocks", block)
        self.assertIn('object["payChannel"] == nil', block)
        self.assertIn("freeRegistrationBody", block)
        catalog = source[source.index("struct PlayerWriteCatalog"):source.index("private enum PlayerWriteAdmission")]
        for name in ["im", "square", "club-community", "club-join", "profile", "registration", "team", "roam", "play", "consent"]:
            self.assertIn('name: "' + name + '"', catalog)
        self.assertIn("clubCommunityWriteService", source)
        self.assertNotIn("reviewedInjection", (ROOT / "App/AppSession.swift").read_text())
        coordinator = (ROOT / "Core/RegistrationCoordinator.swift").read_text()
        self.assertIn("quote.payAmount == .zero", coordinator)
        self.assertIn("usesAppPaymentChannel: false", coordinator)
        self.assertIn("case paymentRequired", coordinator)
        launch = (ROOT / "App/RegionalLaunchConfiguration.swift").read_text()
        reviewed = launch.split("static func reviewedDeployment", 1)[1].split("static func reviewedComposition", 1)[0]
        market = launch.split("static func reviewedMarketDeployment", 1)[1].split("static func reviewedMarketComposition", 1)[0]
        self.assertIn("playerWritesEnabled: true", reviewed)
        self.assertNotIn("playerWritesEnabled: true", market)
        self.assertIn("productionGatesEnabled: false", market)


if __name__ == "__main__":
    unittest.main()
