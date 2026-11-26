"""Static contract checks for Step 3 (ui/h-chrome-v1): per-screen domain switching, tab bar visibility, back nav split, pinned footer bars, and player sheet glass."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read_swift(rel_path: str) -> str:
    return (ROOT / rel_path).read_text(encoding="utf-8")


def strip_swift_comments(src: str) -> str:
    no_block = re.sub(r"/\*.*?\*/", "", src, flags=re.S)
    return re.sub(r"//.*", "", no_block)


class TestGlobalChromeDomainContract(unittest.TestCase):
    def test_game_domain_uses_dark_play_stage_and_game_tokens(self):
        theme = read_swift("App/Theme/Theme.swift")
        self.assertRegex(
            theme,
            r"case [^:]*\.game[^:]*:\s*return \.dark",
            "Play runtime (.game) must resolve to dark colorScheme, not system/merchant light.",
        )

        palette = read_swift("App/DesignSystem/CYDomainPalette.swift")
        self.assertIn("private var surfaceDomain: ThemeDomain { domain == .game ? .player : domain }", palette)
        self.assertNotIn("0x0F172B", palette)
        self.assertNotIn("0x0F172A", palette)

        for rel in (
            "App/PlayExperienceView.swift",
            "App/PlaySessionView.swift",
            "App/PlayRouteMapView.swift",
            "App/PlayKitTimedChallengeView.swift",
            "App/PlayKitSensorChallengeView.swift",
            "App/CityOnsiteTaskView.swift",
            "App/CityNeutralTaskView.swift",
            "App/OrientScoreView.swift",
            "App/PlayKitScreen.swift",
        ):
            src = read_swift(rel)
            self.assertRegex(
                src,
                r"cyDomainScreen\(\.game\)|cyPushedChrome\(domain: \.game\)",
                f"{rel} must bind Play Runtime to the .game domain.",
            )
            self.assertNotIn(".themeDomain(.player)", src)

    def test_merchant_and_coop_screens_use_merchant_light_domain_not_player_dark(self):
        for rel in (
            "App/MerchantHomeView.swift",
            "App/MerchantProjectsView.swift",
            "App/CooperationBrowserView.swift",
            "App/CooperationFlowWorkbench.swift",
            "App/CooperationInviteDetailView.swift",
            "App/CoopFinanceProfitView.swift",
            "App/CoopSettlementDetailView.swift",
            "App/MerchantCoopCenterView.swift",
            "App/MerchantBusinessViews.swift",
            "App/MerchantOrdersView.swift",
            "App/MerchantPayoutAccountView.swift",
            "App/MerchantCityNodeHubView.swift",
            "App/MerchantCityNodeCreateView.swift",
            "App/MerchantLedgerSettlementOverview.swift",
            "App/MerchantOnboardingView.swift",
            "App/CouponManagementView.swift",
            "App/PublicMerchantHomeView.swift",
            "App/CityNodeRedeemView.swift",
        ):
            src = read_swift(rel)
            self.assertRegex(
                src,
                r"\.(?:cyDomainScreen|themeDomain)\(\.merchant\b|\.cyPushedChrome\([^)]*domain:\s*\.merchant\b",
                f"{rel} must explicitly apply the .merchant light domain.",
            )
            self.assertNotRegex(
                src,
                r"\.themeDomain\(\.player\)",
                f"{rel} must not override merchant/coop surfaces with .player dark domain.",
            )

        # MerchantOperationsViews, MerchantEngagementViews, and MerchantContentEditor are hash-pinned by
        # submission import contracts; MerchantHomeView wraps all three pushed destinations in `.cyPushedChrome(domain: .merchant)`.
        merchant_home = read_swift("App/MerchantHomeView.swift")
        self.assertRegex(
            merchant_home,
            r"MerchantOperationsHomeView\([\s\S]*?\.cyPushedChrome\(domain: \.merchant\)",
        )
        self.assertRegex(
            merchant_home,
            r"MerchantEngagementHomeView\([\s\S]*?\.cyPushedChrome\(domain: \.merchant\)",
        )
        self.assertRegex(
            merchant_home,
            r"MerchantContentHomeView\([\s\S]*?\.cyPushedChrome\(domain: \.merchant\)",
        )

    def test_creator_studio_and_topic_editor_use_topic_editor_domain(self):
        # PublishingModesViews is hash-pinned by activity publishing wizard contracts;
        # SessionPublishingModesView wraps it with `.cyPushedChrome(domain: .topicEditor)`.
        for rel in (
            "App/ProjectEditView.swift",
            "App/SessionPublishingModesView.swift",
            "App/TemplateAuthoringView.swift",
            "App/StoryRuleEditorView.swift",
            "App/CreatorContentViews.swift",
        ):
            src = read_swift(rel)
            self.assertRegex(
                src,
                r"\.(?:cyDomainScreen|themeDomain)\(\.topicEditor\b|\.cyPushedChrome\([^)]*domain:\s*\.topicEditor\b",
                f"{rel} must explicitly apply the .topicEditor light domain.",
            )

    def test_tab_bar_uses_hidden_preference_and_miniprogram_opacity(self):
        tab_bar = read_swift("App/DesignSystem/CYDomainTabBar.swift")
        self.assertIn("Theme.MiniProgramChrome.tabUnselectedOpacity", tab_bar)
        self.assertIn("struct CYTabBarHiddenPreferenceKey", tab_bar)
        self.assertIn("func cyHideTabBar", tab_bar)

        night_bar = read_swift("App/DesignSystem/CYNightTabBar.swift")
        self.assertIn("@Environment(\\.cyTabBarHidden) private var isTabBarHidden", night_bar)
        self.assertIn("if !isTabBarHidden {", night_bar)
        self.assertIn("isTabBarHidden ? 0 : CYFloatingTabBarClearanceKey.height", night_bar)

        app_root = read_swift("App/QuestifyApp.swift")
        self.assertIn("CYTabBarHiddenPreferenceKey.self", app_root)
        self.assertIn("isTabBarHidden", app_root)
        self.assertNotIn(".tint(QuestifyPalette.accent)", app_root)

        home_search = read_swift("App/HomeSearchTabParityViews.swift")
        self.assertNotIn("QuestifyPalette.accent", home_search)

    def test_screen_chrome_respects_nested_domain_and_hero_vs_bare_back(self):
        screen_style = read_swift("App/DesignSystem/CYScreenStyle.swift")
        self.assertIn("effectiveDomain", screen_style)
        self.assertIn("traitCollection.userInterfaceStyle", screen_style)
        self.assertIn("struct CYBareBackButton", screen_style)
        self.assertIn("struct CYHeroBackButton", screen_style)
        self.assertIn("func cyHeroPushedChrome", screen_style)
        self.assertIn("func cyPushedChrome", screen_style)
        self.assertIn("struct CYFooterBar", screen_style)

        # Full-bleed hero pushed chrome belongs ONLY on full-bleed hero cover views. Parity r2 (PC-C-1-9 / PC-B-1-8):
        # activity and topic heroes are inset list rows, so they keep the system back (no custom bar chevron).
        for rel in ("App/ActivityDetailView.swift", "App/TopicDetailView.swift"):
            detail = read_swift(rel)
            self.assertNotIn(".cyHeroPushedChrome(", detail)
            self.assertIn(".cyPushedChrome(domain: .player)", detail)
        # CLB-detail-32 (owner native-iOS rule 11-24): the club page keeps the system bar and system back.
        club = read_swift("App/ClubDetailView.swift")
        self.assertNotIn(".cyHeroChrome(", club)
        self.assertNotIn("CYHeroBackButton()", club)
        self.assertIn(".cyPushedChrome(domain: viewerDomain)", club)

        # Standard L2+ non-hero pushed detail views must not wrap back chevrons in glass hero pills.
        for rel in ("App/OfficialEventDetailView.swift", "App/DiscoveryTemplateDetailView.swift", "App/ProfileEditView.swift"):
            src = read_swift(rel)
            self.assertIn("cyPushedChrome", src)
            self.assertNotIn("cyHeroPushedChrome", src)

    def test_pinned_footer_bars_use_cy_footer_bar(self):
        for rel in (
            "App/ActivityDetailView.swift",
            "App/TopicXcxSections.swift",
            "App/RegistrationSheetView.swift",
            "App/OrderLifecycleView.swift",
            "App/ParticipantFormView.swift",
            "App/InvoiceLaunchApplyView.swift",
            "App/InvoiceLaunchTitleEditor.swift",
            "App/ProfileEditView.swift",
            "App/MerchantCityNodeCreateView.swift",
            "App/SquareDetailView.swift",
            "App/QuestifyMotionComponents.swift",
        ):
            self.assertIn("CYFooterBar", read_swift(rel), f"{rel} must use CYFooterBar for its pinned footer action bar.")
        # native r2: the project editor's pinned action bar is now the system bottom toolbar (same actions/ids).
        editor = read_swift("App/ProjectEditView.swift")
        bar = editor[editor.index("ToolbarItemGroup(placement: .bottomBar)"):]
        for ident in ("projectEdit.saveLocal", "projectEdit.saveCloudDraft", "projectEdit.submitServerDraft", "projectEdit.review"):
            self.assertIn(f'.accessibilityIdentifier("{ident}")', bar)

    def test_sheets_use_player_sheet_glass_and_no_cynight_chrome(self):
        # Native restyle (native-ios-r1 §3.4): sheets use the system corners and background in the role
        # appearance. cyPlayerSheetGlass() stays as the player-appearance sheet modifier at every call site below.
        role_theme = strip_swift_comments(read_swift("App/Theme/RoleTheme.swift"))
        self.assertIn("func cyPlayerSheetGlass()", role_theme)
        self.assertIn(".themeDomain(.player)", role_theme)
        self.assertNotIn("presentationCornerRadius", role_theme)

        confirm_sheet = read_swift("App/DesignSystem/CYConfirmSheet.swift")
        self.assertIn("CYColor.sheetGlass", confirm_sheet)
        self.assertNotIn("presentationCornerRadius", strip_swift_comments(confirm_sheet))
        self.assertNotIn("CYNight", strip_swift_comments(confirm_sheet))

        for rel in (
            "App/DesignSystem/CYAnchoredMenu.swift",
            "App/DesignSystem/CYSquareShareSheet.swift",
            "App/DesignSystem/CYSquareActivityPicker.swift",
            "App/DesignSystem/CYSquarePostDraftsSheet.swift",
            "App/DesignSystem/CYMapChrome.swift",
            "App/MemberReportProgressDetailView.swift",
        ):
            self.assertNotIn(
                "CYNight.",
                strip_swift_comments(read_swift(rel)),
                f"{rel} must not use CYNight colors on chrome or sheets.",
            )

        for rel in (
            "App/QuestifyApp.swift",
            "App/TopicDetailView.swift",
            "App/CatalogShareCardView.swift",
            "App/ContextualReviewComposer.swift",
            "App/JourneyLandingViews.swift",
            "App/PlayStoreDayMerchantView.swift",
        ):
            self.assertIn("cyPlayerSheetGlass", read_swift(rel), f"{rel} must apply cyPlayerSheetGlass() on sheets.")

        # restyle/r4-me-account (native iOS r1, spec §3.4): R4 sheets use the system sheet (no custom corner or
        # glass background) but stay in the player role's appearance.
        for rel in (
            "App/AccountView.swift",
            "App/TicketPassSheet.swift",
            "App/SettingsView.swift",
            "App/BundleDetailView.swift",
        ):
            src = strip_swift_comments(read_swift(rel))
            self.assertIn(".themeDomain(.player)", src, f"{rel} sheets must stay in the player role.")
            self.assertNotIn("presentationCornerRadius", src, f"{rel} must use the system sheet corners.")

        # Native restyle R1 (owner-approved, spec native-ios-r1 §2.2/§3.4): the player glass is retired on R1 sheets.
        # They keep the player domain tokens and use the one system sheet chrome (detents + drag indicator).
        for rel in ("App/ActivityDetailView.swift", "App/RegistrationSheetView.swift"):
            src = strip_swift_comments(read_swift(rel))
            self.assertNotIn("cyPlayerSheetGlass", src, f"{rel} uses the system sheet chrome.")
            self.assertIn(".themeDomain(.player)", src, f"{rel} keeps player tokens on its sheets.")
            self.assertIn(".cySheet(", src, f"{rel} uses cySheet detents and drag indicator.")


if __name__ == "__main__":
    unittest.main()
