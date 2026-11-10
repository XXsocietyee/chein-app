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


## e4-lane worker pass (second worker, same list)
Coordinator brief said e1 works from the END; ui/main already carried the e1 worker's batches 1-9 (same start-of-list files) when this worker merged, so this worker's duplicate restyles of items 1-41 were dropped in favour of the ui/main versions (merge took ui/main on every conflict). Only these non-overlapping changes were kept:
| File | Result |
| --- | --- |
| App/RegistrationSheetView.swift | CYPillButton for 11 secondary actions, CYLoadingStateView for 8 spinners (checkout bar/alerts untouched) |
| App/ShopNPCScriptedGuideView.swift | CYPillButton return |
| App/SquareRelatedTopicView.swift | CYPillButton view-topic |
| App/SupportTicketReadView.swift | CYHeroHeader, cyGroupedSurface, 6 CYPillButton, CYLoadingStateView |
| App/SessionTopicSelfPlayView.swift, App/ShopNPCFixtureView.swift (#if DEBUG) | skipped: wrapper / DEBUG fixture |

## Second worker, range 66-88 (coordinator: e1 owns 42-65)
No file of 66-88 is on a ui/cloud-* branch.
### Batch A (66-70)
| File | Result |
| --- | --- |
| App/TemplatePreferencePreviewView.swift | skipped: result-row fragment inside host Form, no title/buttons/states |
| App/TemplateReactionRehearsalView.swift | done: CYHeroHeader, cyGroupedSurface, CYPillButton reload/reset |
| App/TemplateReasoningRehearsalView.swift | done: CYHeroHeader (table key), CYPillButton retry/reload |
| App/TemplateRootAuthoringView.swift | done (light): CYPillButton add actions; editor titles stay in nav bar (EditButton toolbar), destructive clear stays role button |
| App/TemplateRootRehearsalView.swift | done: CYHeroHeader x2, CYPillButton evaluate (primary)/reset |
### Batch B (71-75)
| File | Result |
| --- | --- |
| App/TemplateSampleBrowserView.swift | done: CYHeroHeader, cyGroupedSurface, CYPillButton preview |
| App/TemplateSensorDraftConfigurationView.swift | done: CYHeroHeader, CYEmptyState unavailable, cyGroupedSurface (preview screen only) |
| App/TemplateSensorRehearsalView.swift | done: CYHeroHeader, CYPillButton advance (primary)/reload; determinate ProgressView kept |
| App/TemplateTimerRehearsalView.swift | done: CYHeroHeader (dynamic kind title), CYPillButton start/resume/again primary, rest secondary |
| App/TopicDetailView.swift | done: CYLoadingStateView, CYPillButton (paywall unlock primary, review/self-play secondary) |
### Batch C (76-80)
| File | Result |
| --- | --- |
| App/TopicSessionSelectionView.swift | done: CYEmptyState for missing-data/empty (ids kept); activity rows and toolbar close unchanged |
| App/TopicThemeRecordsView.swift | done: CYLoadingStateView, CYPillButton reload |
| App/WorkshopCommerceView.swift | done (partial): 9 refresh/more/cancel/return buttons to CYPillButton, CYLoadingStateView; buttons with custom full-width labels/modifiers and the tabled unavailable ContentUnavailableView left (CYEmptyState has no tabled detail) |
| App/WorkshopCreatorConsentView.swift | done: CYPillButton declare (primary)/another/refresh, CYLoadingStateView |
| App/WorkshopCreatorPendingView.swift | done: CYPillButton retry/another/more/refresh/author, CYLoadingStateView |
### Batch D (81-88)
| File | Result |
| --- | --- |
| App/WorkshopLicenseLibraryView.swift | done: CYLoadingStateView, CYPillButton refresh/next/reopen |
| App/WorkshopModUpgradeSheetView.swift | done: CYPillButton confirm (primary), success token colour |
| App/WorkshopOwnedLibraryView.swift | done (partial): CYLoadingStateView x2, CYPillButton retry/open-package; tabled ContentUnavailableView unavailable kept |
| App/WorkshopOwnedPackageView.swift | done: CYLoadingStateView, CYPillButton retry |
| App/WorkshopPaidInstallView.swift | done: CYLoadingStateView x3, CYPillButton confirm (primary) + 9 secondary; Back/close toolbar items and role .cancel button untouched |
| App/WorkshopPaidInstalledTextView.swift | done: CYLoadingStateView, CYPillButton retry |
| App/WorkshopPaidProfessionalView.swift | done: CYLoadingStateView, CYPillButton (start review / confirm create primary, rest secondary) |
| App/WorkshopPurchasedLibraryView.swift | done (partial): CYLoadingStateView, CYPillButton retry; tabled unavailable view kept |

## Summary (second worker, items 66-88)
23 files: 21 restyled (some partially, as noted), 2 skipped (TemplatePreferencePreviewView fragment; none merchant-only, none on ui/cloud-*). No new string keys (all existing keys reused); `docs/release/ui-strings-e1-tail.json` is `[]`. Items 1-41 were duplicated work and dropped in favour of ui/main; 42-65 belong to e1.

## Coordinator follow-up: Favorites > Posts
App/AccountCollectionFavoritesView.swift: each post is now its own elevated card (16 padding, 16 radius, hairline border, 12pt gap via the existing card row); the offline "Example content" header is a one-line CYStatusChip (was a clipped caption row); App/SquareComponents.swift: compact post text limited to 3 lines (was 5). Not done: the mixed zh/en synthetic post text comes from Core/SquareSyntheticFixtures.swift (Core is off limits for this task); em dash for unknown like/comment counts needs an optional count in the model, not a presentation change.
