# UI tail (e1 family) receipt

Presentation only, no behaviour or Core edits. NOT COMPILED locally; cloud Build+Test per push.
Shared helpers: `e1HeroRow()` / `e1ActionRow()` in App/E1CommerceComponents.swift (Form/List hero + pill rows).

## Batch 1
- ActivityBrowserView: CUV states -> CYEmptyState (unavailable/failed/empty, ids kept)
- ActivityDetailView: sign-in / load-failed / stale states -> CYEmptyState (club gate kept: custom action)
- ActivityEditingView: hero title, grouped surface, pills (review primary), one title
- ActivityHostCancelView: hero, skeleton loading, pills (confirm primary), grouped surface
- ApprovedTopicReviewRequestView: hero (x2), skeleton loading, pills, grouped surface

## Batch 2
- BundleAppealView, BundleCancelView, BundleOrderStatusView (view only), BundleRedeemResultView, BundleRefundQuoteView: hero title, grouped surface, pill actions (one primary), skeleton loading, status icons/chips, tabular values. BundleRefundQuoteView stays action-free (read-only quote).

## Batch 3
- BundleRenewalIntentView, BundleReservationsView (rows with icon + empty state), BundleReserveWindowView (fragment: pill only, host owns the title), BundleReviewComposeView, BundleTransferClaimView: hero, grouped surface, pills (one primary), skeleton loading.

## Batch 4
- BundleTransferSendView, BundleWalletView, DiscoveryHomeView, DiscoveryPlayTemplatePresentationView (Section fragment: tokens only), DiscoveryTemplateBrowserView+Port (cover thumb / syncing row / empty refresh tokens + skeleton + pill): hero, grouped surface, kit rows, empty states, pills.

## Batch 5
- MemberTemplateDetailView, ModInstallationTemplateEditorView, NearbyMapDiscoveryView (controls/status/row pieces), OfficialActionViews (action sheet, publish/broadcast/invite editors; organizer-side = player surface, dark), OfficialEventsBrowserView: hero, grouped surface, pills, skeletons, CYEmptyState, tokens.

## Batch 6
- OrderPassPreviewView, OwnedTemplateConfigurationView, OwnedTemplateSensorConfigurationView (Section fragment: tokens), OwnedTopicCoverAuthorView (13 borderless buttons -> pills, one primary per section), OwnedTopicCoverImageView: hero, grouped surface, pills, skeleton, rounded image previews.

## Batch 7
- ParticipantManagementDetailView, PlayFinishRouteCardView, PlayRouteMapView (list chrome only; map annotations untouched), PrivateHomeView, ProfileOrderMeetingPointView: hero, pills, CYEmptyState, skeletons, kit tokens on the finish route card.

## Batch 8
- ProjectStoryTemplateView (rows -> CYListRow, pills), PublisherIdentityRegistrationView (inline Section: pills + skeleton), SearchMapDetailViews (hero name, loading, chip), SearchMapExplorerView (LIGHT touch only: ContentUnavailableView -> CYEmptyState, spinners -> skeletons, nearby detail hero; the map/filters chrome is d6-owned and left alone).
- RegistrationSheetView: already restyled in earlier e1 passes (ticket card, pinned bar, CY kit); no change.

## Batch 9
- DONE SearchRoutePreviewView: hero name, primary pill link for walking nav, numbered step rows with tabular numerals, skeleton, tokens. (New shared `CYPillButtonLabel` in E1CommerceComponents.swift.)
- SKIPPED SecondRegistrationStatsView: operator/merchant analytics report (rates, exclusions), debug-fixture only, no player surface (light/merchant-side).
- SKIPPED SessionGlobalSearchView, SessionHomeFeedView, SessionTopicBrowserView, SessionTopicSelfPlayView: pure host wiring (environment injection, toolbar menu entries, `Session*` is on the never-edit list); no restylable view content.
