# UI tail e4c (social/club/IM/coop, list items 67-88 of tail-e3.txt)
Notes: most files already used kit tokens/components from earlier waves; this pass swaps remaining ProgressView -> CYLoadingStateView, plain text Buttons -> CYPillButton, ContentUnavailableView -> CYEmptyState, adds CYHeroHeader where a screen owned its nav title. No behaviour change, identifiers kept.

## Batch 1 (67-71)
| File | Result |
| --- | --- |
| App/NativeFriendProgressCardView.swift | done: CYLoadingStateView, CYPillButton refresh (secondary) |
| App/NativeFriendRemovalView.swift | done: hero (one visible title), CYLoadingStateView, CYPillButton recover (primary) / retry (secondary), CYEmptyState; destructive review button kept |
| App/NearbyTeamMapViews.swift | done: CYLoadingStateView (rest already kit) |
| App/NearbyTeamViews.swift | see batch result below |
| App/OrdinaryIMSendReceiptRecoveryView.swift | done: CYLoadingStateView (pill buttons/chip already kit) |
