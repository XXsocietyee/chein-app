# Mount Hooks — G2 ops (`gap/g2-ops`)

All new UI views live in `App/MPGap/<Area>/*.swift` with zero edits to existing files. The coordinator/integrator mounts each hook at the target file below.

## Club
1. **`ClubGapCoopPoolSection`** (`App/MPGap/Club/ClubGapManageExtensions.swift`)
   - **Target:** `App/ClubDetailView.swift` (inside `管理` tab `List`, owner-only)
   - **Code:** `ClubGapCoopPoolSection(state: coopPoolState, pendingTopicID: pendingTopicID, onRetry: { ... }, onApply: { topicID, name, msg in ... }, onOpenApplication: { ... }, onOpenMyCoop: { ... })`
2. **`ClubGapMemberAvatarStrip`** (`App/MPGap/Club/ClubGapManageExtensions.swift`)
   - **Target:** `App/ClubDetailView.swift` (inside `概览` tab, `成员` section)
   - **Code:** `ClubGapMemberAvatarStrip(avatars: memberAvatars, totalCount: memberCount, onTapAll: { ... })`
3. **`ClubGapSettingsSheet`** (`App/MPGap/Club/ClubGapManageExtensions.swift`)
   - **Target:** `App/ClubDetailView.swift` (`.sheet` triggered by nav-bar gear / `管理` settings row)
   - **Code:** `ClubGapSettingsSheet(clubName: club.name, canGovern: canGovern, onEditClub: { ... }, onTransferOwner: { ... }, onDissolveClub: { ... })`
4. **`ClubGapTopicDirectorEmbeddedSection`** & **`ClubGapTopicMoreMenu`** (`App/MPGap/Club/ClubGapTopicDirectorViews.swift`)
   - **Target:** `App/ClubGovernanceViews.swift` (topic detail `List` and `.toolbar`)
   - **Code:** `ClubGapTopicDirectorEmbeddedSection(summary: directorSummary, onConfirmUnknownWrite: { ... }, onRetryUnknownWrite: { ... }, onOpenTool: { ... }, onToggleLeaderboardVisibility: { ... })`
5. **`ClubGapFEReferenceSettlementSection`** (`App/MPGap/Club/ClubGapReferenceSettlementView.swift`)
   - **Target:** `App/ClubGovernanceViews.swift` (settlement view) & `App/MerchantLedgerSettlementOverview.swift`
   - **Code:** `ClubGapFEReferenceSettlementSection(role: .payer, items: feSettlements, allowsMoneyWrite: allowsMoneyWrite, onMarkSettled: { ids, voucherNo in ... }, onDispute: { ... })`

## Merchant-Coop
1. **`MerchantGapAIInsightDashboardSection`** (`App/MPGap/MerchantCoop/MerchantGapAIInsightViews.swift`)
   - **Target:** `App/MerchantAIInsightView.swift` (or `App/MerchantMarketingViews.swift`)
   - **Code:** `MerchantGapAIInsightDashboardSection(selectedWindow: $window, selectedMetric: $metric, storeName: storeName, windowLabel: window.title, sources: sources, opportunityText: aiOpportunity, problemText: aiProblem, lowSample: lowSample, growTips: growTips, onSelectGrowTip: { ... })`
2. **`MerchantGapExportTaskBanner`** (`App/MPGap/MerchantCoop/MerchantGapOperationsViews.swift`)
   - **Target:** `App/MerchantBusinessViews.swift` (customer list)
   - **Code:** `MerchantGapExportTaskBanner(state: exportState, onDownload: { ... }, onRetry: { ... })`
3. **`MerchantGapManualAftercareSection`** (`App/MPGap/MerchantCoop/MerchantGapOperationsViews.swift`)
   - **Target:** `App/MerchantAftercareProgressView.swift`
   - **Code:** `MerchantGapManualAftercareSection(manualCase: manualCase, onContactSupport: { ... })`
4. **`MerchantGapAINPCIntroSheet`** (`App/MPGap/MerchantCoop/MerchantGapOperationsViews.swift`)
   - **Target:** `App/MerchantStoreCharacterView.swift` (`.sheet` on first visit)
   - **Code:** `MerchantGapAINPCIntroSheet()`
5. **`CoopGapSupplyStationPickerSection`** (`App/MPGap/MerchantCoop/MerchantGapOperationsViews.swift`)
   - **Target:** `App/CoopFlowNewInvitationView` (`App/CooperationFlowEditors.swift`)
   - **Code:** `CoopGapSupplyStationPickerSection(stations: stations, selectedIDs: $selectedStationIDs)`
6. **`CoopGapNearbyReplacementSheet`** (`App/MPGap/MerchantCoop/MerchantGapOperationsViews.swift`)
   - **Target:** `App/CooperationNearbyView`
   - **Code:** `CoopGapNearbyReplacementSheet(merchants: invitableMerchants, onInvite: { ... })`

## Account-Publish
1. **`AccountGapOwnProfileComposerRow`** (`App/MPGap/AccountPublish/AccountPublishGapViews.swift`)
   - **Target:** `App/ProfileAuthorPostsSection.swift`
   - **Code:** `AccountGapOwnProfileComposerRow(joinDateText: profile.joinDate, onTapCompose: { ... })`
2. **`SocialPublicProfileGapCoopBar`** (`App/MPGap/AccountPublish/AccountPublishGapViews.swift`)
   - **Target:** `App/SocialPublicProfileView.swift` (`.safeAreaInset(edge: .bottom)` when merchant viewer & `canInviteCoop`)
   - **Code:** `SocialPublicProfileGapCoopBar(onInitiateCoop: { ... })`
3. **`ProjectEditGapCastAndLookSection`** (`App/MPGap/AccountPublish/AccountPublishGapViews.swift`)
   - **Target:** `App/ProjectEditView.swift`
   - **Code:** `ProjectEditGapCastAndLookSection(castEnabled: $castEnabled, castMembers: castMembers, selectedLookID: $lookID, onOpenCastEditor: { ... })`
4. **`SquareDetailGapPlayCardSection`** (`App/MPGap/AccountPublish/AccountPublishGapViews.swift`)
   - **Target:** `App/SquareDetailView.swift`
   - **Code:** `SquareDetailGapPlayCardSection(templateTitle: templateTitle, isBookmarked: isBookmarked, onRemixTemplate: { ... }, onTryPlay: { ... }, onToggleBookmark: { ... })`
5. **`TeamDetailGapApplicantsSection`** (`App/MPGap/AccountPublish/AccountPublishGapViews.swift`)
   - **Target:** `App/TeamHomeView.swift` (leader-only section)
   - **Code:** `TeamDetailGapApplicantsSection(state: applicantsState, onRetry: { ... }, onReject: { ... }, onApprove: { ... })`
6. **`TeamJoinGapManualCodeSection`** (`App/MPGap/AccountPublish/AccountPublishGapViews.swift`)
   - **Target:** `App/TeamPageParityViews.swift`
   - **Code:** `TeamJoinGapManualCodeSection(code: $joinCode, errorText: joinError, showsBuyTicketCTA: ticketRequired, onSubmitCode: { ... }, onBuyTicket: { ... })`

## Round 2 Additions

### Club
6. **`ClubGapPlayRecordPickerRow`** (`App/MPGap/Club/ClubGapRemainingViews.swift`)
   - **Target:** `App/ClubCommunityViews.swift` (post composer)
   - **Code:** `ClubGapPlayRecordPickerRow(selected: selectedRef, options: refOptions, isLoading: isLoadingRefs, errorText: refError, onSelect: { ... }, onRetryLoad: { ... })`
7. **`ClubGapActivityAndScanActions`** (`App/MPGap/Club/ClubGapRemainingViews.swift`)
   - **Target:** `App/ClubDetailView.swift` (活动 card & 管理 tab)
   - **Code:** `ClubGapActivityAndScanActions(showsUndertake: isMerchantViewer, showsScanVerify: canScan, onTapUndertake: { ... }, onTapScanVerify: { ... })`
8. **`ClubGapFollowAuthorButton`** (`App/MPGap/Club/ClubGapRemainingViews.swift`)
   - **Target:** `App/ClubCommunityViews.swift` (post header)
   - **Code:** `ClubGapFollowAuthorButton(isFollowing: isFollowingAuthor, isBusy: isFollowBusy, onToggle: { ... })`
9. **`ClubGapEventOpsExtrasSection`** (`App/MPGap/Club/ClubGapRemainingViews.swift`)
   - **Target:** `App/ClubOpsEventView.swift`
   - **Code:** `ClubGapEventOpsExtrasSection(paymentNotice: paymentNotice, windowWarning: windowWarning, showsEmptyPublishCTA: topics.isEmpty, onTapPublishTopic: { ... })`

### Merchant-Coop
7. **`MerchantGapWorkbenchProjectCardsSection`** (`App/MPGap/MerchantCoop/MerchantGapRemainingViews.swift`)
   - **Target:** `App/MerchantHomeView.swift`
   - **Code:** `MerchantGapWorkbenchProjectCardsSection(cards: projectCards, onSelectProject: { ... })`
8. **`MerchantGapOnboardingIntroView`** (`App/MPGap/MerchantCoop/MerchantGapRemainingViews.swift`)
   - **Target:** `App/MerchantOnboardingView.swift`
   - **Code:** `MerchantGapOnboardingIntroView(ownedClubs: ownedClubs, onStartForm: { ... }, onSubmitClaim: { ... }, onTransferClub: { ... })`
9. **`MerchantGapDecorContactSection`** (`App/MPGap/MerchantCoop/MerchantGapRemainingViews.swift`)
   - **Target:** `App/MerchantOperationsEditor.swift`
   - **Code:** `MerchantGapDecorContactSection(draft: $contactDraft, onPickQR: { ... }, onPickAddress: { ... }, onPreviewPublicHome: { ... }, onContactOps: { ... })`
10. **`CoopGapRelationFeedAndTeamInviteSection`** (`App/MPGap/MerchantCoop/MerchantGapRemainingViews.swift`)
    - **Target:** `App/CoopRelationDiscoveryView.swift` & `App/MerchantOperatorRosterSections.swift`
    - **Code:** `CoopGapRelationFeedAndTeamInviteSection(posts: posts, isRefreshing: isRefreshing, pendingInvite: pendingInvite, onComposePost: { ... }, onAcceptInvite: { ... })`

### Account-Publish
7. **`ProfileEditGapPhoneBindRow`** (`App/MPGap/AccountPublish/AccountPublishGapRemainingViews.swift`)
   - **Target:** `App/ProfileEditView.swift`
   - **Code:** `ProfileEditGapPhoneBindRow(maskedPhone: profile.phone, onTapBindOrRebind: { ... })`
8. **`MiniCropGapOverlay`** (`App/MPGap/AccountPublish/AccountPublishGapRemainingViews.swift`)
   - **Target:** `App/MiniCropView.swift`
   - **Code:** `MiniCropGapOverlay(shape: cropShape, onReset: { ... })`
9. **`SettingsGapComplaintRow`** (`App/MPGap/AccountPublish/AccountPublishGapRemainingViews.swift`)
   - **Target:** `App/SettingsView.swift`
   - **Code:** `SettingsGapComplaintRow(onOpenComplaint: { ... })`
10. **`ActivityPublishGapOrganizerAndPOISection`** (`App/MPGap/AccountPublish/AccountPublishGapRemainingViews.swift`)
    - **Target:** `App/PublishingModesViews.swift`
    - **Code:** `ActivityPublishGapOrganizerAndPOISection(pickedPlaceName: placeName, isSoldLocked: isSoldLocked, organizerName: organizerName, organizerLoadFailed: organizerLoadFailed, onPickLocation: { ... }, onRetryOrganizer: { ... })`

## Round 4 Additions (`audit/parity-r7-*` Gemini Queue)

### Club
10. **`ClubGapManagedProjectsDirectorSection`** (`App/MPGap/Club/ClubGapRound4Views.swift`)
    - **Target:** `App/ClubDetailView.swift` (管理 tab)
    - **Code:** `ClubGapManagedProjectsDirectorSection(projects: directorProjects, onOpenDirector: { topicID, activityID in ... }, onSelectSessionTool: { topicID, activityID, tool in ... })`
11. **`ClubGapStoryMapAddressRow`** (`App/MPGap/Club/ClubGapRound4Views.swift`)
    - **Target:** `App/ClubStoryViews.swift`
    - **Code:** `ClubGapStoryMapAddressRow(stop: stopLocation)`
12. **`ClubGapApplyCertImagesSection`** (`App/MPGap/Club/ClubGapRound4Views.swift`)
    - **Target:** `App/ClubGovernanceCommandForm.swift` / `App/ClubHostApplicationMaterials.swift`
    - **Code:** `ClubGapApplyCertImagesSection(draft: $certDraft, onAddImages: { ... }, onRetryIndex: { ... })`
13. **`ClubGapFEReferenceRangeBar`** (`App/MPGap/Club/ClubGapRound4Views.swift`)
    - **Target:** `App/MPGap/Club/ClubGapReferenceSettlementView.swift`
    - **Code:** `ClubGapFEReferenceRangeBar(range: $rangeFilter, isExporting: isExporting, onExport: { ... })`
14. **`ClubGapGroupCodeSessionPickerView`** (`App/MPGap/Club/ClubGapRound4Views.swift`)
    - **Target:** `App/ClubGroupCodePresentation.swift`
    - **Code:** `ClubGapGroupCodeSessionPickerView(state: groupCodeStepState, onSelectSession: { ... }, onOpenManage: { ... })`

### Merchant-Coop
11. **`MerchantGapBatchVoucherRow`** (`App/MPGap/MerchantCoop/MerchantGapRound4Views.swift`)
    - **Target:** `App/MerchantLedgerSettlementOverview.swift` (`MerchantLedgerBatchDetailView`)
    - **Code:** `MerchantGapBatchVoucherRow(payVoucherNo: voucherNo, onCopy: { ... })`
12. **`MerchantGapAIInsightExtraSection`** (`App/MPGap/MerchantCoop/MerchantGapRound4Views.swift`)
    - **Target:** `App/MerchantMarketingView.swift`
    - **Code:** `MerchantGapAIInsightExtraSection(storeName: storeName, storeLogoURL: logoURL, heatCells: heatCells, axisFromLabel: axisFrom, poolCards: poolCards, onOpenCoopPool: { ... })`
13. **`MerchantGapDecorInactiveEmptyView`** (`App/MPGap/MerchantCoop/MerchantGapRound4Views.swift`)
    - **Target:** `App/MerchantOperationsViews.swift` (gallery & coop-setting)
    - **Code:** `MerchantGapDecorInactiveEmptyView(title: emptyTitle, onGoOnboarding: { ... })`
14. **`MerchantGapCityNodePosterAndMapViews`** (`App/MPGap/MerchantCoop/MerchantGapRound4Views.swift`)
    - **Target:** `App/MerchantCityNodeHubView.swift` & `App/MerchantCityNodeCreateView.swift`
    - **Code:** `MerchantGapCityNodePosterAndMapViews(codeText: codeText, addressTitle: addressTitle, latitude: lat, longitude: lng)`
15. **`CoopGapListAndDepositActionsView`** & **`CoopGapInvitePresetsSection`** (`App/MPGap/MerchantCoop/MerchantGapRound4Views.swift`)
    - **Target:** `App/CooperationBrowserView.swift`, `App/CooperationInviteActionSections.swift`, `App/CooperationContextualViews.swift`
    - **Code:** `CoopGapListAndDepositActionsView(...)` / `CoopGapInvitePresetsSection(...)`

### Account-Publish
11. **`ProjectEditGapRichStoryBlocksSection`**, **`ProjectEditGapCastEditorSheet`**, **`ProjectEditGapChapterExtrasSection`** (`App/MPGap/AccountPublish/AccountPublishGapRound4Views.swift`)
    - **Target:** `App/ProjectEditDetailForms.swift` & `App/ProjectEditView.swift`
    - **Code:** `ProjectEditGapRichStoryBlocksSection(...)`, `ProjectEditGapCastEditorSheet(...)`, `ProjectEditGapChapterExtrasSection(...)`
12. **`TemplateAuthoringGapRound4Section`** (`App/MPGap/AccountPublish/AccountPublishGapRound4Views.swift`)
    - **Target:** `App/TemplateAuthoringView.swift`
    - **Code:** `TemplateAuthoringGapRound4Section(draft: $round4Draft)`
13. **`TeamDetailGapSaveInviteImageRow`** (`App/MPGap/AccountPublish/AccountPublishGapRound4Views.swift`)
    - **Target:** `App/TeamHomeView.swift`
    - **Code:** `TeamDetailGapSaveInviteImageRow(onSaveConfirmed: { ... })`
