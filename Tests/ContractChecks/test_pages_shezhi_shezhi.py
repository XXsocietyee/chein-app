"""Source checks for pages/shezhi/shezhi. Not a Swift or Xcode run."""
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
DASH = "\u2014"
NOTE = "docs/release/page-ready/pages-shezhi-shezhi.md"


class PagesShezhiShezhiTests(unittest.TestCase):
    def read(self, path):
        return (ROOT / path).read_text(encoding="utf-8")

    def test_home_page_keeps_unknown_as_an_em_dash_and_does_not_mark_a_route_live(self):
        source = self.read("Core/SettingsIdentityApplications.swift")
        for token in [
            "case loading",
            "case empty",
            "case error",
            "case unknown",
            "case ready",
            'public static let unknownDisplay = "—"',
            "public static let routeMarkedLive = false",
            "guard let count else { return unknownDisplay }",
            "return String(count)",
            "public static func countText(numericString _: String) -> String { unknownDisplay }",
            'knownRoles: Set<String> = ["player", "merchant", "club"]',
            "SettingsIdentityApplications.isOffered(toRole: trimmed)",
            "offersIdentityApplications: false",
        ]:
            self.assertIn(token, source)
        self.assertIn(DASH, source)
        # CB277 appends the about-page model to this file and names the uninstalled
        # player-code path. The home model itself still opens no route.
        home, about = source.split("public enum SettingsAboutMetadataPhase", 1)
        # pages/shezhi/shezhi.js:406 reads POST /api/user/info (403 stays a denial at :399).
        # That path is named only in comments. Executable home code still opens no route.
        home_code = "\n".join(line.split("//", 1)[0] for line in home.splitlines())
        self.assertNotIn("api/", home_code)
        self.assertIn("public static let routeInstalled = false", about)
        self.assertIn("public static let routeMarkedLive = false", about)
        self.assertNotIn("routeMarkedLive = true", about)
        self.assertNotIn("routeInstalled = true", about)
        for forbidden in [
            "showsMerchantChoice = true",
            "paymentEnabled = true",
            "payoutEnabled = true",
            "withdrawalEnabled = true",
            "virtualGoodsEnabled = true",
            "https://",
            "http://",
            "URLSession",
            "URLRequest",
            "15229020419",
            "[ICP_FILING_PLACEHOLDER]",
            "[SUPPORT_CONTACT_PLACEHOLDER]",
            "[UGC_POLICY_PLACEHOLDER]",
        ]:
            self.assertNotIn(forbidden, source)
        self.assertIn(
            "func testOnlySignedInPlayerViewIsOfferedApplications",
            self.read("Tests/CoreTests/SettingsIdentityApplicationsTests.swift"),
        )

    def test_debug_fixture_data_is_compiled_out_of_release(self):
        source = self.read("Core/SettingsIdentityApplications.swift")
        start = source.index("#if DEBUG")
        end = source.index("#endif", start)
        body = source[start:end]
        self.assertIn("public enum SettingsHomeFixtureData {", body)
        self.assertNotIn("public enum SettingsHomeFixtureData {", source[end:])
        for label in ["player", "merchant", "club", "UNKNOWN", '"0"', '"  "']:
            self.assertIn(label, body)
        self.assertNotIn("15229020419", body)

    def test_missing_phase_keys_are_listed_and_not_invented_in_the_catalog(self):
        note = self.read(NOTE)
        catalog = json.loads(self.read("Resources/Localizable.xcstrings"))["strings"]
        member = json.loads(self.read("Resources/MemberProfile.xcstrings"))["strings"]
        missing = ["settings.home.loading", "settings.home.error", "settings.home.unknown"]
        for key in missing:
            self.assertIn("`%s`" % key, note)
            self.assertNotIn(key, catalog)
        self.assertIn("member.settings.signedOut", member)
        self.assertIn("settings.title", catalog)
        self.assertIn("region.market", catalog)
        for literal in ["客服与安全", "Support and safety", "内容规范", "Content rules",
                        "联系客服", "Contact support", "查看客服联系方式", "Show support contact"]:
            self.assertIn(literal, note)
        for placeholder in ["[SUPPORT_CONTACT_PLACEHOLDER]", "[ICP_FILING_PLACEHOLDER]",
                            "[UGC_POLICY_PLACEHOLDER]"]:
            self.assertIn(placeholder, note)
        view = self.read("App/SettingsView.swift")
        # The unknown market now renders through the Core helper (nil -> the em dash), never invented or shown as a value.
        self.assertIn("SettingsHomePage.marketText(RegionalLaunchConfiguration.storefrontMarket ?? session.operationalMarket)", view)
        core = self.read("Core/SettingsIdentityApplications.swift")
        self.assertIn("market?.rawValue ?? unknownDisplay", core)

    def test_existing_settings_offer_behavior_is_unchanged(self):
        source = self.read("Core/SettingsIdentityApplications.swift")
        offer = source.split("public enum SettingsHomePage", 1)[0]
        self.assertIn('return role != "merchant" && role != "club"', offer)
        self.assertNotIn("unknownDisplay", offer)


if __name__ == "__main__":
    unittest.main()
