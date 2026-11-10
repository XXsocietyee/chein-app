# ui-tail-e1 (worker from the START of the list)

Source list: `/Users/fanning/chengyin-refs/tail-e1.txt` (88 files). Batches of 5, in file order. Not compiled locally; cloud Build+Test per push. e1 works from the end.

## Batch 1
| File | Result |
| --- | --- |
| App/ActivityBrowserView.swift | done: CYEmptyState (unavailable/error+retry/empty), CYPillButton load-more/retry; root keeps nav title (searchable) |
| App/ActivityDetailView.swift | done: CYEmptyState states, CYPillButton primary bottom action + club gate, label helper removed |
| App/ActivityEditingView.swift | done: CYHeroHeader (one title), cyGroupedSurface, CYPillButton actions (one primary per section) |
| App/ActivityHostCancelView.swift | done: CYLoadingStateView, CYStatusChip blocked/cancelled, CYPillButton recheck/done; destructive confirm stays role button + confirmationDialog |
| App/ApprovedTopicReviewRequestView.swift | done: CYLoadingStateView, CYPillButton review/submit primary, others secondary |

## Batch 2
| File | Result |
| --- | --- |
| App/BundleAppealView.swift | done: CYPillButton submit (primary) / check / resend, CYLoadingStateView; embedded form, no own title so no hero |
| App/BundleCancelView.swift | done: CYHeroHeader, cyGroupedSurface, CYPillButton, CYLoadingStateView; destructive confirm stays role button |
| App/BundleOrderStatusView.swift | done: CYPillButton recheck, cyGroupedSurface; no own title (embedded) |
| App/BundleRedeemResultView.swift | done: CYHeroHeader, CYLoadingStateView, CYPillButton retry |
| App/BundleRefundQuoteView.swift | done: CYHeroHeader, monospaced amounts, cyGroupedSurface (read-only, no action by design) |

## Batch 3
| File | Result |
| --- | --- |
| App/BundleRenewalIntentView.swift | done: CYHeroHeader, CYLoadingStateView, CYPillButton submit (primary) / recover / retry |
| App/BundleReservationsView.swift | done: CYEmptyState empty, monospaced start time, cyGroupedSurface (display only) |
| App/BundleReserveWindowView.swift | done: CYPillButton choose (embedded Section, no own title) |
| App/BundleReviewComposeView.swift | done: CYLoadingStateView, CYPillButton submit/check/resend, monospaced counter |
| App/BundleTransferClaimView.swift | done: CYPillButton claim, CYLoadingStateView, cyGroupedSurface |
| App/BundleTransferSendView.swift | done (list item 16): CYLoadingStateView, CYPillButton confirm (primary) / recover; revoke stays destructive role button; cyGroupedSurface |
| App/BundleWalletView.swift | done (list item 17): CYEmptyState noDetail, monospaced totals, cyGroupedSurface |

(Batches are 5 files in list order; items 16-17 were done together with batch 3 and count toward batch 4.)

## Batch 4 (remaining items 18-20)
| File | Result |
| --- | --- |
| App/DiscoveryHomeView.swift | done: CYEmptyState (unavailable/empty), CYLoadingStateView; root keeps nav title |
| App/DiscoveryPlayTemplatePresentationView.swift | done: monospaced use count (Section fragment, no own chrome) |
| App/DiscoveryTemplateBrowserView+Port.swift | done: CYLoadingStateView, CYPillButton empty refresh; cover thumb left (private fallback tile, no behaviour change) |

## Batch 5
| File | Result |
| --- | --- |
| App/MemberTemplateDetailView.swift | done: CYLoadingStateView, CYStatusChip draft/published, CYPillButton retry; keeps nav title (content title is the template's own) |
| App/ModInstallationTemplateEditorView.swift | done: CYHeroHeader, cyGroupedSurface, CYPillButton (save primary, others secondary/tertiary), confirm primary in review sheet |
| App/NearbyMapDiscoveryView.swift | done: CYLoadingStateView status, CYPillButton clear-tag; map/model code untouched |
| App/OfficialActionViews.swift | done: hero in publish/broadcast/invite editors, CYPillButton review/confirm (one primary each), CYLoadingStateView |
| App/OfficialEventsBrowserView.swift | done: CYEmptyState empty list; search/filter untouched |
