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
            "api/creativesquare/action", "api/creativesquare/like", "api/creativesquare/bookmark",
            "api/comment/add", "api/club/join", "api/club/quit", "api/user/update",
            "api/registration/create", "api/registration/cancel", "api/team/create", "api/team/join", "api/team/quit",
            "api/roam/checkin", "api/roam/stamp/exchange", "api/play/answer", "api/compliance/consents",
            "api/exploration-goals/create",
        ]:
            self.assertIn('"' + path + '"', block)
        for banned in [
            "api/registration/pay", "api/registration/cancel-refund", "api/withdrawal/create",
            "api/login", "api/merchant/", "api/club/settlement/withdraw", "api/mod-commerce",
        ]:
            self.assertNotIn(banned, block)
        self.assertIn("ReleaseMoneyWriteSwitch.blocks", block)
        launch = (ROOT / "App/RegionalLaunchConfiguration.swift").read_text()
        reviewed = launch.split("static func reviewedDeployment", 1)[1].split("static func reviewedComposition", 1)[0]
        market = launch.split("static func reviewedMarketDeployment", 1)[1].split("static func reviewedMarketComposition", 1)[0]
        self.assertIn("playerWritesEnabled: true", reviewed)
        self.assertNotIn("playerWritesEnabled: true", market)
        self.assertIn("productionGatesEnabled: false", market)


if __name__ == "__main__":
    unittest.main()
