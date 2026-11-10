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
