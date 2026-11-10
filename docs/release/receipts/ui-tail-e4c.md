# UI tail e4c (social/club/IM/coop, list items 67-88 of tail-e3.txt)
Notes: most files already used kit tokens/components from earlier waves; this pass swaps remaining ProgressView -> CYLoadingStateView, plain text Buttons -> CYPillButton, ContentUnavailableView -> CYEmptyState, adds CYHeroHeader where a screen owned its nav title. No behaviour change, identifiers kept.

## Batch 1 (67-71)
| File | Result |
| --- | --- |
| App/NativeFriendProgressCardView.swift | done: CYLoadingStateView, CYPillButton refresh (secondary) |
| App/NativeFriendRemovalView.swift | done: hero (one visible title), CYLoadingStateView, CYPillButton recover (primary) / retry (secondary), CYEmptyState; destructive review button kept |
| App/NearbyTeamMapViews.swift | done: CYLoadingStateView (rest already kit) |
| App/NearbyTeamViews.swift | done: CYLoadingStateView x4 (toolbar refresh stays a toolbar item; rest already kit) |
| App/OrdinaryIMSendReceiptRecoveryView.swift | done: CYLoadingStateView (pill buttons/chip already kit) |

## Batch 2 (72-76)
| File | Result |
| --- | --- |
| App/PlayAdvancedTeamViews.swift | done: CYLoadingStateView for leaderboard loading (controls/chips/empty already kit) |
| App/PlayPlayerTeamStatusView.swift | skipped: already kit (CYStatusChip rows inside parent Section), nothing to change |
| App/ProfileFollowListView.swift | done: CYLoadingStateView x2 (hero/empty/chips/pill already kit) |
| App/RoamNearbyTeamsView.swift | done: CYLoadingStateView for inactive-scene placeholder |
| App/SessionClubPublicActivityListView.swift | skipped: pure wrapper, no UI |
