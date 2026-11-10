# ui-tail-e3

Social tail, list `/Users/fanning/chengyin-refs/tail-e3.txt` (88 files), batches of 5 in file order. Presentation only; no behaviour or Core edits. New strings go to `docs/release/ui-strings-e3t.json`. Not compiled locally; each push is one cloud Build+Test.

## Batch 1
Done: ClubAIDesignFeedbackViews, ClubActionOriginalRecoveryView, ClubActivityReportView, ClubBadgeManagementView, ClubChatEntryView.
Skipped: none.

## Batch 2
Done: ClubCheckinRailView, ClubCommunityViews, ClubContextualViews, ClubDirectoryView, ClubEnrollmentView. ClubEmptyState (ClubComponents) now renders CYEmptyState.
Skipped: none.

Coordinator note (msg_627cd7eeaa45): from batch 3 the list is processed in REVERSE order, and files touched on origin/ui/cloud-* are skipped as cloud-owned. At batch 3 no ui/cloud-* branch had any diff against ui/main.

## Batch 3 (reverse: last 5 files)
Done: TicketWalletTeamView, TeamReformFlowViews, TeamPageParityViews, TeamOrientBoardView, TeamCreateView.
Skipped: none.
Xcode Cloud on batch 1/2 commits: Test - iOS "action_required, 2 errors" are both GLTFKit2 vendor module errors ("failed to emit precompiled module", "unsupported Swift architecture"), not from App sources.
Batch 1+2 Build - iOS on cbfcaa411: success.

## Batch 4 (reverse)
Done: SocialPublicProfileView, SocialMessageMediaView, SocialInviteHistoryView, SocialArticleContentView, SocialActionViews.
Skipped: none.
Cloud-owned (diff on origin/ui/cloud-*), skipped from here on: ClubGovernanceViews, ClubManagementView, ClubOpsCustomerViews, CooperationBrowserView. ClubEnrollmentView was already restyled in batch 2 before the cloud lane touched it; expect a merge conflict to resolve in favour of one version.

## Batch 5 (reverse)
Done: ProfileFollowListView, SessionNearbyTeamView (stale state).
Skipped (host/adapter, no visible presentation of their own): SessionTeamViews, SessionClubPublicActivityListView, RoamNearbyTeamsView.

## Batch 6 (reverse)
Done: NearbyTeamMapViews, NearbyTeamViews, OrdinaryIMSendReceiptRecoveryView, PlayAdvancedTeamViews, PlayPlayerTeamStatusView.
Skipped: none.

## Batch 7 (reverse)
Done: NativeFriendRemovalView, NativeFriendProgressCardView, NativeFriendPickerView, NativeFriendMetadataView, NativeFriendHomeView.
Skipped: none.

## Batch 8 (reverse)
Done: NativeClubNotificationDefaultView, NativeChannelMessageSearchView, NativeChannelMessageRevisionView, NativeChannelMessagePinsView, NativeChannelMessageContextView.
Skipped: none.

## Batch 9 (reverse)
Done: NativeChannelMessageBubbleView, NativeChannelMessageAttachmentView, NPCChatDataView, MessagingMessageDetailView, IMVoiceViews. IMFlowStateMessage (shared IM flow state row) now renders on CYPalette soft fills.
Skipped: none.

## Batch 10 (reverse)
Done: IMVideoViews, IMFileViews, IMExpandedViews, IMCoopInviteStripView, IMConversationSafetyViews.
Skipped: none.

## Batch 11 (reverse)
Done: IMConversationRowActionsView, IMConversationReadAllView, IMCardPreviewViews, GroupPollOriginalResultView, IMStaticLocationCardView.
Skipped: none.

## Batch 12 (reverse)
Done: CooperationDirectoryViews, CoopWithdrawShellViews, CoopSettlementDetailView, CoopRelationDiscoveryView, CoopFinanceProfitView.
Cloud-owned, skipped (diff on origin/ui/cloud-*): ClubEventCalendarView, ClubGovernanceFeedPostView (plus the earlier ClubGovernanceViews, ClubManagementView, ClubOpsCustomerViews, CooperationBrowserView). ClubContextualViews, ClubDirectoryView and ClubEnrollmentView were restyled here first and are also touched by a cloud lane: expect merge conflicts there.

## Batch 13 (reverse)
Done: ClubTerminalSessionView, ClubTabParityViews, ClubStoryViews, ClubStatsOverviewView, ClubSessionQuickStartView.
Skipped: none.

## Batch 14 (reverse)
Done: ClubPublicRosterView, ClubPublicActivityListView, ClubProjectLaunchView, ClubPostReferenceView, ClubOwnerRefundFixtureView (DEBUG-only fixture host; buttons moved to CYPillButton).
Skipped: none.
Build - iOS on batch 14 head (2a... all batches 1-14): success. Test - iOS action_required with 2 errors that are the GLTFKit2 vendor module errors only.

## Batch 15 (reverse)
Done: ClubOpsSettlementViews, ClubOpsJoinNotifyViews, ClubOpsEventView, ClubOperationsReviewView, ClubNotificationAudienceView.
Skipped: none.

## Batch 16 (reverse; last of the list)
Done: ClubMembersView, ClubMemberReportView, ClubLeadProgressView, ClubLeadPrimaryActionView, ClubInvitationFeedbackView, ClubHomeView.
Skipped: none.
