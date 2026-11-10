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

## Batch 3 (77-81)
| File | Result |
| --- | --- |
| App/SessionNearbyTeamView.swift | done: CYLoadingStateView |
| App/SessionTeamViews.swift | skipped: pure session adapters/hooks, no UI |
| App/SocialActionViews.swift | done: CYLoadingStateView (review sheet already CYPillButton/CYStatusChip; toolbar close/done stay toolbar items) |
| App/SocialArticleContentView.swift | skipped: article text runs only, already tokenised, no controls/states |
| App/SocialInviteHistoryView.swift | done: CYLoadingStateView x2 (rest already kit) |

## Batch 4 (82-86)
| File | Result |
| --- | --- |
| App/SocialMessageMediaView.swift | done: CYLoadingStateView (load pill/hero already kit) |
| App/SocialPublicProfileView.swift | skipped: already kit (CYHeroHeader/CYStatusChip/CYPillButton), no remaining plain controls |
| App/TeamCreateView.swift | done: CYLoadingStateView |
| App/TeamOrientBoardView.swift | done: inline progress spinner given an accessibilityLabel; rest already kit |
| App/TeamPageParityViews.swift | skipped: already kit (CYPillButton/CYStatusChip), no remaining plain controls |

## Batch 5 (87-88, remainder)
| File | Result |
| --- | --- |
| App/TeamReformFlowViews.swift | done: CYLoadingStateView x2, CYPillButton secondary for check-result x2, labelled busy spinner; destructive/toolbar buttons kept |
| App/TicketWalletTeamView.swift | done: CYLoadingStateView; row button kept |

## Summary
22 files in range 67-88: 15 touched, 7 skipped (SessionClubPublicActivityListView, SessionTeamViews: no UI wrappers; PlayPlayerTeamStatusView, SocialArticleContentView, SocialPublicProfileView, TeamPageParityViews: already fully kit; OrdinaryIM counted as touched). No merchant-only files in the range. No new string keys (`docs/release/ui-strings-e4-tail3.json` is `[]`). No local builds.

Cloud result for 1ee610b54 (all 5 batches): Build - iOS and Test - iOS report `action_required` (workflow awaiting approval, not run; no red). Earlier per-batch runs were cancelled by the next push.
