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
