# Receipt: domain audit (`ui/cur-domain-audit`)

Screens that did not set the app domain now call the existing helper `cyDomainScreen` (`themeDomain` + `cyDomainPageBackground` + `CYDomainPalette` brand tint). Player and play stay dark. Merchant, coop, and creator stay light. The system color scheme is not the switch.

No second theme switch. No per-control recolor. No copy or layout change. `RegionalLaunchConfiguration`, `AppSession`, and `AppCompositionRoot` were not edited. `ReviewedAreaSwitch` was not redeclared. `OwnerDecisionFixtureHost` was not added. The contract baseline was not edited. Hash-pinned sources were left in place.

## Counts

- Changed screens: **188** (dark 133, light 55)
  - player `.player` dark: 127
  - merchant and coop `.merchant` light: 38
  - creator `.topicEditor` light: 17
  - play runtime `.game` dark: 6
- Left screens: **272**
  - hash-pinned file: 76
  - ambiguous domain: 39 (domain —)
  - unknown role: 157 (domain —)

## Huge bodies split

`MessagingMessageDetailView` and `NativeAttributeAuthorView` moved their existing body into `cyDomainBody` and apply `cyDomainScreen` on the short body.

## Checks

- `python3 -B tools/check_design_lint.py` PASS (1634 App Swift files, allowlist unchanged)
- `python3 -B tools/check_scaffold.py` PASS (262 pages, structural checks)
- `swiftc` was not run

## Changed

| Screen | File | Domain | Appearance |
| --- | --- | --- | --- |
| `CityNeutralTaskRuntimeHostView` | `App/CityNeutralTaskRuntimeHostView.swift` | `.game` | dark |
| `CityOnsiteTaskRuntimeHostView` | `App/CityOnsiteTaskRuntimeHostView.swift` | `.game` | dark |
| `PlayDirectorView` | `App/PlayDirectorView.swift` | `.game` | dark |
| `PlayKitAlbumView` | `App/PlayKitAlbumView.swift` | `.game` | dark |
| `PlayKitAccusationView` | `App/PlayKitQuestoViews.swift` | `.game` | dark |
| `PlayKitHangmanView` | `App/PlayKitQuestoViews.swift` | `.game` | dark |
| `BeGapMerchantHubView` | `App/BeGapMerchantScreens.swift` | `.merchant` | light |
| `CityMerchantValueBenefitView` | `App/CityMerchantValueView.swift` | `.merchant` | light |
| `CityMerchantValueView` | `App/CityMerchantValueView.swift` | `.merchant` | light |
| `CoopPeerCreditView` | `App/CooperationContextualViews.swift` | `.merchant` | light |
| `CooperationPoolView` | `App/CooperationDirectoryViews.swift` | `.merchant` | light |
| `CoopFlowSupplyManagementView` | `App/CooperationFlowEditors.swift` | `.merchant` | light |
| `CoopFlowReadView` | `App/CooperationFlowWorkbench.swift` | `.merchant` | light |
| `CouponManagementDetailView` | `App/CouponManagementView.swift` | `.merchant` | light |
| `SessionMerchantAcceptedProjectView` | `App/MerchantAcceptedProjectView.swift` | `.merchant` | light |
| `MerchantAuthoringView` | `App/MerchantAuthoringView.swift` | `.merchant` | light |
| `MerchantChapterInvitationDetailView` | `App/MerchantChapterInvitationViews.swift` | `.merchant` | light |
| `SessionMerchantAnchorView` | `App/MerchantDeskAnchorSection.swift` | `.merchant` | light |
| `Key` | `App/MerchantDiscoverView.swift` | `.merchant` | light |
| `MerchantGameNodeEntryView` | `App/MerchantGameNodeEntryView.swift` | `.merchant` | light |
| `MerchantGameNodeView` | `App/MerchantGameNodeView.swift` | `.merchant` | light |
| `SessionMerchantLedgerInboxView` | `App/MerchantLedgerInboxNavigation.swift` | `.merchant` | light |
| `MerchantSettlementBatchDetailView` | `App/MerchantLedgerParityViews.swift` | `.merchant` | light |
| `MerchantLedgerBatchDetailView` | `App/MerchantLedgerSettlementOverview.swift` | `.merchant` | light |
| `MerchantNPCMapPointManualView` | `App/MerchantNPCMapPointView.swift` | `.merchant` | light |
| `MerchantNPCMapPointReadOnlyView` | `App/MerchantNPCMapPointView.swift` | `.merchant` | light |
| `MerchantOfferWithdrawalOriginalRecoveryView` | `App/MerchantOfferWithdrawalOriginalComposition.swift` | `.merchant` | light |
| `MerchantOfferWithdrawalOriginalView` | `App/MerchantOfferWithdrawalOriginalView.swift` | `.merchant` | light |
| `MerchantOfferWithdrawalView` | `App/MerchantOfferWithdrawalView.swift` | `.merchant` | light |
| `MerchantOfficialRecruitmentView` | `App/MerchantOfficialRecruitmentView.swift` | `.merchant` | light |
| `MerchantOperatorInvitationLandingView` | `App/MerchantOperatorInvitationLandingView.swift` | `.merchant` | light |
| `MerchantPerkTemplatesView` | `App/MerchantPerkTemplatesView.swift` | `.merchant` | light |
| `SessionMerchantLedgerAssetsView` | `App/MerchantPersonalIncomeHandoff.swift` | `.merchant` | light |
| `SessionMerchantPersonalIncomeView` | `App/MerchantPersonalIncomeHandoff.swift` | `.merchant` | light |
| `LoadKey` | `App/MerchantProjectRecentEventsView.swift` | `.merchant` | light |
| `MerchantReviewReplyRecoveryView` | `App/MerchantReviewReplyRecoveryView.swift` | `.merchant` | light |
| `MerchantSettlementOverviewView` | `App/MerchantSettlementOverviewView.swift` | `.merchant` | light |
| `MerchantStoreCharacterView` | `App/MerchantStoreCharacterView.swift` | `.merchant` | light |
| `NearbyMerchantView` | `App/NearbyMerchantView.swift` | `.merchant` | light |
| `Key` | `App/PublicMerchantReviewsView.swift` | `.merchant` | light |
| `PublisherCancellationView` | `App/PublisherLifecycleViews.swift` | `.merchant` | light |
| `PublisherOwnershipReviewView` | `App/PublisherLifecycleViews.swift` | `.merchant` | light |
| `SearchMapMerchantDetailView` | `App/SearchMapDetailViews.swift` | `.merchant` | light |
| `SessionPublisherLifecycleView` | `App/SessionPublisherLifecycleView.swift` | `.merchant` | light |
| `AccountCollectionCouponDetailView` | `App/AccountCollectionCouponDetailView.swift` | `.player` | dark |
| `AccountCollectionCouponsView` | `App/AccountCollectionCouponsView.swift` | `.player` | dark |
| `ActivityBrowserView` | `App/ActivityBrowserView.swift` | `.player` | dark |
| `ActivityEditingView` | `App/ActivityEditingView.swift` | `.player` | dark |
| `AuthChannelView` | `App/AuthChannelView.swift` | `.player` | dark |
| `BundleDetailView` | `App/BundleDetailView.swift` | `.player` | dark |
| `BundleExitSwapView` | `App/BundleExitSwapView.swift` | `.player` | dark |
| `BundleReviewListView` | `App/BundleReviewListView.swift` | `.player` | dark |
| `BundleVoucherView` | `App/BundleVoucherView.swift` | `.player` | dark |
| `CatalogShareCardView` | `App/CatalogShareCardView.swift` | `.player` | dark |
| `ChapterStoryView` | `App/ChapterStoryView.swift` | `.player` | dark |
| `CityPlayerRulesView` | `App/CityPlayerRulesView.swift` | `.player` | dark |
| `CityPlayerView` | `App/CityPlayerView.swift` | `.player` | dark |
| `ClubActivityReportView` | `App/ClubActivityReportView.swift` | `.player` | dark |
| `ClubBadgeManagementView` | `App/ClubBadgeManagementView.swift` | `.player` | dark |
| `LoadKey` | `App/ClubCalendarSessionRows.swift` | `.player` | dark |
| `LoadedContext` | `App/ClubChannelMessagingView.swift` | `.player` | dark |
| `ClubChatEntryView` | `App/ClubChatEntryView.swift` | `.player` | dark |
| `ClubChatUnavailableView` | `App/ClubChatEntryView.swift` | `.player` | dark |
| `ClubOperatingRulesView` | `App/ClubContextualViews.swift` | `.player` | dark |
| `ClubOpsTimeView` | `App/ClubContextualViews.swift` | `.player` | dark |
| `ClubDirectoryView` | `App/ClubDirectoryView.swift` | `.player` | dark |
| `ClubOwnedView` | `App/ClubDirectoryView.swift` | `.player` | dark |
| `ClubGapBoardView` | `App/ClubGapSurfaces.swift` | `.player` | dark |
| `ReadContext` | `App/ClubManagementView.swift` | `.player` | dark |
| `ClubOperationsReviewView` | `App/ClubOperationsReviewView.swift` | `.player` | dark |
| `Key` | `App/ClubOpsEventView.swift` | `.player` | dark |
| `ClubPayoutReceiverView` | `App/ClubPayoutReceiverView.swift` | `.player` | dark |
| `ClubPersonalSettlementView` | `App/ClubPayoutReceiverView.swift` | `.player` | dark |
| `ClubSettlementMineView` | `App/ClubPayoutReceiverView.swift` | `.player` | dark |
| `ReadKey` | `App/ClubPublicActivityListView.swift` | `.player` | dark |
| `ProfileTarget` | `App/ClubPublicRosterView.swift` | `.player` | dark |
| `ReadTrigger` | `App/ClubSessionQuickStartView.swift` | `.player` | dark |
| `ClubWelcomeNoteOriginalHistoryView` | `App/ClubWelcomeNoteEditor.swift` | `.player` | dark |
| `SquareMineListView` | `App/CommunityTrustPlayerViews.swift` | `.player` | dark |
| `DiscoveryHomeView` | `App/DiscoveryHomeView.swift` | `.player` | dark |
| `HomeFeedView` | `App/HomeFeedView.swift` | `.player` | dark |
| `IMConversationReadAllView` | `App/IMConversationReadAllView.swift` | `.player` | dark |
| `IMConversationRowActionsView` | `App/IMConversationRowActionsView.swift` | `.player` | dark |
| `IMSafetyReviewView` | `App/IMConversationSafetyViews.swift` | `.player` | dark |
| `IMConversationControlsView` | `App/IMExpandedViews.swift` | `.player` | dark |
| `IMImageComposeView` | `App/IMExpandedViews.swift` | `.player` | dark |
| `IMRouteShareComposeView` | `App/IMExpandedViews.swift` | `.player` | dark |
| `IMStartConversationView` | `App/IMExpandedViews.swift` | `.player` | dark |
| `IMStaticLocationComposeView` | `App/IMExpandedViews.swift` | `.player` | dark |
| `IMFileComposeView` | `App/IMFileViews.swift` | `.player` | dark |
| `IMVideoComposeView` | `App/IMVideoViews.swift` | `.player` | dark |
| `IMVideoPlaybackView` | `App/IMVideoViews.swift` | `.player` | dark |
| `InvoiceLaunchDetailView` | `App/InvoiceLaunchDetailView.swift` | `.player` | dark |
| `InvoiceLaunchHistoryView` | `App/InvoiceLaunchHistoryView.swift` | `.player` | dark |
| `InvoiceLaunchTitlesView` | `App/InvoiceLaunchTitlesView.swift` | `.player` | dark |
| `JourneyPromoView` | `App/JourneyLandingViews.swift` | `.player` | dark |
| `JourneySeatsView` | `App/JourneyLandingViews.swift` | `.player` | dark |
| `JourneyNarrativeView` | `App/JourneyNarrativeView.swift` | `.player` | dark |
| `JourneyRankBoardView` | `App/JourneyReportViews.swift` | `.player` | dark |
| `JourneyReportView` | `App/JourneyReportViews.swift` | `.player` | dark |
| `JourneySettleView` | `App/JourneyReportViews.swift` | `.player` | dark |
| `MemberReportProgressDetailView` | `App/MemberReportProgressDetailView.swift` | `.player` | dark |
| `MemberScoreAppealDetailView` | `App/MemberScoreAppealDetailView.swift` | `.player` | dark |
| `MemberScoreAppealListView` | `App/MemberScoreAppealListView.swift` | `.player` | dark |
| `MemberTemplateDetailView` | `App/MemberTemplateDetailView.swift` | `.player` | dark |
| `MessagingConversationListView` | `App/MessagingHomeView.swift` | `.player` | dark |
| `MessagingMessageDetailView` | `App/MessagingMessageDetailView.swift` | `.player` | dark |
| `TeamInvitationEntryView` | `App/NativeNavigationCompletionViews.swift` | `.player` | dark |
| `OrderCenterEntryView` | `App/OrderCenterEntryView.swift` | `.player` | dark |
| `OrderLifecycleReviewView` | `App/OrderLifecycleView.swift` | `.player` | dark |
| `ParticipantManagementDetailView` | `App/ParticipantManagementDetailView.swift` | `.player` | dark |
| `ProfileBadgeDetailView` | `App/ProfileBadgesView.swift` | `.player` | dark |
| `ProfileBadgesView` | `App/ProfileBadgesView.swift` | `.player` | dark |
| `ProfileFollowListView` | `App/ProfileFollowListView.swift` | `.player` | dark |
| `ParticipantListDeleteView` | `App/ProfileParticipantsView.swift` | `.player` | dark |
| `ProfileParticipantDetailView` | `App/ProfileParticipantsView.swift` | `.player` | dark |
| `ProfileParticipantsView` | `App/ProfileParticipantsView.swift` | `.player` | dark |
| `RegistrationSheetView` | `App/RegistrationSheetView.swift` | `.player` | dark |
| `RewardPledgeClaimView` | `App/RewardPledgeViews.swift` | `.player` | dark |
| `RoamExplorationExportView` | `App/RoamExplorationExportView.swift` | `.player` | dark |
| `RoamFinishReportView` | `App/RoamFinishReportView.swift` | `.player` | dark |
| `OpenedTile` | `App/RoamHomeTabsView.swift` | `.player` | dark |
| `RoamToolUnavailableView` | `App/RoamHomeTabsView.swift` | `.player` | dark |
| `RoamMonthlyRecapDetailView` | `App/RoamMonthlyRecapDetailView.swift` | `.player` | dark |
| `RoamPassportRecordView` | `App/RoamPassportHistoryView.swift` | `.player` | dark |
| `Selection` | `App/RoamPassportHistoryView.swift` | `.player` | dark |
| `RoamCapsuleView` | `App/RoamPassportPrivateToolsViews.swift` | `.player` | dark |
| `RoamExplorationGoalsView` | `App/RoamPassportPrivateToolsViews.swift` | `.player` | dark |
| `RoamAnniversaryView` | `App/RoamPassportToolsViews.swift` | `.player` | dark |
| `RoamMonthlyRecapView` | `App/RoamPassportToolsViews.swift` | `.player` | dark |
| `RoamPosterScanView` | `App/RoamPosterScanView.swift` | `.player` | dark |
| `RoamPreflightRulesView` | `App/RoamPreflightRulesView.swift` | `.player` | dark |
| `RoamReceivedStampSectionView` | `App/RoamReceivedStampSectionView.swift` | `.player` | dark |
| `RoamRecoveryView` | `App/RoamRecoveryView.swift` | `.player` | dark |
| `RoamCityStampDraftView` | `App/RoamStampViews.swift` | `.player` | dark |
| `RoamStampDetailView` | `App/RoamStampViews.swift` | `.player` | dark |
| `RoamCityStampFlowView` | `App/RoamSubpageParityViews.swift` | `.player` | dark |
| `RoamSharedFootprintView` | `App/RoamSubpageParityViews.swift` | `.player` | dark |
| `RoamHangoutUnavailableView` | `App/RoamVoucherHangoutViews.swift` | `.player` | dark |
| `RoamVoucherEntryView` | `App/RoamVoucherHangoutViews.swift` | `.player` | dark |
| `SearchMapCityDetailView` | `App/SearchMapDetailViews.swift` | `.player` | dark |
| `SessionCityPlayerValueView` | `App/SessionCityPlayerValueView.swift` | `.player` | dark |
| `SettingsPrivacyLocationView` | `App/SettingsPrivacyLocationView.swift` | `.player` | dark |
| `SettingsSupportSafetyView` | `App/SettingsSupportSafetyEntry.swift` | `.player` | dark |
| `SocialActionEditorView` | `App/SocialActionViews.swift` | `.player` | dark |
| `SocialActionReviewView` | `App/SocialActionViews.swift` | `.player` | dark |
| `SocialMessageMediaView` | `App/SocialMessageMediaView.swift` | `.player` | dark |
| `Key` | `App/SquareBrowserView.swift` | `.player` | dark |
| `SquareCloudComposerView` | `App/SquareCloudComposerView.swift` | `.player` | dark |
| `SquareDeletionConfirmView` | `App/SquareDeletionViews.swift` | `.player` | dark |
| `SquareGovernanceView` | `App/SquareGovernanceViews.swift` | `.player` | dark |
| `SquareReportProgressView` | `App/SquareReportProgressView.swift` | `.player` | dark |
| `SquareReportView` | `App/SquareReportView.swift` | `.player` | dark |
| `TeamCreateView` | `App/TeamCreateView.swift` | `.player` | dark |
| `TeamDetailView` | `App/TeamHomeView.swift` | `.player` | dark |
| `TeamHomeView` | `App/TeamHomeView.swift` | `.player` | dark |
| `TicketPassPresentView` | `App/TicketPassPresentView.swift` | `.player` | dark |
| `TopicChapterView` | `App/TopicDetailView.swift` | `.player` | dark |
| `TopicSessionSelectionView` | `App/TopicSessionSelectionView.swift` | `.player` | dark |
| `TopicThemeCardView` | `App/TopicThemeRecordsView.swift` | `.player` | dark |
| `TopicThemeRecordsView` | `App/TopicThemeRecordsView.swift` | `.player` | dark |
| `VideoBountyView` | `App/VideoBountyView.swift` | `.player` | dark |
| `WalletAssetsView` | `App/WalletCommerceViews.swift` | `.player` | dark |
| `WalletCartView` | `App/WalletCommerceViews.swift` | `.player` | dark |
| `WalletCheckoutView` | `App/WalletCommerceViews.swift` | `.player` | dark |
| `WalletPointsTasksView` | `App/WalletCommerceViews.swift` | `.player` | dark |
| `WalletProductView` | `App/WalletCommerceViews.swift` | `.player` | dark |
| `WalletProductsView` | `App/WalletCommerceViews.swift` | `.player` | dark |
| `WalletWithdrawalsView` | `App/WalletCommerceViews.swift` | `.player` | dark |
| `WalletIncomeAnalysisView` | `App/WalletIncomeAnalysisView.swift` | `.player` | dark |
| `WelcomeView` | `App/WelcomeView.swift` | `.player` | dark |
| `Capture` | `App/CollectSetAuthorView.swift` | `.topicEditor` | light |
| `CreatorMaintenanceWorkbenchView` | `App/CreatorMaintenanceViews.swift` | `.topicEditor` | light |
| `CreatorTicketDetailView` | `App/CreatorMaintenanceViews.swift` | `.topicEditor` | light |
| `CreatorPostGameOutcomeView` | `App/CreatorPostGameOutcomeView.swift` | `.topicEditor` | light |
| `PublishTabFloatingSheetView` | `App/HomeSearchTabParityViews.swift` | `.topicEditor` | light |
| `ModCreatorIncomeDetailView` | `App/ModCreatorIncomeViews.swift` | `.topicEditor` | light |
| `ModCreatorIncomeListView` | `App/ModCreatorIncomeViews.swift` | `.topicEditor` | light |
| `NativeAttributeAuthorView` | `App/NativeAttributeAuthorViews.swift` | `.topicEditor` | light |
| `NativeConditionAuthorView` | `App/NativeConditionAuthorView.swift` | `.topicEditor` | light |
| `Capture` | `App/NativeStoryWalkingAuthorView.swift` | `.topicEditor` | light |
| `NativeZeroHPAuthorView` | `App/NativeZeroHPAuthorView.swift` | `.topicEditor` | light |
| `OwnedTopicCoverAuthorView` | `App/OwnedTopicCoverAuthorView.swift` | `.topicEditor` | light |
| `ProjectNodeNPCFormView` | `App/ProjectEditFlowParity.swift` | `.topicEditor` | light |
| `ProjectEditLaunchView` | `App/ProjectEditLaunchView.swift` | `.topicEditor` | light |
| `TemplateAuthoringLaunchView` | `App/TemplateAuthoringLaunchView.swift` | `.topicEditor` | light |
| `TemplateCreatorRehearsalView` | `App/TemplateCreatorRehearsalView.swift` | `.topicEditor` | light |
| `TopicCreatorToolsView` | `App/TopicCreatorToolsView.swift` | `.topicEditor` | light |

## Left — hash-pinned

The domain is known. The file is hashed by a contract test, so the helper was not attached here.

| Screen | File | Domain | Appearance |
| --- | --- | --- | --- |
| `PlayExperienceNodeView` | `App/PlayExperienceView.swift` | `.game` | dark |
| `MerchantContentEditView` | `App/MerchantContentEditor.swift` | `.merchant` | light |
| `MerchantContentDocumentView` | `App/MerchantContentViews.swift` | `.merchant` | light |
| `MerchantContentHomeView` | `App/MerchantContentViews.swift` | `.merchant` | light |
| `MerchantContentReviewView` | `App/MerchantContentViews.swift` | `.merchant` | light |
| `MerchantEngagementReviewView` | `App/MerchantEngagementComposer.swift` | `.merchant` | light |
| `MerchantEngagementHomeView` | `App/MerchantEngagementViews.swift` | `.merchant` | light |
| `MerchantEvidenceSelectionView` | `App/MerchantEvidenceSelectionView.swift` | `.merchant` | light |
| `MerchantPredictionReviewView` | `App/MerchantMarketingView.swift` | `.merchant` | light |
| `MerchantNPCKnowledgeDraftView` | `App/MerchantNPCKnowledgeDraftView.swift` | `.merchant` | light |
| `MerchantNPCChatView` | `App/MerchantNPCViews.swift` | `.merchant` | light |
| `MerchantOperationsConfirmationView` | `App/MerchantOperationsEditor.swift` | `.merchant` | light |
| `MerchantOperationsAssetsView` | `App/MerchantOperationsViews.swift` | `.merchant` | light |
| `MerchantOperationsCityView` | `App/MerchantOperationsViews.swift` | `.merchant` | light |
| `MerchantOperationsDocumentView` | `App/MerchantOperationsViews.swift` | `.merchant` | light |
| `MerchantOperationsHomeView` | `App/MerchantOperationsViews.swift` | `.merchant` | light |
| `AccountCollectionFavoritePostsView` | `App/AccountCollectionFavoritesView.swift` | `.player` | dark |
| `AccountCollectionFavoriteTopicsView` | `App/AccountCollectionFavoritesView.swift` | `.player` | dark |
| `AccountCollectionFavoritesView` | `App/AccountCollectionFavoritesView.swift` | `.player` | dark |
| `ClubAIDesignView` | `App/ClubAIDesignView.swift` | `.player` | dark |
| `ClubCommunityCommentsView` | `App/ClubCommunityViews.swift` | `.player` | dark |
| `ClubCommunityFeedView` | `App/ClubCommunityViews.swift` | `.player` | dark |
| `ClubCommunityHistoryView` | `App/ClubCommunityViews.swift` | `.player` | dark |
| `ClubCommunityPostDetailView` | `App/ClubCommunityViews.swift` | `.player` | dark |
| `ClubCommunityReviewView` | `App/ClubCommunityViews.swift` | `.player` | dark |
| `ClubEventCalendarView` | `App/ClubEventCalendarView.swift` | `.player` | dark |
| `ClubGovernanceEventView` | `App/ClubGovernanceViews.swift` | `.player` | dark |
| `ClubGovernanceStoryView` | `App/ClubGovernanceViews.swift` | `.player` | dark |
| `ClubHomeView` | `App/ClubHomeView.swift` | `.player` | dark |
| `ClubInvitationFeedbackView` | `App/ClubInvitationFeedbackView.swift` | `.player` | dark |
| `ClubLeadProgressView` | `App/ClubLeadProgressView.swift` | `.player` | dark |
| `ClubMembersView` | `App/ClubMembersView.swift` | `.player` | dark |
| `ClubOperationsWorkspaceView` | `App/ClubOperationsViews.swift` | `.player` | dark |
| `ClubStatsOverviewView` | `App/ClubStatsOverviewView.swift` | `.player` | dark |
| `DiscoveryTemplateBrowserView` | `App/DiscoveryTemplateBrowserView.swift` | `.player` | dark |
| `GrowthCenterView` | `App/GrowthCenterView.swift` | `.player` | dark |
| `GrowthLeaderboardView` | `App/GrowthLeaderboardView.swift` | `.player` | dark |
| `ObjectBadgeDetailView` | `App/ObjectBadgeViews.swift` | `.player` | dark |
| `ObjectBadgeWallView` | `App/ObjectBadgeViews.swift` | `.player` | dark |
| `ProfileOrderDetailView` | `App/ProfileOrdersView.swift` | `.player` | dark |
| `ProfileOrdersView` | `App/ProfileOrdersView.swift` | `.player` | dark |
| `RoamBrowserView` | `App/RoamBrowserView.swift` | `.player` | dark |
| `RoamHistoryShareView` | `App/RoamHistoryShareView.swift` | `.player` | dark |
| `RoamHistoryDetailView` | `App/RoamHistoryViews.swift` | `.player` | dark |
| `RoamHistoryView` | `App/RoamHistoryViews.swift` | `.player` | dark |
| `RoamItemDetailView` | `App/RoamItemDetailView.swift` | `.player` | dark |
| `RoamLiveRulesView` | `App/RoamLiveSessionView.swift` | `.player` | dark |
| `RoamLiveSessionView` | `App/RoamLiveSessionView.swift` | `.player` | dark |
| `RoamMedalShareView` | `App/RoamMedalShareView.swift` | `.player` | dark |
| `RoamShareAlbumGuideView` | `App/RoamShareAlbumGuideView.swift` | `.player` | dark |
| `SearchMapExplorerView` | `App/SearchMapExplorerView.swift` | `.player` | dark |
| `SettingsAboutView` | `App/SettingsAboutView.swift` | `.player` | dark |
| `SettingsLegalDocumentView` | `App/SettingsLegalDocumentView.swift` | `.player` | dark |
| `SettingsSoundPreferencesView` | `App/SettingsSupportSections.swift` | `.player` | dark |
| `SettingsUnavailableFeatureView` | `App/SettingsSupportSections.swift` | `.player` | dark |
| `SettingsView` | `App/SettingsView.swift` | `.player` | dark |
| `ShopNPCView` | `App/ShopNPCView.swift` | `.player` | dark |
| `SocialInviteHistoryView` | `App/SocialInviteHistoryView.swift` | `.player` | dark |
| `SocialPublicProfileView` | `App/SocialPublicProfileView.swift` | `.player` | dark |
| `SquareWorkspaceView` | `App/SquareWorkspaceView.swift` | `.player` | dark |
| `TicketWalletTeamView` | `App/TicketWalletTeamView.swift` | `.player` | dark |
| `TopicBrowserView` | `App/TopicBrowserView.swift` | `.player` | dark |
| `ProjectChapterAudioAuthorView` | `App/ProjectChapterAudioAuthorView.swift` | `.topicEditor` | light |
| `ProjectEditChapterView` | `App/ProjectEditDetailForms.swift` | `.topicEditor` | light |
| `ProjectEditNodeView` | `App/ProjectEditDetailForms.swift` | `.topicEditor` | light |
| `ProjectEditReviewView` | `App/ProjectEditDetailForms.swift` | `.topicEditor` | light |
| `ProjectEditTicketView` | `App/ProjectEditDetailForms.swift` | `.topicEditor` | light |
| `ProjectNodeImageAuthorView` | `App/ProjectNodeImageAuthorView.swift` | `.topicEditor` | light |
| `ProjectStoryAudioAuthorView` | `App/ProjectStoryAudioAuthorView.swift` | `.topicEditor` | light |
| `ProjectStoryImageAuthorView` | `App/ProjectStoryImageAuthorView.swift` | `.topicEditor` | light |
| `ActivityPublishingView` | `App/PublishingModesViews.swift` | `.topicEditor` | light |
| `TemplateAuthoringAdvancedView` | `App/TemplateAuthoringDetailForms.swift` | `.topicEditor` | light |
| `TemplateAuthoringStoryView` | `App/TemplateAuthoringDetailForms.swift` | `.topicEditor` | light |
| `TemplateAuthoringMineView` | `App/TemplateAuthoringMineView.swift` | `.topicEditor` | light |
| `TemplateAuthoringReviewView` | `App/TemplateAuthoringView.swift` | `.topicEditor` | light |
| `TemplateCreatorConfigurationView` | `App/TemplateCreatorConfigurationView.swift` | `.topicEditor` | light |

## Left — ambiguous

Domain is —. Not guessed.

| Screen | File | Domain |
| --- | --- | --- |
| `BundleMerchantStallView` | `App/BundleMerchantStallView.swift` | — |
| `CreatorApplicationView` | `App/CreatorApplicationView.swift` | — |
| `MerchantGamePlayerView` | `App/MerchantGamePlayerView.swift` | — |
| `PlayAdvancedView` | `App/PlayAdvancedView.swift` | — |
| `PlayBranchHistoryView` | `App/PlayBranchHistoryView.swift` | — |
| `PlayStillnessStreamView` | `App/PlayDeviceTaskViews.swift` | — |
| `PlayStopwatchView` | `App/PlayDeviceTaskViews.swift` | — |
| `PlayNodeDetailView` | `App/PlayNodeDetailView.swift` | — |
| `PlayCircleView` | `App/PlayPlayerAndCircleViews.swift` | — |
| `PlayPlayerSessionView` | `App/PlayPlayerAndCircleViews.swift` | — |
| `PlayPrefabRuntimeView` | `App/PlayPrefabRuntimeView.swift` | — |
| `PlayOperatingSummaryView` | `App/PlayPreferenceViews.swift` | — |
| `PlayPreferenceView` | `App/PlayPreferenceViews.swift` | — |
| `PlayOfflinePackView` | `App/PlayRecoveryViews.swift` | — |
| `PlayRewardBadgeCollectionView` | `App/PlayRewardBadgeViews.swift` | — |
| `PlaySharedPlanLifecycleView` | `App/PlaySharedPlanLifecycleView.swift` | — |
| `PlaySharedPlanR5HostView` | `App/PlaySharedPlanR5HostView.swift` | — |
| `PlayStoreDayMerchantView` | `App/PlayStoreDayMerchantView.swift` | — |
| `PlayTeamBackpackView` | `App/PlayTeamBackpackView.swift` | — |
| `PlayThemeBackpackView` | `App/PlayThemeBackpackView.swift` | — |
| `PlayThemeRecordsView` | `App/PlayThemeRecordsView.swift` | — |
| `PlayerTaskEvidenceView` | `App/PlayerTaskEvidenceView.swift` | — |
| `RewardPledgeMerchantView` | `App/RewardPledgeViews.swift` | — |
| `RewardPledgeStaffView` | `App/RewardPledgeViews.swift` | — |
| `WorkshopCommerceLicenseDetailView` | `App/WorkshopCommerceView.swift` | — |
| `WorkshopCommerceView` | `App/WorkshopCommerceView.swift` | — |
| `SessionWorkshopCreatorConsentView` | `App/WorkshopCreatorConsentView.swift` | — |
| `WorkshopCreatorConsentView` | `App/WorkshopCreatorConsentView.swift` | — |
| `WorkshopCreatorPendingView` | `App/WorkshopCreatorPendingView.swift` | — |
| `WorkshopLicenseLibraryView` | `App/WorkshopLicenseLibraryView.swift` | — |
| `WorkshopModUpgradeSheetView` | `App/WorkshopModUpgradeSheetView.swift` | — |
| `WorkshopOwnedDetailView` | `App/WorkshopOwnedLibraryView.swift` | — |
| `WorkshopOwnedLibraryView` | `App/WorkshopOwnedLibraryView.swift` | — |
| `WorkshopOwnedPackageView` | `App/WorkshopOwnedPackageView.swift` | — |
| `WorkshopPaidInstallView` | `App/WorkshopPaidInstallView.swift` | — |
| `WorkshopPaidInstalledTextView` | `App/WorkshopPaidInstalledTextView.swift` | — |
| `WorkshopPaidProfessionalView` | `App/WorkshopPaidProfessionalView.swift` | — |
| `WorkshopPurchasedDetailView` | `App/WorkshopPurchasedLibraryView.swift` | — |
| `WorkshopPurchasedLibraryView` | `App/WorkshopPurchasedLibraryView.swift` | — |

## Left — unknown role

Domain is —. Not guessed.

| Screen | File | Domain |
| --- | --- | --- |
| `ApprovedReleaseOriginalRecoveryView` | `App/ApprovedReleaseOriginalRecovery.swift` | — |
| `CharacterCardReadbackView` | `App/CharacterCardReadbackView.swift` | — |
| `CharacterSheetDetailView` | `App/CharacterSheetDetailView.swift` | — |
| `CityArrivalEvidenceView` | `App/CityArrivalEvidenceView.swift` | — |
| `CityCurrentSnapshotView` | `App/CityCurrentSnapshotView.swift` | — |
| `CityOrderedMapView` | `App/CityOrderedMapView.swift` | — |
| `CityParticipationFormView` | `App/CityParticipationFormView.swift` | — |
| `CityParticipationRecoveryView` | `App/CityParticipationRecoveryView.swift` | — |
| `CityTaskHistoryView` | `App/CityTaskHistoryView.swift` | — |
| `SessionClubProjectLaunchView` | `App/ClubProjectLaunchView.swift` | — |
| `CouponCodeView` | `App/CouponCodeView.swift` | — |
| `ExploreCompletionView` | `App/ExploreCompletionView.swift` | — |
| `FreeExplorationExperienceView` | `App/FreeExplorationViews.swift` | — |
| `FreeExplorationReadStoreView` | `App/FreeExplorationViews.swift` | — |
| `FreeExplorationStoreView` | `App/FreeExplorationViews.swift` | — |
| `FreeExploreBundleLaunchView` | `App/FreeExploreBundleLaunchView.swift` | — |
| `G6RevenueAllocationsView` | `App/G6CapabilityViews.swift` | — |
| `GlobalSearchView` | `App/GlobalSearchView.swift` | — |
| `GroupPollOriginalResultView` | `App/GroupPollOriginalResultView.swift` | — |
| `GroupPollUnavailableView` | `App/GroupPollViews.swift` | — |
| `GroupPollView` | `App/GroupPollViews.swift` | — |
| `H5DeclaredSessionView` | `App/H5DeclaredSessionView.swift` | — |
| `UnifiedSearchResultsView` | `App/MapSearchPlayerViews.swift` | — |
| `MasterReleaseSignoffDashboardView` | `App/MasterReleaseSignoffDashboardView.swift` | — |
| `MasterSevenDayLaunchCommandCenterView` | `App/MasterSevenDayLaunchCommandCenterView.swift` | — |
| `MasterThreeDocument312LaneCommandHubView` | `App/MasterThreeDocument312LaneCommandHubView.swift` | — |
| `ModInstallationQaEditorView` | `App/ModInstallationQaEditorView.swift` | — |
| `ModInstallationSavedRehearsalView` | `App/ModInstallationSavedRehearsalView.swift` | — |
| `ModInstallationTemplateEditorView` | `App/ModInstallationTemplateEditorView.swift` | — |
| `ModInstalledTextReadView` | `App/ModInstalledTextReadView.swift` | — |
| `ModSettlementDetailView` | `App/ModSettlementViews.swift` | — |
| `ModSettlementListView` | `App/ModSettlementViews.swift` | — |
| `ModUpgradeOriginalRecoveryView` | `App/ModUpgradeView.swift` | — |
| `ModUpgradeView` | `App/ModUpgradeView.swift` | — |
| `ModVenueOperationsView` | `App/ModVenueOperationsView.swift` | — |
| `NPCChatDataRecordView` | `App/NPCChatDataView.swift` | — |
| `NPCChatDataView` | `App/NPCChatDataView.swift` | — |
| `NativeBlacklistView` | `App/NativeBlacklistView.swift` | — |
| `NativeChannelChainView` | `App/NativeChannelChainView.swift` | — |
| `NativeChannelCheckinRankView` | `App/NativeChannelCheckinView.swift` | — |
| `NativeChannelCheckinView` | `App/NativeChannelCheckinView.swift` | — |
| `NativeChannelHistoryView` | `App/NativeChannelHistoryView.swift` | — |
| `NativeChannelManagementPermissionsView` | `App/NativeChannelManagementPermissionsView.swift` | — |
| `NativeChannelManagementDetailView` | `App/NativeChannelManagementViews.swift` | — |
| `NativeChannelManagementDirectoryView` | `App/NativeChannelManagementViews.swift` | — |
| `NativeChannelManagementEditorView` | `App/NativeChannelManagementViews.swift` | — |
| `NativeChannelManagementReviewView` | `App/NativeChannelManagementViews.swift` | — |
| `NativeChannelMessageAttachmentView` | `App/NativeChannelMessageAttachmentView.swift` | — |
| `NativeChannelMessageContextView` | `App/NativeChannelMessageContextView.swift` | — |
| `NativeChannelMessagePinsView` | `App/NativeChannelMessagePinsView.swift` | — |
| `NativeChannelMessageRevisionView` | `App/NativeChannelMessageRevisionView.swift` | — |
| `NativeChannelMessageSearchView` | `App/NativeChannelMessageSearchView.swift` | — |
| `NativeChannelNotificationConversationView` | `App/NativeChannelNotificationConversationView.swift` | — |
| `NativeChannelNotificationGlobalView` | `App/NativeChannelNotificationGlobalView.swift` | — |
| `NativeChannelOnboardingView` | `App/NativeChannelOnboardingView.swift` | — |
| `NativeChannelProgressBoardView` | `App/NativeChannelProgressBoardView.swift` | — |
| `NativeChannelProgressLoadedView` | `App/NativeChannelProgressEntry.swift` | — |
| `NativeChannelProgressOwnHistoryView` | `App/NativeChannelProgressOwnHistoryView.swift` | — |
| `NativeChannelProgressPrivacyView` | `App/NativeChannelProgressPrivacyView.swift` | — |
| `NativeChannelReportRecoveryView` | `App/NativeChannelReportRecoveryEntry.swift` | — |
| `NativeChannelWelcomeView` | `App/NativeChannelWelcomeView.swift` | — |
| `NativeClubNotificationDefaultView` | `App/NativeClubNotificationDefaultView.swift` | — |
| `NativeConditionAuthorBranchView` | `App/NativeConditionAuthorView.swift` | — |
| `NativeConditionAuthorChoiceView` | `App/NativeConditionAuthorView.swift` | — |
| `NativeConditionAuthorNodeView` | `App/NativeConditionAuthorView.swift` | — |
| `NativeEnrollmentView` | `App/NativeEnrollmentView.swift` | — |
| `NativeEntryLandingView` | `App/NativeEntryLandingView.swift` | — |
| `NativeFriendChannelInviteView` | `App/NativeFriendChannelInviteEntry.swift` | — |
| `NativeFriendChannelSourceView` | `App/NativeFriendChannelSourceEntry.swift` | — |
| `NativeFriendDirectoryDetailView` | `App/NativeFriendDirectoryView.swift` | — |
| `NativeFriendDirectoryView` | `App/NativeFriendDirectoryView.swift` | — |
| `NativeFriendHomeView` | `App/NativeFriendHomeView.swift` | — |
| `NativeFriendMetadataView` | `App/NativeFriendMetadataView.swift` | — |
| `NativeFriendRemovalView` | `App/NativeFriendRemovalView.swift` | — |
| `NativeTimeWindowHostView` | `App/NativeMotionReminderViews.swift` | — |
| `BadgeRouteEntryView` | `App/NativeNavigationCompletionViews.swift` | — |
| `NativeRouteErrorView` | `App/NativeNavigationCompletionViews.swift` | — |
| `NativeNotificationDeliveryLogView` | `App/NativeNotificationDeliveryLogView.swift` | — |
| `NativeNotificationPermissionNudgeView` | `App/NativeNotificationPermissionNudgeView.swift` | — |
| `NativeProgressPrivacyView` | `App/NativeProgressPrivacyView.swift` | — |
| `NativeVerificationReviewView` | `App/NativeVerificationView.swift` | — |
| `NativeVerificationView` | `App/NativeVerificationView.swift` | — |
| `NativeWebhookDeliveryLogView` | `App/NativeWebhookDeliveryLogView.swift` | — |
| `NativeWebhookInboundLogView` | `App/NativeWebhookInboundLogView.swift` | — |
| `NativeWebhookConfirmationView` | `App/NativeWebhookManagementEntry.swift` | — |
| `NativeWebhookRecoveryView` | `App/NativeWebhookManagementEntry.swift` | — |
| `NativeWebhookManagementView` | `App/NativeWebhookManagementView.swift` | — |
| `NativeWebhookOneTimeCredentialView` | `App/NativeWebhookOneTimeCredentialView.swift` | — |
| `NearbyTeamReviewView` | `App/NearbyTeamViews.swift` | — |
| `NearbyTeamsView` | `App/NearbyTeamViews.swift` | — |
| `NonCashRewardDetailView` | `App/NonCashRewardViews.swift` | — |
| `NonCashRewardsView` | `App/NonCashRewardViews.swift` | — |
| `ObjectCardDetailView` | `App/ObjectCardViews.swift` | — |
| `OfficialEventsBrowserView` | `App/OfficialEventsBrowserView.swift` | — |
| `OfficialOrganizerConsoleView` | `App/OfficialOrganizerConsoleView.swift` | — |
| `OfficialBroadcastStatsView` | `App/OfficialPrivateViews.swift` | — |
| `OfficialPublishedView` | `App/OfficialPrivateViews.swift` | — |
| `OfficialRouteDetailView` | `App/OfficialRouteViews.swift` | — |
| `OfficialRouteListView` | `App/OfficialRouteViews.swift` | — |
| `OwnedTemplateConfigurationView` | `App/OwnedTemplateConfigurationView.swift` | — |
| `OwnedTemplateStoryConfigurationView` | `App/OwnedTemplateConfigurationView.swift` | — |
| `OwnedTopicCoverImageView` | `App/OwnedTopicCoverImageView.swift` | — |
| `OwnerDraftBrowserView` | `App/OwnerDraftBrowserView.swift` | — |
| `OwnerDraftDetailView` | `App/OwnerDraftBrowserView.swift` | — |
| `OwnerDraftGuestView` | `App/OwnerDraftBrowserView.swift` | — |
| `ParticipationSupportView` | `App/ParticipationSupportView.swift` | — |
| `PassDetailView` | `App/PassMarketViews.swift` | — |
| `PassGiftClaimView` | `App/PassMarketViews.swift` | — |
| `PassMarketView` | `App/PassMarketViews.swift` | — |
| `PassLibraryView` | `App/PassMembershipViews.swift` | — |
| `PassMembershipView` | `App/PassMembershipViews.swift` | — |
| `PersonalLocationShareUnavailableView` | `App/PersonalLocationShareHost.swift` | — |
| `PersonalLocationShareView` | `App/PersonalLocationShareView.swift` | — |
| `CompletedPlayHistoryView` | `App/PlayerJourneyViews.swift` | — |
| `ParticipationDetailView` | `App/PlayerJourneyViews.swift` | — |
| `ParticipationHistoryView` | `App/PlayerJourneyViews.swift` | — |
| `PrivacyProtectionView` | `App/PrivacyProtectionView.swift` | — |
| `PrivateHomeMapPickerView` | `App/PrivateHomeMapPicker.swift` | — |
| `ProjectStoryTemplateView` | `App/ProjectStoryTemplateView.swift` | — |
| `PublicCatalogDetailView` | `App/PublicCatalogViews.swift` | — |
| `PublicCatalogView` | `App/PublicCatalogViews.swift` | — |
| `PublishingIdentityStatusView` | `App/PublishingManagementViews.swift` | — |
| `PublishingProjectsView` | `App/PublishingManagementViews.swift` | — |
| `PublishingModesView` | `App/PublishingModesViews.swift` | — |
| `QuickPublishingView` | `App/PublishingModesViews.swift` | — |
| `QmodAuthorImportView` | `App/QmodAuthorImportView.swift` | — |
| `ReformWorldHostWorkbenchView` | `App/ReformWorldHostWorkbenchView.swift` | — |
| `ReleasePreflightDiagnosticsView` | `App/ReleasePreflightDiagnosticsView.swift` | — |
| `SecondRegistrationStatsView` | `App/SecondRegistrationStatsView.swift` | — |
| `OwnMediaReviewView` | `App/SettingsPrivacyLocationView.swift` | — |
| `StoryParticipationView` | `App/StoryRuleEditorView.swift` | — |
| `SupportTicketReadView` | `App/SupportTicketReadView.swift` | — |
| `TemplateAdditionalSampleBrowserView` | `App/TemplateAdditionalSampleBrowserView.swift` | — |
| `TemplateD6SourceSampleView` | `App/TemplateAdditionalSampleBrowserView.swift` | — |
| `TemplateAdvancedGameConfigurationView` | `App/TemplateAdvancedGameConfigurationView.swift` | — |
| `TemplateCoinFlipRehearsalView` | `App/TemplateCoinFlipRehearsalView.swift` | — |
| `TemplateCheckPresetView` | `App/TemplateCreatorConfigurationView.swift` | — |
| `TemplateD6RehearsalView` | `App/TemplateD6RehearsalView.swift` | — |
| `TemplateEffectListView` | `App/TemplateEffectListView.swift` | — |
| `TemplateHotspotPlacementView` | `App/TemplateHotspotPlacementView.swift` | — |
| `TemplateLegacyQuestionRehearsalView` | `App/TemplateLegacyQuestionRehearsalView.swift` | — |
| `TemplateLocalCategoryRemovalView` | `App/TemplateLocalCategoryRemovalView.swift` | — |
| `TemplateReactionRehearsalView` | `App/TemplateReactionRehearsalView.swift` | — |
| `TemplateReasoningRehearsalView` | `App/TemplateReasoningRehearsalView.swift` | — |
| `TemplateLowHPPresetView` | `App/TemplateRootAuthoringView.swift` | — |
| `TemplateRootAuthoringView` | `App/TemplateRootAuthoringView.swift` | — |
| `TemplateD20RehearsalView` | `App/TemplateRootRehearsalView.swift` | — |
| `TemplateRootRehearsalView` | `App/TemplateRootRehearsalView.swift` | — |
| `TemplateSampleBrowserView` | `App/TemplateSampleBrowserView.swift` | — |
| `TemplateSensorRehearsalView` | `App/TemplateSensorRehearsalView.swift` | — |
| `TemplateTimerOutcomeEditorView` | `App/TemplateTimerRehearsalView.swift` | — |
| `TemplateTimerRehearsalView` | `App/TemplateTimerRehearsalView.swift` | — |
| `VerificationCodeView` | `App/VerificationCodeView.swift` | — |
| `WalkingNavigationView` | `App/WalkingNavigationView.swift` | — |
| `WithdrawalHistoryView` | `App/WithdrawalHistoryView.swift` | — |
| `WithdrawalSupportContactView` | `App/WithdrawalSupportContactView.swift` | — |
| `WithdrawalSupportLandingView` | `App/WithdrawalSupportLandingView.swift` | — |

