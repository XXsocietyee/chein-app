"""App Store Guideline 1.2 (UGC completeness) source and grant verification."""
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class UGC12CompletenessContractTests(unittest.TestCase):
    def read(self, rel: str) -> str:
        return (ROOT / rel).read_text(encoding="utf-8")

    def test_xcstrings_translations_complete_en_and_zh_hans(self):
        data = json.loads(self.read("Resources/UGCSafety.xcstrings"))
        strings = data["strings"]
        self.assertGreaterEqual(len(strings), 25)
        for key, entry in strings.items():
            locs = entry["localizations"]
            self.assertEqual(set(locs.keys()), {"en", "zh-Hans"}, key)
            for lang in ("en", "zh-Hans"):
                unit = locs[lang]["stringUnit"]
                self.assertEqual(unit["state"], "translated", f"{key}.{lang}")
                self.assertTrue(unit["value"].strip(), f"{key}.{lang}")

    def test_both_grant_lists_include_ugc_safety_routes(self):
        china_cap = self.read("Core/ChinaReviewedRouteCapability.swift")
        player_leases = self.read("App/ReviewedPlayerWriteLeases.swift")
        required_routes = [
            "api/v1/community/capabilities",
            "api/v1/community/reports",
            "api/v1/community/appeals",
            "api/topic/report",
            "api/template/report",
            "api/template/personal-report",
            "api/creativesquare/report",
            "api/comment/report",
            "api/club/post/report",
            "api/club/post/comment/report",
            "api/club/governance/cases/report",
            "api/club/governance/cases/appeal",
            "api/merchant/reviews/report",
            "api/team/report",
            "api/external-game/reports",
            "api/mod-owned-report",
            "api/im/report",
            "api/im/block",
            "api/im/unblock",
            "api/native/blacklist/list",
            "api/ai/safety/precheck",
            "api/community-trust/reports/taxonomy",
            "api/community-trust/reports/mine",
        ]
        for route in required_routes:
            self.assertIn(f"/{route}", china_cap, f"ChinaReviewedRouteCapability missing /{route}")
            self.assertIn(route, player_leases, f"ReviewedPlayerWriteLeases missing {route}")

    def test_blocked_content_filtering_and_safety_menus_wired_across_surfaces(self):
        checks = {
            "App/QuestifyApp.swift": ".environment(\\.ugcSafetyContext, session.makeUGCSafetyContext())",
            "App/SquareBrowserView.swift": "UGCBlockedFilterContainer",
            "App/SquareDetailView.swift": "UGCBlockedFilterContainer",
            "App/TopicDetailView.swift": "UGCSafetyMenuButton",
            "App/TopicReviewsContent.swift": "UGCBlockedFilterContainer",
            "App/TopicXcxSections.swift": "UGCBlockedFilterContainer",
            "App/ActivityDetailView.swift": "UGCSafetyMenuButton",
            "App/ActivityReviewsSection.swift": "UGCBlockedFilterContainer",
            "App/ClubCommunityViews.swift": "UGCBlockedFilterContainer",
            "App/ClubPostDiscussion.swift": "UGCBlockedFilterContainer",
            "App/ClubChannelMessagingView.swift": "ugcSafety?.blockedStore.blockedMemberIDs",
            "App/MessagingHomeView.swift": "UGCBlockedFilterContainer",
            "App/MessagingHistoryView.swift": "UGCBlockedFilterContainer",
            "App/IMConversationSafetyViews.swift": "ugcSafety?.blockedStore.recordLocalBlock",
            "App/SocialPublicProfileView.swift": "UGCProfileSafetyActionsSection",
            "App/MemberIdentityAvatarView.swift": "UGCReviewSafetyFooter",
            "App/DiscoveryTemplateDetailView.swift": "UGCSafetyMenuButton",
            "App/PublicMerchantReviewsView.swift": "UGCBlockedFilterContainer",
            "App/WorkshopPurchasedLibraryView.swift": "UGCSafetyMenuButton",
            "App/RoamNearbyParityExtras.swift": "UGCReviewSafetyFooter",
        }
        for path, token in checks.items():
            self.assertIn(token, self.read(path), f"{path} missing {token}")

    def test_appsession_ratchet_not_violated(self):
        lines = len(self.read("App/AppSession.swift").splitlines())
        self.assertLessEqual(lines, 8171)


if __name__ == "__main__":
    unittest.main()
