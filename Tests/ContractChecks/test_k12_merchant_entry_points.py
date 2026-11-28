"""K12: every player-reachable merchant-center entry is gated on PlayerLaunch.merchantCenterEnabled.

The first release is player + clubs. The flag stays false in Release. This list is the entry points a player
can open (Settings, Mine, profile, search, deep links, notifications, the publish menu, and routes that do
not go through Settings). Public store pages stay open: they are not the merchant center.
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


# name, file, source needle that hides the entry while the flag is off.
ENTRIES = [
    ("Settings 成为商家", "App/SettingsAccountEntries.swift",
     "if PlayerLaunch.merchantCenterEnabled { // Lane G: 成为商家"),
    ("Settings 商家工具", "App/SettingsView.swift",
     'if PlayerLaunch.merchantCenterEnabled && session.account?.effectiveRole == "merchant"'),
    ("Settings account card opens 品牌中心", "App/ProfileSettingsProfileRoute.swift",
     'guard PlayerLaunch.merchantCenterEnabled, accountID > 0, role == "merchant"'),
    ("Settings identity deep link uses the gated rows", "App/MPGap/AccountPublish/AccountPublishR8Mounts.swift",
     "SettingsIdentityApplicationEntries(session: session, profile: profile)"),
    ("Mine merchant rows", "App/AccountView.swift",
     "if showsMerchant && PlayerLaunch.merchantCenterEnabled && themeDomain != .player { merchantSection }"),
    ("Mine 合作 row", "App/AccountView.swift",
     "if WelcomeView.showsMerchantChoice && PlayerLaunch.merchantCenterEnabled"),
    ("Mine ··· menu has no merchant row", "App/AccountView.swift",
     'Button { showsPublicProfile = true } label: { Label("social.profile"'),
    ("Welcome 商家注册", "App/WelcomeView.swift",
     "if Self.showsMerchantChoice && PlayerLaunch.merchantCenterEnabled"),
    ("Home banner 成为商家", "App/SessionHomeFeedView.swift",
     'case "merchant_apply" where PlayerLaunch.merchantCenterEnabled:'),
    ("Home banner list drops the hidden page", "Core/HomeSearchTabParity.swift",
     "fixedActionBanners.filter { !PlayerLaunch.isHidden(page: $0.routePath) }"),
    ("Merchant root console", "App/HomeSearchTabParityViews.swift",
     "guard PlayerLaunch.merchantCenterEnabled, isConfigured, isSignedIn, let accountID, accountID > 0 else {"),
    ("商家工作台 switch", "App/HomeSearchTabParityViews.swift",
     "guard PlayerLaunch.merchantCenterEnabled else { return .unavailable }"),
    ("Denied state 申请入驻", "App/QuestifyApp.swift",
     ".merchantGateActions, PlayerLaunch.merchantCenterEnabled ? MerchantGateActions("),
    ("我的项目 查看申请", "App/ProjectOwnedContentViews.swift",
     ".myProjectReceivedApplies, PlayerLaunch.merchantCenterEnabled ? {"),
    ("我的项目 topic opens merchantinfo", "App/ProjectOwnedContentViews.swift",
     "if PlayerLaunch.merchantCenterEnabled {"),
    ("我的项目 scope=MERCHANT", "App/ProjectOwnedContentViews.swift",
     'if entryScope == "MERCHANT", !PlayerLaunch.merchantCenterEnabled { return nil }'),
    ("Messages 竞猜 entry", "App/SessionMessagingEntry.swift",
     "predictionEntry: PlayerLaunch.merchantCenterEnabled ? { AnyView(SessionMerchantPredictionEntry(session: session)) } : nil"),
    ("Messages merchant chrome", "App/SessionMessagingEntry.swift",
     'merchantChrome: PlayerLaunch.merchantCenterEnabled && session.account?.role == "merchant"'),
    ("Messages coop invite strip", "App/IMCoopInviteStripFactory.swift",
     "guard PlayerLaunch.merchantCenterEnabled, let reader else { return nil }"),
    ("Orders notification opens merchant projects", "App/SubscribeMessageTapScreens.swift",
     'if PlayerLaunch.merchantCenterEnabled, session.account?.effectiveRole == "merchant"'),
    ("Orders page opens merchant projects", "App/MPReviewedPageScreen.swift",
     'if PlayerLaunch.merchantCenterEnabled, session.account?.effectiveRole == "merchant" { SubscribeMessageProjectsEntry'),
    ("Deep link, universal link and push tap", "App/AppSession.swift",
     "NativeEntryPresentation(intent: PlayerLaunch.gate(intent))"),
    ("QR scan", "Core/ScanPayload.swift",
     ".entry(PlayerLaunch.gate(intent))"),
    ("In-app route table", "App/MPParityKit.swift",
     "if PlayerLaunch.isHidden(page: page)"),
    ("Reviewed page screen", "App/MPReviewedPageScreen.swift",
     "if PlayerLaunch.isHidden(page: page) { playerHomeFallback }"),
    ("myproject?scope=MERCHANT route", "App/MPParityKit.swift",
     'let merchant = query["scope"] == "MERCHANT" && PlayerLaunch.merchantCenterEnabled'),
    ("Coupon deny 申请成为商家", "App/CouponManagementView.swift",
     "if isMerchantMember || !PlayerLaunch.merchantCenterEnabled {"),
    ("Coupon forbidden player CTA", "App/MPGap/Member/MemberRound4Views.swift",
     "if isMerchant || !PlayerLaunch.merchantCenterEnabled {"),
    ("Participation 去修改", "App/PlayerJourneyViews.swift",
     "if PlayerLaunch.merchantCenterEnabled { // Lane G: merchant apply editor"),
    ("Public profile 发起合作", "App/MPGap/AccountPublish/AccountPublishR9Mounts.swift",
     "guard PlayerLaunch.merchantCenterEnabled, isMerchant, let viewer = session.account?.id else { return false }"),
    ("Public store 发送邀约", "App/PublicMerchantHomeView.swift",
     "if PlayerLaunch.merchantCenterEnabled, popupActions.loadCoopInviteTopics != nil {"),
    ("Public store invite loader", "App/AppSession+MemberPopups.swift",
     "if PlayerLaunch.merchantCenterEnabled {"),
    ("Club 可对接的活动", "App/ClubDetailR8Mounts.swift",
     "if PlayerLaunch.merchantCenterEnabled {"),
    ("Club 邀约承接", "App/ClubDetailView.swift",
     "undertake: PlayerLaunch.merchantCenterEnabled && viewerDomain == .merchant"),
    ("Club undertake destination", "App/ClubDetailR8Mounts.swift",
     "if PlayerLaunch.merchantCenterEnabled, let session {"),
    ("Club 可对接商家", "App/ClubDetailView.swift",
     "if PlayerLaunch.merchantCenterEnabled {"),
    ("Club 邀请商家", "App/ClubLeadPrimaryActionView.swift",
     "if !PlayerLaunch.merchantCenterEnabled, action == .merchants || action == .sentInvitations { return nil }"),
    ("Club 切换到商家端", "App/ClubGovernanceViews.swift",
     "if PlayerLaunch.merchantCenterEnabled { // Lane G: 切换到商家端"),
    ("Club 联系商家", "App/ClubTopicDirectorMount.swift",
     "if PlayerLaunch.merchantCenterEnabled, merchantHoldBlocked, let topicID {"),
    ("Pricing chapter opens merchantinfo", "App/PublisherLifecycleViews.swift",
     "if PlayerLaunch.merchantCenterEnabled, TopicPricingXcx.opensChapterProject(row), let chapterProject"),
    ("Topic page chapter project destination", "App/PlatformConsumerSessionOwner.swift",
     ".environment(\\.pricingChapterProjectDestination, PlayerLaunch.merchantCenterEnabled ? { topicID in"),
    ("Pricing page chapter project destination", "App/MPReviewedPageScreen.swift",
     ".environment(\\.pricingChapterProjectDestination, PlayerLaunch.merchantCenterEnabled ? { topicID in"),
    ("Topic editor drops scope=MERCHANT", "App/PlatformConsumerSessionOwner.swift",
     'if let scope, scope != "MERCHANT" || PlayerLaunch.merchantCenterEnabled { query["scope"] = scope }'),
    ("Publish editor scope=MERCHANT", "App/MPReviewedPageScreen.swift",
     'if scope == "MERCHANT", !PlayerLaunch.merchantCenterEnabled { return nil }'),
    ("Publish tab query drops scope=MERCHANT", "App/PublishTabRootView.swift",
     'if let scope, !scope.isEmpty, scope != "MERCHANT" || PlayerLaunch.merchantCenterEnabled { query["scope"] = scope }'),
    ("Template draft scope=MERCHANT", "App/MPGap/AccountPublish/AccountPublishR9Mounts.swift",
     'guard PlayerLaunch.merchantCenterEnabled, scope == "MERCHANT" else { return coordinator }'),
    ("Template shelf scope=MERCHANT", "App/TemplateAuthoringMineView.swift",
     "guard PlayerLaunch.merchantCenterEnabled else { return nil }"),
    ("Member locked merchant benefits", "App/MemberHomeHeader.swift",
     "!$0.isMerchantCapability || $0.unlocked || PlayerLaunch.merchantCenterEnabled"),
]


class K12MerchantEntryPoints(unittest.TestCase):
    def test_one_flag_stays_off_in_release(self):
        src = read("Core/PlayerLaunch.swift")
        self.assertIsNotNone(re.search(
            r"#if DEBUG \|\| TEST\s+public static let merchantCenterEnabled = true\s+#else\s+"
            r"public static let merchantCenterEnabled = false\s+#endif", src))
        self.assertNotIn("merchantEntryEnabled", src)
        decls = []
        for path in (ROOT / "App").rglob("*.swift"):
            if "Fixture" in path.name or "DesignFixtures" in path.as_posix():
                continue
            decls += re.findall(r"merchantCenterEnabled\s*=", path.read_text(encoding="utf-8"))
        self.assertEqual(decls, [])

    def test_every_player_merchant_entry_is_gated(self):
        self.assertGreaterEqual(len(ENTRIES), 40)
        for name, rel, needle in ENTRIES:
            src = read(rel)
            self.assertIn(needle, src, name)
            # The identity picker mounts the Settings rows; the flag lives on those rows.
            if "PlayerLaunch." not in needle:
                self.assertIn("if PlayerLaunch.merchantCenterEnabled { // Lane G: 成为商家",
                              read("App/SettingsAccountEntries.swift"), name)

    def test_publish_menu_and_settings_search_have_no_ungated_merchant_row(self):
        menu = read("App/PublishTabRootView.swift")
        self.assertNotIn("MerchantOnboardingView", menu)
        self.assertNotIn("settings.becomeMerchant", menu)
        self.assertIn("PlayerLaunch.merchantCenterEnabled", menu)
        search = read("App/SettingsView.swift").split("private let entries = [", 1)[1].split("]", 1)[0]
        self.assertNotIn("becomeMerchant", search)
        self.assertNotIn("merchant", search.lower())

    def test_search_keeps_the_public_store_and_not_the_center(self):
        # Search merchant rows and 找商家 open the public store page. That page stays.
        # The coop invite on it is gated (see ENTRIES).
        detail = read("App/SearchMapDetailViews.swift")
        discover = read("App/MerchantDiscoverView.swift")
        for src in (detail, discover):
            self.assertNotIn("MerchantOnboardingView", src)
            self.assertNotIn("pages/merchant/apply", src)
            self.assertIn("PublicMerchantHomeView", discover)
        self.assertIn("SearchMapMerchantDetailView", read("App/SessionGlobalSearchView.swift"))


if __name__ == "__main__":
    unittest.main()
