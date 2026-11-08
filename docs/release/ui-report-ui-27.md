# UI-27 report — NOT COMPILED

Owner scope: every `App/*.swift` not matched by UI-12..26 and not on the never-edit list (265 files reviewed by grep for raw colours/fonts/fixed heights).

## Changed (57 files, mechanical, presentation only)
Replaced raw system colours with `CYColor` tokens (theme: dark/player):

| Raw | Token |
|---|---|
| `Color.green` | `CYColor.successText` |
| `Color.red` | `CYColor.dangerText` |
| `Color.orange` | `CYColor.warningText` |
| `Color.secondary` | `CYColor.textSecondary` |

Opacity modifiers kept as-is. Mini-program page followed: none (internal release-gate/readiness section views); Revolut pattern: n/a.

## Not done
- `DiceD20View.swift`: procedural gold/silver dice shading uses computed RGB and fixed 150pt height; intentionally left (illustration, not themeable UI).
- `.font(.system(size:))`, fixed heights, and per-screen empty/error-state work in the remaining files not attempted: cannot compile, so kept the diff small and safe.
- Files already changed by cloud/ui-01..11 were skipped (none overlapped the edits).

## New string keys
None (`docs/release/ui-strings-ui-27.json` = empty list).

## Files touched
- App/AppClipAndQRCodeHandshakeSectionView.swift
- App/AppStoreConnectMetadataAndScreenshotSectionView.swift
- App/AppStorePrivacyManifestSectionView.swift
- App/AppStoreReviewRejectionPreventionSectionView.swift
- App/AppStoreSubmissionFinalPreflightGateView.swift
- App/AppStoreSubmissionReadinessSectionView.swift
- App/AssetPointsAndOrderCancellationSectionView.swift
- App/AudioAndMediaPipelineSectionView.swift
- App/AuthChannelView.swift
- App/BackendRolloutAllowlistSwitchboardSectionView.swift
- App/BackendSyncAndContractGateSectionView.swift
- App/ColdStartLaunchLatencyAndPrewarmSectionView.swift
- App/CommerceAndWalletSafetySectionView.swift
- App/CompleteWave1To3AndReformV9ShowcaseView.swift
- App/CrashResilienceAndMetricKitDiagnosticsSectionView.swift
- App/DeviceOrientationAndSplitViewAdaptationSectionView.swift
- App/EndToEndReleaseCandidateGateSectionView.swift
- App/FinalReleaseSignoffAndZeroGapCertificateView.swift
- App/FinalThreeDocumentAndSevenDayGoalCompletionView.swift
- App/FinalTwentyBatchMasterCompletionView.swift
- App/GameJournalCompositionAndPlaySummarySectionView.swift
- App/GrowthAndLeaderboardParitySectionView.swift
- App/IMExpandedViews.swift
- App/IMInboxViews.swift
- App/ImageAndVideoDiskCacheBudgetSectionView.swift
- App/InAppCustomerSupportAndFeedbackSectionView.swift
- App/KeychainAndBiometricSessionSecuritySectionView.swift
- App/LocalizationCompletenessSectionView.swift
- App/MasterReleaseSignoffDashboardView.swift
- App/MiniProgram99PageParitySectionView.swift
- App/MiniProgramVsNativeSupersetClassifierSectionView.swift
- App/MyProjectTabViews.swift
- App/NPCAISceneGuardSectionView.swift
- App/OfflineDurableRecoverySectionView.swift
- App/PhotoLibraryAndCameraPermissionSectionView.swift
- App/ProductionCanaryRolloutAndPhasedReleaseSectionView.swift
- App/PublishTopicAndCommentModerationSectionView.swift
- App/PushNotificationAndLiveActivitySectionView.swift
- App/QuestifyMotionComponents.swift
- App/ReformWorkPackagesW02ToW20SectionView.swift
- App/ReformWorldHostWorkbenchView.swift
- App/RegionalEndpointAllowlistSectionView.swift
- App/ReleaseArchiveChecklistSectionView.swift
- App/RunAuthorityHostSectionView.swift
- App/SQLiteAndJSONJournalCorruptionRecoverySectionView.swift
- App/ScheduleAndLeadProgressPollingSectionView.swift
- App/SevenDayLaunchCriticalPathSectionView.swift
- App/StoreKit2SubscriptionAndRefundSectionView.swift
- App/StoryRuleEditorView.swift
- App/StoryWalkingAndFogSectionView.swift
- App/TestFlightInternalAndExternalSmokeSectionView.swift
- App/ThreeDocumentMasterCrosswalkSectionView.swift
- App/UITestFlowReadinessAnchorSectionView.swift
- App/UltimateReleaseReadinessExecutiveSummaryView.swift
- App/Wave3HandoffStatusSectionView.swift
- App/WeChatAndAppleSignInNonceStateSectionView.swift
- App/ZeroRegressionLegacyServerIsolationSectionView.swift
