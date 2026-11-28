"""FP-H3 (App Store 1.2): which UGC surfaces expose a report entry, and which still do not.

COVERED surfaces must keep a report action. GAPS are surfaces with user-generated content and no report entry in
the native UI. They are listed, not hidden: the Core write contracts exist (`api/topic/report`,
`api/comment/report`, activity review and avatar reports are not wired), but a UI entry needs a reviewed transport
grant composed in AppSession (G1-owned), so it is not added here. When a gap gets an entry, move it to COVERED;
this test then fails until the list is updated, so the list cannot go stale."""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]

COVERED = {
    'App/SquareDetailView.swift': 'posts and comments',
    'App/SquareBrowserView.swift': 'square feed cards and blocked-author filtering',
    'App/ClubChannelMessagingView.swift': 'club channel messages and members',
    'App/ClubCommunityViews.swift': 'club posts and comments',
    'App/PublicMerchantReviewsView.swift': 'merchant reviews',
    'Core/IMConversationSafety.swift': 'IM conversations',
    'App/TopicDetailView.swift': 'topic detail (api/topic/report)',
    'App/TopicXcxSections.swift': 'topic lineup and node templates',
    'App/TopicReviewsContent.swift': 'topic review previews',
    'App/ActivityDetailView.swift': 'activity detail (api/v1/community/reports ACTIVITY)',
    'App/ActivityReviewsSection.swift': 'activity reviews',
    'App/ClubPostDiscussion.swift': 'club post discussion comments',
    'App/MemberIdentityAvatarView.swift': 'member avatars',
    'App/SocialPublicProfileView.swift': 'public profiles (MEMBER report and block)',
    'App/DiscoveryTemplateDetailView.swift': 'creator and personal templates',
    'App/ExternalGameReviewScreens.swift': 'external games',
    'App/WorkshopPurchasedLibraryView.swift': 'workshop purchased mods',
    'App/RoamNearbyParityExtras.swift': 'place player reviews (api/comment/list owner type 4)',
}
GAPS = {}


class UgcSurfaceReportEntries(unittest.TestCase):
    def test_covered_surfaces_keep_a_report_action(self):
        for path in COVERED:
            self.assertIn('report', (ROOT / path).read_text().lower(), path)

    def test_gaps_are_exactly_the_surfaces_without_a_report_entry(self):
        for path, label in GAPS.items():
            text = (ROOT / path).read_text().lower()
            self.assertNotIn('report', text, f'{path} ({label}) now has a report entry: move it to COVERED')

    def test_gap_list_is_recorded_in_the_parity_docs(self):
        text = (ROOT / 'docs/parity/fix1-ugc-report-gaps.md').read_text()
        for path in GAPS:
            self.assertIn(path, text)


if __name__ == '__main__':
    unittest.main()
