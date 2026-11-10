"""Source contract for the club governance page model. Does not execute Swift."""
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if not (ROOT / "App").exists():
    ROOT = ROOT.parent

MISSING = {
    "clubOpsGov.page.loading": ("Loading governance", "正在加载治理记录"),
    "clubOpsGov.page.empty": ("Nothing to review", "暂无治理内容"),
    "clubOpsGov.page.unknown": ("Governance figures are unavailable", "治理数字暂未返回"),
    "clubOpsGov.count.bans": ("Bans", "封禁记录"),
    "clubOpsGov.count.cases": ("Cases", "工单"),
    "clubOpsGov.count.members": ("Members", "可治理成员"),
    "clubOpsGov.count.activeBan": ("Active ban", "生效封禁"),
}


def read(path):
    return (ROOT / path).read_text()


def catalog_has(catalog, key):
    entry = catalog.get("strings", {}).get(key)
    if not entry:
        return False
    for language in ("en", "zh-Hans"):
        unit = entry.get("localizations", {}).get(language, {}).get("stringUnit", {})
        if unit.get("state") != "translated" or not str(unit.get("value", "")).strip():
            return False
    return True


class ClubGovernancePageReadyChecks(unittest.TestCase):
    def test_governance_page_states_stay_off_player_entry(self):
        core = read("Core/ClubOpsGovernancePresentation.swift")
        note = read("docs/release/page-ready/pages-club-governance-index.md")
        tests = read("Tests/CoreTests/ClubOpsGovernancePageTests.swift")
        for token in [
            "case loading",
            "case empty",
            "case error(ClubGovernanceFailure)",
            "case unknown",
            "case ready",
            'public static let unknownDisplay = "—"',
            "public static let includedInPlayerFirstEntry = false",
            "public static let routeMarkedLive = false",
            "public static let performsWrites = false",
            "public static let bansRead = ClubGovernanceRead.bans",
            "public static let casesRead = ClubGovernanceRead.cases",
            "public static let membersRead = ClubGovernanceRead.members",
            "guard capability.granted else { return .loading(clientCapabilityPresent: false) }",
        ]:
            self.assertIn(token, core)
        for flag in [
            "showsMerchantChoice = true",
            "paymentEnabled = true",
            "payoutEnabled = true",
            "withdrawalEnabled = true",
            "virtualGoodsEnabled = true",
        ]:
            self.assertNotIn(flag, core)
        self.assertNotIn(".send(", core)
        self.assertNotIn("import SwiftUI", core)
        self.assertLess(core.index("#if DEBUG"), core.index("enum ClubOpsGovernancePageFixtureData"))
        self.assertLess(core.index("enum ClubOpsGovernancePageFixtureData"), core.rindex("#endif"))
        for path in ["App/HomeFeedView.swift", "App/WelcomeView.swift", "App/ClubHomeView.swift"]:
            self.assertNotIn("ClubOpsGovernancePage", read(path))
        for name in [
            "testGovernancePageStaysHiddenWithoutCapabilityAndOffPlayerEntry",
            "testGovernancePageLoadingEmptyReadyAndLiteralZero",
            "testGovernanceUnknownCountsAreEmDashNeverZero",
            "testGovernanceLoadUsesExistingReadsAndHidesADeniedGrant",
        ]:
            self.assertIn("func " + name + "(", tests)
        gov = json.loads(read("Resources/ClubOpsGovernance.xcstrings"))
        loc = json.loads(read("Resources/Localizable.xcstrings"))
        copy_keys = set(re.findall(r'"(clubOpsGov\.[A-Za-z0-9_.]+)"', core[core.index("enum Copy"):core.index("enum Accessibility")]))
        missing = sorted(key for key in copy_keys if not catalog_has(gov, key) and not catalog_has(loc, key))
        self.assertEqual(missing, sorted(MISSING))
        for key, (english, chinese) in MISSING.items():
            self.assertIn("`" + key + "`", note)
            self.assertIn(english, note)
            self.assertIn(chinese, note)
            self.assertNotIn("http", english.lower())
            self.assertNotIn("http", chinese.lower())
        self.assertNotIn("http", note.lower())


if __name__ == "__main__":
    unittest.main()
