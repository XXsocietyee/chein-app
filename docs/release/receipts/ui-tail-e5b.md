# ui-tail-e5b receipt (e3 list items 45-88; NOT COMPILED locally; cloud Build+Test is the check)

New string keys: none so far (existing keys reused; new ones go to `docs/release/ui-strings-e5-tail2.json`).

## Batch 1
- IMConversationReadAllView: done (CYHeroHeader, CYPillButton primary)
- IMConversationRowActionsView: done (CYHeroHeader, CYPillButton primary + secondary)
- IMConversationSafetyViews: done (CYHeroHeader, CYPillButton; destructive confirm stays a role:.destructive Button)
- IMCoopInviteStripView: done (CYSkeleton, CYStatusChip, CYPillButton)
- IMExpandedViews: done (CYHeroHeader on six screens, CYPillButton primaries)

## Batch 2
- IMFileViews: done (CYHeroHeader x2, CYPillButton primaries)
- IMStaticLocationCardView: done (CYCoverArt replaces raw gradient, a11y label on show-map control)
- IMVideoViews: done (CYHeroHeader x2, CYPillButton primaries)
- IMVoiceViews: done (CYHeroHeader x2, CYPillButton primaries)
- MessagingMessageDetailView: done (CYHeroHeader on detail + review sheet)

## Batch 3 (also covers the first two files of batch 4)
- NPCChatDataView: done (CYHeroHeader x2, CYPillButton reload)
- NativeChannelMessageAttachmentView: done (CYEmptyState)
- NativeChannelMessageBubbleView: done (CYStatusChip for the edited mark)
- NativeChannelMessageContextView: done (CYHeroHeader, CYSkeleton, CYPillButton retry)
- NativeChannelMessagePinsView: done (CYHeroHeader, CYSkeleton, CYPillButton reload)
- NativeChannelMessageRevisionView: done (CYHeroHeader, CYSkeleton, CYPillButton retry)
- NativeChannelMessageSearchView: done (CYHeroHeader, CYSkeleton, CYPillButton run + retry)

## Batch 4 (items 62-67)
- NativeClubNotificationDefaultView: done (CYHeroHeader, CYSkeleton, CYPillButton)
- NativeFriendDirectoryView: done (CYHeroHeader x2, CYSkeleton, CYEmptyState, CYPillButton)
- NativeFriendHomeView: done (CYHeroHeader x3, CYSkeleton, CYEmptyState, CYPillButton)
- NativeFriendMetadataView: done (CYHeroHeader, CYSkeleton, CYPillButton primary)
- NativeFriendPickerView: done (CYPillButton primary)
- NativeFriendProgressCardView: done (CYSkeleton, CYPillButton)
- NativeFriendRemovalView: done (CYHeroHeader, CYSkeleton, CYEmptyState, CYPillButton; destructive review stays a role:.destructive Button)

## Batch 5 (items 68-72) and the rest of the list (73-88)
The list was computed before the cloud lanes landed: most of these already carry the kit. Work done here is the remaining gaps only (loading spinners to CYSkeleton with the same VoiceOver label, hero title where a raw nav title was left).
- NearbyTeamMapViews: done (CYSkeleton for recruiting load)
- NearbyTeamViews: done (CYSkeleton x4; hero already present)
- OrdinaryIMSendReceiptRecoveryView: done (CYSkeleton)
- PlayAdvancedTeamViews: done (CYHeroHeader on team review sheet, CYSkeleton)
- PlayPlayerTeamStatusView: skipped, already kit (CYStatusChip)
- ProfileFollowListView: done (CYSkeleton x2; hero already present)
- RoamNearbyTeamsView: done (CYSkeleton)
- SessionClubPublicActivityListView: skipped, pure adapter host with no UI
- SessionNearbyTeamView: done (CYSkeleton)
- SessionTeamViews: skipped, pure adapter hosts with no UI
- SocialActionViews: done (CYSkeleton)
- SocialArticleContentView: skipped, already kit (CYEmptyState, CYStatusChip)
- SocialInviteHistoryView: done (CYSkeleton x2)
- SocialMessageMediaView: done (CYSkeleton)
- SocialPublicProfileView: skipped, already kit (cyHeroScreen, CYPillButton)
- TeamCreateView: done (CYSkeleton)
- TeamOrientBoardView: done (CYHeroHeader on report sheet)
- TeamPageParityViews: skipped, already kit (CYPillButton)
- TeamReformFlowViews: done (CYSkeleton x3)
- TicketWalletTeamView: done (CYSkeleton)
- (NativeFriendRemovalView is item 67 and is in batch 4.)

No merchant-only files were in items 45-88. No new string keys: `docs/release/ui-strings-e5-tail2.json` holds an empty array.
