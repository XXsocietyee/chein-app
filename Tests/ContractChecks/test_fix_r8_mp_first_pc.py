"""fix/r8-mp-first-pc: source pins for MP-first player-content rows (owner 2026-11-25). Does not execute Swift."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text()


class MPFirstPlayerContentPins(unittest.TestCase):
    def test_merchant_content_approval_defaults_open_and_transport_admits(self):
        content = read('Core/MerchantContentService.swift')
        self.assertIn('func permits(_ command: MerchantContentCommand) -> Bool\n', content)
        self.assertIn('public static let closed = MerchantContentWriteApproval(', content)
        self.assertIn('case .claim, .cancelClaim, .cityStatus, .place: return MerchantCoopLiveWrites.cityNode', content)
        self.assertIn('case .station: return false', content)
        self.assertNotIn('chapterWithdraw: Bool = false', content)
        self.assertIn('MerchantContentMPWriteRoute.accepts(request, baseURL: api.baseURL, token: captured.token)', read('App/AppCompositionRoot.swift'))

    def test_publisher_grants_issue_mp_writes_not_refunds(self):
        core = read('Core/RuntimeDependencyConfiguration.swift')
        self.assertIn('PublisherLifecycleGrants(reads: endpoints, pricing: endpoints, ownership: endpoints, graduation: endpoints)', core)
        self.assertNotIn('cancellationRefunds: endpoints', core)
        self.assertIn('publisherReads: true, playReadApprovalID: UUID())', read('App/ReviewedPlayerWriteLeases.swift'))

    def test_topic_favorite_is_mounted(self):
        detail = read('App/TopicDetailView.swift')
        self.assertIn('onToggleFavorite: favoriteHost == nil ? nil : { toggleFavorite(topicID: value.id) }', detail)
        for host in ('App/PlatformConsumerSessionOwner.swift', 'App/SessionTopicBrowserView.swift'):
            self.assertIn('.environment(\\.topicFavoriteHostFactory, { session.makeTopicFavoriteHost() })', read(host))

    def test_ui_rows_follow_mp(self):
        self.assertIn('allowsRead: { true }', read('App/SessionWalletCommerceView.swift'))  # R8-PC-D4-1
        self.assertIn('AnyView(WithdrawalSupportContactView())', read('App/WalletCommerceViews.swift'))  # R7-PC-D5-1
        self.assertIn('registrationEnabled: true)', read('App/RoamNearbyEventsDetailHost.swift'))  # R7-PC-C1-10
        official = read('App/OfficialPrivateViews.swift')  # R7-PC-C6-1
        self.assertNotIn('NavigationLink("officialAction.publish")', official)
        self.assertNotIn('official.published.eventsEmptyDetail', official)
        self.assertIn('private var hidesMerchants: Bool { false }', read('App/GlobalSearchView.swift'))  # R7-PC-A3-1
        home = read('App/SessionHomeFeedView.swift')  # R8-PC-A1-1
        self.assertIn('homeCityLabel = city', home)
        self.assertNotIn('session.roamArea = RoamSearchArea(coordinate: centre, label: city)', home)
        self.assertIn('templateTabScope == .merchant(canManageProjects: true)', read('App/DiscoveryTemplateBrowserView.swift'))  # R7-PC-A2-8
        bounty = read('App/VideoBountyView.swift')  # R7-PC-D7-1
        self.assertNotIn('if tab == .submissions { campaignAttribution }', bounty)
        self.assertNotIn('"videoBounty.attribution.\\(row.id)"', bounty)
        self.assertNotIn('Text("guideXcx.detailDisclaimer")', read('App/SocialGuideViews.swift'))  # R7-PC-D3-5


if __name__ == '__main__':
    unittest.main()
