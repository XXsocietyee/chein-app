"""Lane G player release gate: merchant center, merchant onboarding and coop entries are hidden in Release.

Static checks (no Xcode needed):
- one flag, `PlayerLaunch.merchantCenterEnabled`, false in Release and true under DEBUG/TEST;
- every intake (deep link, universal link, push tap, scan, page route table, parity router, reviewed page screen)
  passes through the gate and falls back to the player home page;
- every App/ file that opens a merchant-center/coop screen or names a hidden page is classified below. A new,
  unclassified entry point fails `test_no_unclassified_merchant_or_coop_entry_point`; a file marked `gated` that
  loses its `PlayerLaunch.` guard fails `test_gated_files_keep_their_guard`;
- the Swift unit test pins exactly the hidden pages of the generated route table.
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


# Mirror of Core/PlayerLaunch.swift.
PREFIXES = ("pages/merchant/", "pages/coop/", "pages/cooperation/")
SINGLES = {"pages/topic/merchantapply/index", "pages/topic/merchantinfo/merchantinfo"}
PLAYER_VISIBLE = {"pages/merchant/profile/index"}


def is_merchant_center_page(page: str) -> bool:
    page = page.split("?", 1)[0].lstrip("/")
    if page in PLAYER_VISIBLE:
        return False
    return page in SINGLES or any(page.startswith(p) or page + "/" == p for p in PREFIXES)


MERCHANT_VIEWS = re.compile(
    r"\b(MerchantOnboardingView|MerchantHomeView|SessionMerchantRootContainerView|CooperationBrowserView|"
    r"MerchantCoopCenterView|SessionMerchantCoopCenterView|BeGapMerchantHubView|SessionMerchantOverviewView|"
    r"SessionMerchantProjectBrowseView|IMCoopInviteStripView|CoopRelationDiscoveryView|SessionCoopRelationDiscoveryView|"
    r"CooperationFlowWorkbench|CoopFlowReadView|CooperationInviteDetailView|CoopFlowNewInvitationView|"
    r"CoopFinanceProfitView|MerchantAccountModeSwitchRow|MerchantRootModeSwitchBannerView)\(")
HIDDEN_LITERAL = re.compile(r'"(/?pages/(?:merchant|coop|cooperation)/[^"]*|/?pages/topic/merchant(?:apply|info)/[^"]*)"')

# Every App/ file (fixtures excluded) that opens a merchant-center/coop screen or names a hidden page.
#   gated          - the entry is behind `PlayerLaunch.` in this file (checked below)
#   merchant-only  - reached only from the merchant console, a hidden route or another gated entry
#   player-money   - player money flow (主办分润 / wallet earnings); stays on by owner decision 11-26
CLASSIFIED = {
    "App/AccountView.swift": "gated",                      # Me tab merchant rows, coop row, mode switch row
    "App/SettingsAccountEntries.swift": "gated",           # 成为商家 in Settings
    "App/SettingsView.swift": "gated",                     # 商家工具 (BeGap merchant hub)
    "App/SessionHomeFeedView.swift": "gated",              # 成为商家 home banner action
    "App/HomeSearchTabParityViews.swift": "gated",         # merchant root mode + banner list
    "App/QuestifyApp.swift": "gated",                      # merchant gate actions (申请入驻); root mode via coordinator
    "App/ProjectOwnedContentViews.swift": "gated",         # 我的项目 › 查看申请 (received coop applies)
    "App/IMCoopInviteStripFactory.swift": "gated",         # 消息 coop invite strip
    "App/ClubDetailR8Mounts.swift": "gated",               # club coop pool (可对接的活动 / 我的合作)
    "App/ClubGovernanceViews.swift": "gated",              # 切换到商家端 / 查看商家入驻 / merchantinfo review
    "App/CouponManagementView.swift": "gated",             # 申请成为商家 from the coupon deny state
    "App/PlayerJourneyViews.swift": "gated",               # 去修改 merchant apply editor
    "App/ClubTopicDirectorMount.swift": "gated",           # 准备总览 联系商家 (coop list)
    "App/MPGap/AccountPublish/AccountPublishR9Mounts.swift": "gated",  # 发起合作 bar on a merchant's public profile
    "App/MPParityKit.swift": "gated",                      # parity route table: hidden page -> player home
    "App/MPReviewedPageScreen.swift": "gated",             # reviewed page screen: hidden page -> player home
    "App/CoopRelationDiscoveryView.swift": "merchant-only",
    "App/CooperationBrowserView.swift": "merchant-only",
    "App/CooperationFlowWorkbench.swift": "merchant-only",
    "App/IMCoopInviteStripView.swift": "merchant-only",    # built only by IMCoopInviteStripFactory
    "App/NativeR2/Island/IslandSources.swift": "merchant-only",  # coop invite island, fed only by the gated IM coop strip
    "App/MerchantCoopCenterSessionBinding.swift": "merchant-only",
    "App/MerchantDecorR8Parity.swift": "merchant-only",
    "App/MerchantHomeView.swift": "merchant-only",
    "App/MerchantPersonalIncomeHandoff.swift": "merchant-only",
    "App/MerchantReading.swift": "merchant-only",
    "App/NativeEntryLandingView.swift": "merchant-only",   # SessionMerchantMarketingDestination
    "App/OrphanScreenMounts.swift": "merchant-only",       # default for MerchantHomeView's authoring destination
    "App/SubscribeMessageTapScreens.swift": "merchant-only",  # .coopList, reachable only via the gated parity route
    "App/SessionWalletCommerceView.swift": "player-money",
    "App/WalletEarningsOverview.swift": "player-money",
}


def app_sources():
    for f in sorted((ROOT / "App").rglob("*.swift")):
        rel = f.relative_to(ROOT).as_posix()
        if "fixture" in rel.lower() or "/DesignFixtures/" in rel or "/NativeGallery/" in rel:
            continue
        yield rel, f.read_text(encoding="utf-8")


class PlayerReleaseGateContracts(unittest.TestCase):
    def test_single_flag_is_false_in_release(self):
        src = read("Core/PlayerLaunch.swift")
        m = re.search(r"#if DEBUG \|\| TEST\s+public static let merchantCenterEnabled = true\s+#else\s+"
                      r"public static let merchantCenterEnabled = false\s+#endif", src)
        self.assertIsNotNone(m, "PlayerLaunch.merchantCenterEnabled must be true only under DEBUG || TEST")
        decls = re.findall(r"merchantCenterEnabled\s*=", " ".join(read(p) for p, _ in app_sources()))
        self.assertEqual(decls, [], "the flag is declared once, in Core/PlayerLaunch.swift")
        self.assertIn('playerHomePage = "pages/index/index"', src)

    def test_every_intake_passes_the_gate(self):
        session = read("App/AppSession.swift")
        body = session.split("func receiveNativeIntent(_ intent: NativeEntryIntent) {", 1)[1].split("\n    }\n", 1)[0]
        self.assertIn("NativeEntryPresentation(intent: PlayerLaunch.gate(intent))", body)
        self.assertEqual(len(re.findall(r"nativeEntry\s*=\s*NativeEntryPresentation", session)), 1)
        for rel, src in app_sources():
            if rel != "App/AppSession.swift":
                self.assertNotRegex(src, r"nativeEntry\s*=\s*NativeEntryPresentation", rel)
        entry = read("App/MPParityDeepLinkEntry.swift")
        # chein://mp, universal links and push taps all hand their intent to receiveNativeIntent.
        self.assertIn("receiveNativeIntent(.miniProgramPage(link))", entry)
        self.assertIn("receiveAppLink(destination)", entry)
        self.assertIn("case .entry(let intent): receiveNativeIntent(intent)", read("App/AppSession+AppLinks.swift"))
        self.assertIn("session.receiveNativeIntent(intent)", entry)
        self.assertIn("session.receiveNativeIntent(pending)", entry)
        scan = read("Core/ScanPayload.swift")
        self.assertEqual(scan.count(".entry(PlayerLaunch.gate(intent))"), 2)
        self.assertNotRegex(scan, r"\.entry\(intent\)")

    def test_route_tables_fall_back_to_player_home(self):
        kit = read("App/MPParityKit.swift")
        self.assertIn("if PlayerLaunch.isHidden(page: page) { self = .screen(page: PlayerLaunch.playerHomePage, query: [:]); return }", kit)
        self.assertIn('let merchant = query["scope"] == "MERCHANT" && PlayerLaunch.merchantCenterEnabled', kit)
        screen = read("App/MPReviewedPageScreen.swift")
        self.assertIn("if PlayerLaunch.isHidden(page: page) { playerHomeFallback } else { screen }", screen)
        self.assertIn("MPTabHandoff { session.dismissNativeEntry(); rootTabSwitch(.home) }",
                      screen.split("private var playerHomeFallback", 1)[1].split("\n    }\n", 1)[0])
        gen = read("tools/build_page_route_table.py")
        self.assertIn("guard !PlayerLaunch.isHidden(page: bare) else { return nil }", gen)
        self.assertIn("guard !PlayerLaunch.isHidden(page: bare) else { return nil }", read("Core/MiniProgramPages.swift"))

    def test_merchant_root_mode_is_off(self):
        src = read("App/HomeSearchTabParityViews.swift")
        self.assertIn("guard PlayerLaunch.merchantCenterEnabled, isConfigured, isSignedIn, let accountID, accountID > 0 else {", src)
        self.assertIn("guard PlayerLaunch.merchantCenterEnabled else { return false }", src)
        self.assertIn("guard PlayerLaunch.merchantCenterEnabled else { return .unavailable }", src)
        self.assertIn("HomeIndexParityPresentation.playerActionBanners", src)
        self.assertNotIn("return HomeIndexParityPresentation.fixedActionBanners", src)

    def test_me_settings_and_home_entries_are_guarded(self):
        checks = {
            "App/AccountView.swift": [
                "if showsMerchant && PlayerLaunch.merchantCenterEnabled && themeDomain != .player { merchantSection }",
                "if WelcomeView.showsMerchantChoice && PlayerLaunch.merchantCenterEnabled {",
            ],
            "App/WelcomeView.swift": ["if Self.showsMerchantChoice && PlayerLaunch.merchantCenterEnabled {"],
            "App/SettingsAccountEntries.swift": ["if PlayerLaunch.merchantCenterEnabled { // Lane G: 成为商家"],
            "App/SettingsView.swift": ['if PlayerLaunch.merchantCenterEnabled && session.account?.effectiveRole == "merchant" { Section {'],
            "App/SessionHomeFeedView.swift": ['case "merchant_apply" where PlayerLaunch.merchantCenterEnabled:'],
            "App/QuestifyApp.swift": [r"\.merchantGateActions, PlayerLaunch.merchantCenterEnabled ? MerchantGateActions("],
            "App/ProjectOwnedContentViews.swift": [r"\.myProjectReceivedApplies, PlayerLaunch.merchantCenterEnabled ? {"],
            "App/IMCoopInviteStripFactory.swift": ["guard PlayerLaunch.merchantCenterEnabled, let reader else { return nil }"],
            "App/CouponManagementView.swift": ["if isMerchantMember || !PlayerLaunch.merchantCenterEnabled {"],
            "App/PlayerJourneyViews.swift": ["if PlayerLaunch.merchantCenterEnabled { // Lane G: merchant apply editor"],
            "App/ClubTopicDirectorMount.swift": ["if PlayerLaunch.merchantCenterEnabled, merchantHoldBlocked, let topicID {"],
            "App/MPGap/AccountPublish/AccountPublishR9Mounts.swift": [
                "guard PlayerLaunch.merchantCenterEnabled, isMerchant, let viewer = session.account?.id else { return false }"],
            "Core/HomeSearchTabParity.swift": ["fixedActionBanners.filter { !PlayerLaunch.isHidden(page: $0.routePath) }"],
        }
        for rel, needles in checks.items():
            src = read(rel)
            for needle in needles:
                self.assertIn(needle.replace("\\", ""), src.replace("\\", ""), f"{rel}: {needle}")
        club = read("App/ClubDetailR8Mounts.swift")
        pool = club.split("struct ClubCoopPoolMount: View {", 1)[1].split("\n}\n", 1)[0]
        self.assertIn("if PlayerLaunch.merchantCenterEnabled {", pool)
        gov = read("App/ClubGovernanceViews.swift")
        # CLB-r9-topic-detail-02: 承接审核 moved from the toolbar ClubGapTopicMoreMenu into the 更多 sheet; same gate.
        undertake = gov.split('Button("club.director.reviewUndertake")', 1)[0].rsplit("\n", 2)[-2]
        self.assertIn('if PlayerLaunch.merchantCenterEnabled, stats["canReviewChapterApplications"] == .bool(true) {', undertake)
        self.assertEqual(gov.count('Button("club.director.reviewUndertake")'), 1)
        self.assertNotIn("ClubGapTopicMoreMenu(", gov)
        self.assertIn("if PlayerLaunch.merchantCenterEnabled, let topicID = scope.topicID, stats[\"canReviewChapterApplications\"]", gov)
        self.assertIn("if PlayerLaunch.merchantCenterEnabled { // Lane G: 切换到商家端", gov)

    def test_no_unclassified_merchant_or_coop_entry_point(self):
        found = {}
        for rel, src in app_sources():
            views = set(MERCHANT_VIEWS.findall(src))
            pages = {m for m in HIDDEN_LITERAL.findall(src) if is_merchant_center_page(m)}
            if views or pages:
                found[rel] = sorted(views) + sorted(pages)
        unclassified = {k: v for k, v in found.items() if k not in CLASSIFIED}
        self.assertEqual(unclassified, {}, "new merchant/coop entry point: guard it with PlayerLaunch and classify it")

    def test_gated_files_keep_their_guard(self):
        for rel, kind in CLASSIFIED.items():
            self.assertIn(kind, {"gated", "merchant-only", "player-money"}, rel)
            if kind == "gated":
                self.assertIn("PlayerLaunch.", read(rel), rel)

    def test_swift_test_pins_the_route_table_hidden_set(self):
        table = read("Core/MiniProgramPages.swift")
        pages = re.findall(r'case \w+ = "([^"]+)"', table)
        self.assertGreater(len(pages), 200)
        hidden = {p for p in pages if is_merchant_center_page(p)}
        test = read("Tests/CoreTests/PlayerReleaseGateTests.swift")
        block = test.split("static let hiddenPages: Set<String> = [", 1)[1].split("]", 1)[0]
        pinned = set(re.findall(r'"([^"]+)"', block))
        self.assertEqual(pinned, hidden)
        for page in ("pages/merchant/profile/index", "pages/play/merchant/index", "pages/index/index"):
            self.assertNotIn(page, hidden)
        core = read("Core/PlayerLaunch.swift")
        for prefix in PREFIXES:
            self.assertIn(f'"{prefix}"', core)
        for page in SINGLES | PLAYER_VISIBLE:
            self.assertIn(f'"{page}"', core)

    def test_player_money_flows_are_not_gated(self):
        # Owner 11-26: money on. The gate never touches payment, refund, payout or withdrawal switches.
        code = "\n".join(l.split("//", 1)[0] for l in read("Core/PlayerLaunch.swift").splitlines())
        for word in ("payment", "refund", "payout", "withdraw", "Money"):
            self.assertNotIn(word, code)
        for rel, src in app_sources():
            for line in src.splitlines():
                if "PlayerLaunch." in line:
                    self.assertNotRegex(line, r"(?i)moneyEnabled|paymentEnabled|refundEnabled|payoutEnabled|withdraw", f"{rel}: {line}")


if __name__ == "__main__":
    unittest.main()
