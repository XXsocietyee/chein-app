"""PAGE-READY checks for pages/club/group-code/index. Not an Xcode run."""
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text()


class ClubGroupCodePageReadyChecks(unittest.TestCase):
    def test_group_code_page_states_stay_off_player_entry(self):
        core = read("Core/ClubGroupCodePort.swift")
        view = read("App/ClubGovernanceViews.swift")
        presentation = read("App/ClubGroupCodePresentation.swift")
        welcome = read("App/WelcomeView.swift")
        # The page is now projected inside the club-governance read host (club ops surface), never the player entry.
        self.assertIn("ClubGroupCodePage.project(value: value, scope: scope, capability:", view)
        self.assertNotIn("ClubGroupCodePage", welcome)
        for entry in ("App/WelcomeView.swift", "App/QuestifyApp.swift", "App/SessionHomeFeedView.swift"):
            self.assertNotIn("ClubGroupCodePage", read(entry))
        self.assertIn("static let showsMerchantChoice = false", welcome)
        for token in [
            "case loading",
            "case empty",
            "case error(ClubGovernanceFailure)",
            "case unknown",
            "case ready",
            'public static let unknownDisplay = "—"',
            "public static let includedInPlayerFirstEntry = false",
            "public static let routeMarkedLive = false",
            "public static let issuanceLive = false",
            "public static let readOperation = ClubGovernanceRead.topicOverview",
            "public static let issueOperation = ClubGovernanceMutation.issueGroupCode",
            "guard capability.granted else { return .loading(clientCapabilityPresent: false) }",
        ]:
            self.assertIn(token, core)
        self.assertNotIn("api/club/group-code", core)
        self.assertNotIn(".send(", core)
        for flag in [
            "showsMerchantChoice = true",
            "paymentEnabled = true",
            "payoutEnabled = true",
            "withdrawalEnabled = true",
            "virtualGoodsEnabled = true",
        ]:
            self.assertNotIn(flag, core)
        self.assertNotIn("http://", core)
        self.assertNotIn("https://", core)
        self.assertLess(core.index("#if DEBUG"), core.index("enum ClubGroupCodePageFixtureData"))
        self.assertLess(core.index("enum ClubGroupCodePageFixtureData"), core.rindex("#endif"))
        catalog = json.loads(read("Resources/Localizable.xcstrings"))["strings"]
        display = json.loads(read("Resources/ClubGroupCodeDisplay.xcstrings"))["strings"]
        note = read("docs/release/page-ready/pages-club-group-code-index.md")
        missing = [
            "club.groupCode.page.loading",
            "club.groupCode.page.empty",
            "club.groupCode.page.error",
            "club.groupCode.page.unknown",
            "club.groupCode.page.retry",
            "club.groupCode.metric.headcount",
        ]
        for key in missing:
            self.assertNotIn(key, catalog)
            self.assertNotIn(key, display)
            self.assertIn(key, core)
            self.assertIn(key, note)
        self.assertIn("club.gov.providerGate", catalog)
        self.assertIn("en", catalog["club.gov.providerGate"]["localizations"])
        self.assertIn("zh-Hans", catalog["club.gov.providerGate"]["localizations"])
        for line in [
            "Loading sessions you can lead",
            "正在加载可带队场次",
            "No sessions you can lead right now",
            "暂无可带队的场次",
            "The group code page didn't load",
            "团核销码页面加载失败",
            "A headcount wasn't provided",
            "人数未提供",
            "Try again",
            "重试",
            "Headcount",
            "人数",
        ]:
            self.assertIn(line, note)
        tests = read("Tests/CoreTests/ClubGroupCodePageReadyTests.swift")
        for name in [
            "testGroupCodePageStaysHiddenWithoutCheckInCapability",
            "testGroupCodePageLoadingEmptyReadyAndLiteralZero",
            "testGroupCodeUnknownHeadcountIsEmDashNeverZero",
            "testGroupCodeLoadUsesTopicOverviewAndHidesADeniedGrant",
            "testGroupCodeIssueCommandUsesExistingContractAndDoesNotSend",
        ]:
            self.assertIn("func " + name + "(", tests)


if __name__ == "__main__":
    unittest.main()
