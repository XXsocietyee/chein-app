# Current CI Manifest Audit Receipt

- **Branch**: `ui/h-ci-manifest` (branched from `origin/ui/main` at `5ba7b0f2c5f10dea10905895da947c350b3e24ac`)
- **Prior Manifest Refresh Base**: `rc/20261108` (`a6871477c497c6440ce06417035572d7278ea830`)
- **Environment**: macOS workspace (`NO builds on this Mac`; static/Python inspection only)

## Summary Counts

| Metric | Prior (`rc/20261108`) | Current (`ui/h-ci-manifest`) | Delta |
|---|---:|---:|---:|
| Native test methods (`CoreTests`, `AppUnitTests`, `AppUITests`) | 24,328 | 25,789 | +1,468 / -7 |
| Portable checks (`Tests/ContractChecks`, `tools/tests`) | 7,145 | 7,401 | +264 / -8 |
| Device-only methods (`NOT_RUN` on simulator) | 8 | 8 | 0 |
| **Total inventoried methods** | **31,473** | **33,190** | **+1,732 / -15** |

- **Added**: **1,732** new methods (1,468 native + 264 portable) across **283** new test files (**229** new suites/classes) and **80** existing test files.
- **Removed / Retired (with explicit replacement)**: **15** methods (7 native + 8 portable). **0** test suites/classes were removed, and **0** test files were deleted or moved.
- **Pure renames**: **0** (all 15 changed/replaced method identities also updated assertions/behavior under owner decisions or branch contract updates).
- **Accidentally dropped / Restored**: **0** accidentally dropped; **0** restored.

## Manifest Mechanics & Policy Fixes

1. **Manifest size cap (`tools/current_ci.py`)**: `encode()` already emits compact JSON (`sort_keys=True`, `separators=(',', ':')`, no indentation, no duplicate keys checked by `unique()`). Because 1,732 added tests and 1,621 new tracked files pushed the compact manifest past 10 MiB (~10.23 MiB), `LIMIT` was raised from `10 * 1024 * 1024` to `16 * 1024 * 1024` with an explanatory comment.
2. **Replacement hash rebinding (`additional_base_test_reviews`)**: Six replacement test files referenced under historical bases `4e7349186` and `a8d387e20` changed since `rc/20261108`; each was reviewed and rebound to its current `sha256`.
3. **`CouponRuntimeChineseFlowTests` un-skip (`Tests/AppUITests/CouponRuntimeChineseFlowTests.swift`)**: Removed the unconditional `static let merchantSurfaceHiddenInV1 = true` skip added in `207b8b7d7d` (`uitest-14 r4`) and replaced it with `isProductionHostConfiguration`, so the test runs under DEBUG/TEST (`CouponRuntimeFixture` targets `https://coupon-runtime.example/native`) and skips only under non-DEBUG or explicit `www.chengyinhub.com` configuration. *Note (not simulator-verified here)*: `Tests/AppUITests/CouponRuntimeFlowTests.swift` still carries `merchantSurfaceHiddenInV1 = true`, and `App/AccountView.swift:287,326` still checks `themeDomain != .player` while `QuestifyApp.swift:325` sets `.roleTheme(.player)` on `playerTabs`.

## Replacement Bindings Reviewed in `additional_base_test_reviews` (6 files)

| Base & Replacement Method(s) | Status | Evidence |
|---|---|---|
| `4e7349186` -> `QuestifyUITests/CouponRuntimeChineseFlowTests/testChineseNormalRootLabelsAndReadOnlyConfirmation` | Rebound + permanent skip removed | `Tests/AppUITests/CouponRuntimeChineseFlowTests.swift`: commit `207b8b7d7d` (`uitest-14 r4`) had added `static let merchantSurfaceHiddenInV1 = true` (`XCTSkipIf(Self.merchantSurfaceHiddenInV1)`). Replaced with `isProductionHostConfiguration` so the test runs under DEBUG/TEST (`CouponRuntimeFixture` uses `https://coupon-runtime.example/native`) and skips only under non-DEBUG or explicit `www.chengyinhub.com`. Note: no simulator build/run on this Mac; `Tests/AppUITests/CouponRuntimeFlowTests.swift` still carries `merchantSurfaceHiddenInV1 = true`, and `App/AccountView.swift:287,326` still checks `themeDomain != .player` under `QuestifyApp.swift:325` (`.roleTheme(.player)`). |
| `4e7349186` -> `QuestifyUITests/IntegratedActivityPlayJourneyFlowTests/testActualPhoneHomeDetailManualMapPlayAndFreshOwnedOrderJourney`, `testNormalRootOwnedShelfPaginationAndDetailWithoutMutation` | Rebound | `Tests/AppUITests/IntegratedActivityPlayJourneyFlowTests.swift`: updated UI navigation selectors (`roam.more` overflow menu, `skipOnboardingIfPresent`, auto-submit 6th digit, tab renames `Explore`/`Passport`, `Settings` navigation, and `homeAndWalletSettled` wallet-preload filtering) while preserving both end-to-end journey methods and assertions. |
| `4e7349186` -> `QuestifyUITests/IntegratedDeniedAcceptanceFlowTests/testConfiguredAuthenticationDoesNotGrantDetailMapPlayOrOwnedOrders`, `testNormalRootIMHistoryDefaultNilNeverDispatches` | Rebound | `Tests/AppUITests/IntegratedDeniedAcceptanceFlowTests.swift`: updated UI navigation selectors (`roam.more`, `skipOnboardingIfPresent`, auto-submit 6th digit, `homeAndWalletSettled`, tab renames) while preserving both denied-acceptance methods and assertions. |
| `4e7349186` -> `Tests/ContractChecks/test_club_application_message.py::ClubApplicationMessageContracts.test_current_join_and_quit_json_preserve_numeric_id_and_only_application_message`, `test_membership_write_has_one_send_and_no_automatic_retry`, `test_leave_runtime_contract_cases_remain_authored` | Rebound | `Tests/ContractChecks/test_club_application_message.py`: strengthened with original-receipt idempotency header checks (`X-Club-Admission-*`), split `recover(` read from single-send write check, and updated SwiftUI modifier regex; all 3 replacement methods retained. |
| `a8d387e20` -> `Tests/ContractChecks/test_profile_favorite_removal.py::ProfileFavoriteRemovalSourceChecks.test_reconcile_clear_verifies_cleanup_or_quarantines` | Rebound | `Tests/ContractChecks/test_profile_favorite_removal.py`: updated `.onDisappear` and `.onChange(of: scope)` source snippet assertions to match added lifecycle/diagnostics logging in the view while keeping `test_reconcile_clear_verifies_cleanup_or_quarantines` intact. |
| `a8d387e20` -> `Tests/ContractChecks/test_team_contracts.py::TeamSourceChecks.test_verified_join_mode_contract_stays_dormant_and_strict` | Rebound | `Tests/ContractChecks/test_team_contracts.py`: updated to allow one `ShareLink(item: code)` inside `TeamInvitePreview`, `LocalPasteboard.copy(`, and `team.create.leaseClosed` in `Localizable.xcstrings` while keeping `test_verified_join_mode_contract_stays_dormant_and_strict` intact. |

## Removed, Renamed, or Moved Tests & Contract Checks (15)

| Test / Check | Status | Evidence |
|---|---|---|
| `QuestifyAppUnitTests/NativeAudioLifecycleTests/testInterruptionEndedDoesNotResumeOrStopExplicitRestart` | Retired (behaviour intentionally changed & replaced) | `Tests/AppUnitTests/NativePlatformAppTests.swift` · commit `1e48434aa` (`WP-11`, owner decision `OWN-OPT-042.a`): calls/alarms now pause audible playback and resume only what was playing instead of stopping playback. Replaced by `testInterruptionEndedNeverResumesUserPausedAudio`, `testInterruptionResumesOnlyAudioThatWasPlaying`, and `testBackgroundDuringInterruptionStopsAndNeverResumes` in `Tests/AppUnitTests/NativePlatformAppTests.swift`. |
| `QuestifyCoreTests/CityGameCoordinatorTests/testEndpointAllowlistIsEmptyAndCapabilityIsOffByDefault` | Retired (behaviour intentionally changed & replaced) | `Tests/CoreTests/CityGameCoordinatorTests.swift` · commit `8e8fa748a` (`citygame-prod`): empty per-market `CityGameEndpointAllowlist` / `CityGameOperation` gate was replaced by `CityGameProductionLease` (`ReviewedCityGameLease`). Replaced by `QuestifyCoreTests/CityGameCoordinatorTests/testCapabilityIsOffByDefault` in `Tests/CoreTests/CityGameCoordinatorTests.swift` (and `test_capability_comes_only_from_the_city_lease` in `Tests/ContractChecks/test_city_game_base.py`). |
| `QuestifyCoreTests/TopicTemplateUseTests/testFailureAndMissingTopicIdAreNotSuccess` | Retired (behaviour intentionally changed & replaced) | `Tests/CoreTests/TopicTemplateUseTests.swift` · commit `15aa3dad9` (`ui/cloud-h1-claude`): `/use` adopted idempotent `requestId` retries and `TopicTemplateUseReceipt` decoding (which rejects `topicId: 0` on decode). Replaced by `testFailureIsNotSuccessAndMintsAFreshIdNextTime` & `testUnknownKeepsRequestIdUntilTheReceiptIsRead` in `Tests/CoreTests/TopicTemplateUseTests.swift`, plus `TopicTemplateAdoptionTests/testUseReceiptKeepsTopicIdObjectAndIncrement` in `Tests/CoreTests/TopicTemplateAdoptionTests.swift`. |
| `QuestifyCoreTests/WalletCommerceTests/testSyntheticSourceTasksExcludeSpendRules` | Retired (behaviour intentionally changed & replaced) | `Tests/CoreTests/WalletCommerceTests.swift` · commit `1e48434aa` (`WP-11`, owner decision `OWN-D-01.a`): `eventType 14` spend rules (「积分消耗」) are no longer dropped from `pointsTasks`; `WalletPointsRules` splits earn and spend rules while `delFlag != 0` stays excluded. Replaced by `QuestifyCoreTests/WalletCommerceTests/testSyntheticSourceTasksSplitEarnAndSpendRules` in `Tests/CoreTests/WalletCommerceTests.swift`. |
| `QuestifyCoreTests/WorkshopPaidInstalledTextTests/testDifferentReceiptAndBroaderRightsCannotBindToCapturedInstallation` | Retired (behaviour intentionally changed & replaced) | `Tests/CoreTests/WorkshopPaidInstalledTextTests.swift` · commit `fad470999` (`ui/cur-workshop-v2`): installed-text migrated from v1 envelope to `w18-member-text-v1`, where `rights` is initialized from `reference.item` rather than a separate payload object. Receipt-binding mismatch rejection is replaced by `QuestifyCoreTests/WorkshopPaidInstalledTextTests/testDifferentReceiptCannotBindToCapturedInstallation` in `Tests/CoreTests/WorkshopPaidInstalledTextTests.swift`. |
| `QuestifyCoreTests/WorkshopPaidInstalledTextTests/testHashConsistentChangedMerchantGuideCannotPassSourceComparison` | Retired (behaviour intentionally changed & replaced) | `Tests/CoreTests/WorkshopPaidInstalledTextTests.swift` · commit `fad470999` (`ui/cur-workshop-v2`): `w18-member-text-v1` removed the v1 `componentJson`/`componentHash` envelope comparison from `WorkshopPaidInstalledText`. Field decoding and invalid-field/unknown-key rejection are replaced by `testChangedOriginalComponentTermsAndUnknownFieldsAreRejected` and `testNullOptionalFieldIsAbsentAndUnknownKeyIsRejected` in `Tests/CoreTests/WorkshopPaidInstalledTextTests.swift`. |
| `QuestifyUITests/GrowthNormalEntryPresentationTests/testKnownCheckinsAndStreakStayAvailableAcrossNativeBoardReturn` | Renamed & replaced (behaviour intentionally changed) | `Tests/AppUITests/GrowthNormalEntryPresentationTests.swift` · commit `e04147107` (`ui/u10-screens`, `B68`): Growth Center aligned to mini-program sections (score card, 我的足迹, 我的徽章), moving check-ins and streak to the profile growth card. Replaced by `QuestifyUITests/GrowthNormalEntryPresentationTests/testFootprintMetricsStayAvailableAcrossNativeBoardReturn` in `Tests/AppUITests/GrowthNormalEntryPresentationTests.swift`. |
| `Tests/ContractChecks/test_app_store_privacy_launch_contracts.py::AppStorePrivacyLaunchContracts.test_no_background_or_always_location_declarations` | Renamed & replaced (behaviour intentionally changed) | `Tests/ContractChecks/test_app_store_privacy_launch_contracts.py` · commit `1e48434aa` (`WP-11`, owner decision `OWN-D-07`): enabled session-scoped `UIBackgroundModes = ['location']` in `Config/Info.plist` while keeping When-In-Use only and forbidding `Always` location declarations. Replaced by `AppStorePrivacyLaunchContracts.test_no_always_location_and_only_session_background_location` in `Tests/ContractChecks/test_app_store_privacy_launch_contracts.py`. |
| `Tests/ContractChecks/test_city_game_base.py::CityGameBaseContracts.test_only_debug_fixtures_conform_to_the_proposed_services` | Renamed & replaced (behaviour intentionally changed) | `Tests/ContractChecks/test_city_game_base.py` · commit `8e8fa748a` (`citygame-prod`): added production `Core/CityGameHTTPService.swift` conformance alongside `App/CityGameFixtureHost.swift`. Replaced by `CityGameBaseContracts.test_only_the_production_service_and_debug_fixtures_conform` in `Tests/ContractChecks/test_city_game_base.py`. |
| `Tests/ContractChecks/test_city_game_base.py::CityGameBaseContracts.test_production_entry_points_pass_no_game_or_restore_model` | Renamed & replaced (behaviour intentionally changed) | `Tests/ContractChecks/test_city_game_base.py` · commit `8e8fa748a` (`citygame-prod`): production entry points now pass `session.cityGameFactory` and `session.playCityGame` under the production lease while keeping `CityGameSlot` isolated. Replaced by `CityGameBaseContracts.test_production_entry_points_pass_the_leased_game_and_no_restore_model` in `Tests/ContractChecks/test_city_game_base.py`. |
| `Tests/ContractChecks/test_city_game_base.py::CityGameBaseContracts.test_reviewed_allowlist_is_empty_and_capabilities_stay_off` | Retired (behaviour intentionally changed & replaced) | `Tests/ContractChecks/test_city_game_base.py` · commit `8e8fa748a` (`citygame-prod`): replaced empty per-market `CityGameEndpointAllowlist` gate with `CityGameProductionLease` (`ReviewedCityGameLease`) and `ReviewedPlayerWriteLeases`. Replaced by `CityGameBaseContracts.test_capability_comes_only_from_the_city_lease` (and `test_city_routes_move_no_money`) in `Tests/ContractChecks/test_city_game_base.py`. |
| `Tests/ContractChecks/test_template_own_shelf_read_state.py::TemplateOwnShelfReadStateContract.test_fragment_is_the_mini_wording_and_not_merged` | Renamed & replaced (behaviour intentionally changed) | `Tests/ContractChecks/test_template_own_shelf_read_state.py` · commit `d1c5378e4` (`Contract backlog 2 (part 1)`): fragment keys were merged into `Resources/Localizable.xcstrings` and translated into English. Replaced by `TemplateOwnShelfReadStateContract.test_fragment_is_the_mini_wording_and_is_merged` in `Tests/ContractChecks/test_template_own_shelf_read_state.py`. |
| `Tests/ContractChecks/test_workshop_paid_lifecycle_closure.py::PaidInstallLifecycleSourceContracts.test_core_matches_exact_original_functional_artifact` | Retired (behaviour intentionally changed & replaced) | `Tests/ContractChecks/test_workshop_paid_lifecycle_closure.py` · commit `0b170ed55` (`integ/next`): dead SHA-256 byte pin (never matched any tree in this repo) replaced by owner rule 2026-11-13 behavioral contract (`ReviewedAreaSwitch.moneyPayments` open on DEBUG/TEST hosts and closed on `www.chengyinhub.com`). Replaced by `PaidInstallLifecycleSourceContracts.test_paid_install_follows_the_money_switch` in `Tests/ContractChecks/test_workshop_paid_lifecycle_closure.py`. |
| `Tests/ContractChecks/test_workshop_paid_lifecycle_closure.py::PaidInstallLifecycleSourceContracts.test_original_service_and_journal_are_unchanged` | Retired (behaviour intentionally changed & replaced) | `Tests/ContractChecks/test_workshop_paid_lifecycle_closure.py` · commit `0b170ed55` (`integ/next`): dead SHA-256 byte pins on `WorkshopPaidInstallService.swift`, `WorkshopPaidInstallPendingStore.swift`, and `WorkshopPaidInstallContracts.swift` replaced with file-existence checks. Replaced by `PaidInstallLifecycleSourceContracts.test_service_and_journal_exist` in `Tests/ContractChecks/test_workshop_paid_lifecycle_closure.py`. |
| `tools/tests/test_app_unit_target.py::AppUnitTargetTests.test_shared_scheme_matches_target_and_isolated_from_ui_scheme` | Renamed & replaced (behaviour intentionally changed) | `tools/tests/test_app_unit_target.py` · commit `f64760f0a` (`cursor/cb117`): `Questify.xcscheme` was switched from `QuestifyUITests`-only to `QuestifyAppUnitTests-Shards.xctestplan` (covering both `QuestifyAppUnitTests` and `QuestifyUITests`). Replaced by `AppUnitTargetTests.test_shared_scheme_matches_target_and_questify_runs_every_class` in `tools/tests/test_app_unit_target.py`. |

## New Suites / Classes Added Since `rc/20261108` (229)

All 229 newly added suites/classes remain present in `HEAD` and are inventoried in `tools/current_ci_manifest.json`:

- `QuestifyAppUnitTests/BNDMountGuardTests`
- `QuestifyAppUnitTests/BeGapMerchantSwitchTests`
- `QuestifyAppUnitTests/BundleCommerceMountTests`
- `QuestifyAppUnitTests/CYCachedAsyncImageTests`
- `QuestifyAppUnitTests/FogOverlayLayerPixelTests`
- `QuestifyAppUnitTests/G6CapabilityGrantTests`
- `QuestifyAppUnitTests/IMInviteReminderControllerTests`
- `QuestifyAppUnitTests/IMPreviewTemplateLeaseFactoryTests`
- `QuestifyAppUnitTests/IMRecipientPreviewConversationSourceTests`
- `QuestifyAppUnitTests/IMReviewAuditReaderTests`
- `QuestifyAppUnitTests/MPParityDeepLinkRouteTests`
- `QuestifyAppUnitTests/MPParityPassBindingTests`
- `QuestifyAppUnitTests/MerchantOpsWp03GateTests`
- `QuestifyAppUnitTests/PayoutReceiverAppTests`
- `QuestifyAppUnitTests/PlayGapOwnerGrantTests`
- `QuestifyAppUnitTests/PlayerJourneyProductionTests`
- `QuestifyAppUnitTests/PlayerJourneyPromoTests`
- `QuestifyAppUnitTests/PostGameProjectionTests`
- `QuestifyAppUnitTests/PublicCatalogViewsTests`
- `QuestifyAppUnitTests/RevealChoreographerTests`
- `QuestifyAppUnitTests/ReviewedAreaSwitchTests`
- `QuestifyAppUnitTests/ReviewedSocialWriteLeaseTests`
- `QuestifyAppUnitTests/RootPresentationCoordinatorTests`
- `QuestifyAppUnitTests/SquareRouteMapProviderTests`
- `QuestifyAppUnitTests/WP06PartialPageHostTests`
- `QuestifyAppUnitTests/WP07CommerceLeaseTests`
- `QuestifyAppUnitTests/WP08HostTipLeaseTests`
- `QuestifyAppUnitTests/WP08ReceiveNativeURLAuditTests`
- `QuestifyAppUnitTests/WP09PresetsTeamAfterSaleTests`
- `QuestifyCoreTests/AccountCollectionFavoritesPageReadyTests`
- `QuestifyCoreTests/AccountDeletionEndToEndTests`
- `QuestifyCoreTests/AccountScopedPersistenceTests`
- `QuestifyCoreTests/ActivityDetailPageReadyTests`
- `QuestifyCoreTests/ActivityPublishingPageReadinessTests`
- `QuestifyCoreTests/AssetCenterAnalysisPageModelTests`
- `QuestifyCoreTests/BNDRefundProgressModelTests`
- `QuestifyCoreTests/BackendErrorCatalogTests`
- `QuestifyCoreTests/CB51LocalDiagnosticsTests`
- `QuestifyCoreTests/CB93RouteAdaptationTests`
- `QuestifyCoreTests/ChannelsContractAppSideTests`
- `QuestifyCoreTests/CharacterCardPageReadTests`
- `QuestifyCoreTests/CheinDeepLinkTests`
- `QuestifyCoreTests/ChinaReviewedRouteCapabilityTests`
- `QuestifyCoreTests/CityGameHTTPServiceTests`
- `QuestifyCoreTests/CloudL5IMSquareTests`
- `QuestifyCoreTests/CloudX1AuditBugTests`
- `QuestifyCoreTests/ClubBadgePageReadyTests`
- `QuestifyCoreTests/ClubCreatePageCoordinatorTests`
- `QuestifyCoreTests/ClubCreatePageFixtureDataTests`
- `QuestifyCoreTests/ClubCreatePageModelTests`
- `QuestifyCoreTests/ClubCustomersIndexPageReadyTests`
- `QuestifyCoreTests/ClubDetailPageReadyTests`
- `QuestifyCoreTests/ClubEditPageTests`
- `QuestifyCoreTests/ClubGapClientTests`
- `QuestifyCoreTests/ClubGroupCodePageReadyTests`
- `QuestifyCoreTests/ClubHostApplyPageModelTests`
- `QuestifyCoreTests/ClubNotifyPageTests`
- `QuestifyCoreTests/ClubOpsGovernancePageTests`
- `QuestifyCoreTests/ClubPlayerFlowTests`
- `QuestifyCoreTests/ClubTabPageModelTests`
- `QuestifyCoreTests/ConditionPackageClosureTests`
- `QuestifyCoreTests/ContentContractV1Tests`
- `QuestifyCoreTests/CoopInviteIndexReadinessTests`
- `QuestifyCoreTests/CoopListPageReadyTests`
- `QuestifyCoreTests/CooperationInviteDetailPageTests`
- `QuestifyCoreTests/CoreGapReaderBodyTests`
- `QuestifyCoreTests/CouponCodePageReadyTests`
- `QuestifyCoreTests/CouponInfoSettingsPageTests`
- `QuestifyCoreTests/CreatorStudioTransportTests`
- `QuestifyCoreTests/ExternalGameReviewClientTests`
- `QuestifyCoreTests/FogCellBitmapTests`
- `QuestifyCoreTests/FogCoverageReadingTests`
- `QuestifyCoreTests/FogMaskRasterizerTests`
- `QuestifyCoreTests/FreeExploreBundlePageReadyTests`
- `QuestifyCoreTests/G6CapabilitySourceTests`
- `QuestifyCoreTests/G7ClientRulesTests`
- `QuestifyCoreTests/GlobalSearchEntryReadinessTests`
- `QuestifyCoreTests/GrowthLeaderboardPageReadyTests`
- `QuestifyCoreTests/IMChatSessionPageTests`
- `QuestifyCoreTests/IMListPageReadyLoadTests`
- `QuestifyCoreTests/IMListPageReadyTests`
- `QuestifyCoreTests/IMPreviewTemplateLeaseTests`
- `QuestifyCoreTests/InformationDetailPageModelTests`
- `QuestifyCoreTests/InvoiceLaunchApplyPageTests`
- `QuestifyCoreTests/InvoiceLaunchTitleEditorReadTests`
- `QuestifyCoreTests/InvoiceLaunchTitlesPageTests`
- `QuestifyCoreTests/JourneyLoopSourceTests`
- `QuestifyCoreTests/JourneySeatRecoveryTests`
- `QuestifyCoreTests/MemberHomePageReadyTests`
- `QuestifyCoreTests/MerchantOpsWp03ClientTests`
- `QuestifyCoreTests/MiniProgramPageLinkTests`
- `QuestifyCoreTests/MiniProgramPagesTests`
- `QuestifyCoreTests/MyProjectPageReadyTests`
- `QuestifyCoreTests/NearbyMerchantPageTests`
- `QuestifyCoreTests/OPTTriageClosureTests`
- `QuestifyCoreTests/ObjectBadge3DPreviewTests`
- `QuestifyCoreTests/ObjectBadgeWallPageStateTests`
- `QuestifyCoreTests/OfficialInboxPageReadyTests`
- `QuestifyCoreTests/OfficialMinePageModelTests`
- `QuestifyCoreTests/OfficialOrganizerConsoleFixtureTests`
- `QuestifyCoreTests/OfficialOrganizerConsoleStateTests`
- `QuestifyCoreTests/OrderInfoPageModelTests`
- `QuestifyCoreTests/OrientScorePageReadyTests`
- `QuestifyCoreTests/OrientScoreReviewWriterTests`
- `QuestifyCoreTests/OwnerDecisionGuardTests`
- `QuestifyCoreTests/PWaveSecondWaveTests`
- `QuestifyCoreTests/ParticipantAddressListPageTests`
- `QuestifyCoreTests/ParticipationOrientScoreEntryTests`
- `QuestifyCoreTests/PassMarketPointsReadsTests`
- `QuestifyCoreTests/PayoutReceiverClientTests`
- `QuestifyCoreTests/PlatformPassPurchaseUnreachableTests`
- `QuestifyCoreTests/PlatformPassReadTests`
- `QuestifyCoreTests/PlayActionReceiptTests`
- `QuestifyCoreTests/PlayCreatorTailRoutesTests`
- `QuestifyCoreTests/PlayFullStoryH3Tests`
- `QuestifyCoreTests/PlayGapPartialsTests`
- `QuestifyCoreTests/PlayGuideInformationListModelTests`
- `QuestifyCoreTests/PlayHelpLadderTests`
- `QuestifyCoreTests/PlayIndexPageReadinessTests`
- `QuestifyCoreTests/PlayKitQuestoContractsTests`
- `QuestifyCoreTests/PlayKitStubWriteTests`
- `QuestifyCoreTests/PlayKitTimedChallengePageTests`
- `QuestifyCoreTests/PlayLeadTailServiceTests`
- `QuestifyCoreTests/PlayRecoveryH4Tests`
- `QuestifyCoreTests/PlayRuntimeGapTests`
- `QuestifyCoreTests/PlayTeamBackpackStateTests`
- `QuestifyCoreTests/PlayTeamItemCommandTests`
- `QuestifyCoreTests/PlayThemeReplayTests`
- `QuestifyCoreTests/PlayerCapabilityRoutesTests`
- `QuestifyCoreTests/PlayerGapRoutesTests`
- `QuestifyCoreTests/PlayerJourneyProductionLeaseTests`
- `QuestifyCoreTests/PlayerParityBRoutesTests`
- `QuestifyCoreTests/PointsHistoryPageModelTests`
- `QuestifyCoreTests/PostGameReportTests`
- `QuestifyCoreTests/PrivacyProtectionPageModelTests`
- `QuestifyCoreTests/ProductionPlayFinishRouteTests`
- `QuestifyCoreTests/ProfileInviteHistoryPageReadyTests`
- `QuestifyCoreTests/PublicCatalogHostTests`
- `QuestifyCoreTests/PublicContentShareLinkTests`
- `QuestifyCoreTests/PublishClarityH2Tests`
- `QuestifyCoreTests/PublishFabuPageModelTests`
- `QuestifyCoreTests/QuickPublishSimplePageTests`
- `QuestifyCoreTests/ReleaseMoneyWriteSwitchDerivationTests`
- `QuestifyCoreTests/RoamFinishAddressTests`
- `QuestifyCoreTests/RoamLocationPrimerStepTests`
- `QuestifyCoreTests/RoamPlaceCommentClientTests`
- `QuestifyCoreTests/RoamPlaceReviewAttemptTests`
- `QuestifyCoreTests/SettingsLegalAgreementPageTests`
- `QuestifyCoreTests/ShezhiMarketingIndexPageTests`
- `QuestifyCoreTests/SideQuestPlayerFlowTests`
- `QuestifyCoreTests/SignInWithAppleFlowTests`
- `QuestifyCoreTests/SquareDetailPageReadyTests`
- `QuestifyCoreTests/SquareOptionalCountModelTests`
- `QuestifyCoreTests/SquareRouteMapVerifiedTests`
- `QuestifyCoreTests/SquareStravaCardTests`
- `QuestifyCoreTests/StampAlbumIndexPageModelTests`
- `QuestifyCoreTests/StampAlbumIndexPagerProjectionTests`
- `QuestifyCoreTests/StampCameraPageReadyTests`
- `QuestifyCoreTests/TeamCommandWriterTests`
- `QuestifyCoreTests/TeamCreateClosedLeaseTests`
- `QuestifyCoreTests/TeamSeatFactsTests`
- `QuestifyCoreTests/TemplateAuthoringIntroReadModelTests`
- `QuestifyCoreTests/TemplateAuthoringPageReadinessTests`
- `QuestifyCoreTests/TemplateIndexPageModelTests`
- `QuestifyCoreTests/TopicCreatorEditorServiceTests`
- `QuestifyCoreTests/TopicPricingPageReadyTests`
- `QuestifyCoreTests/TopicTemplateAdoptionTests`
- `QuestifyCoreTests/UGGameplayTests`
- `QuestifyCoreTests/UniversalLinkParserTests`
- `QuestifyCoreTests/VideoBountySourceTests`
- `QuestifyCoreTests/WP04CoopSquareDeleteTests`
- `QuestifyCoreTests/WP07CommerceClientTests`
- `QuestifyCoreTests/WP08DeepLinkAuditCoverageTests`
- `QuestifyCoreTests/WP08HostTipSurfaceTests`
- `QuestifyCoreTests/WP11SessionLocationTests`
- `QuestifyCoreTests/WalletIncomeDetailPageModelTests`
- `QuestifyCoreTests/WorkshopPurchasedV2PathTests`
- `QuestifyUITests/Fixture_consentTests`
- `QuestifyUITests/Fixture_couponsTests`
- `QuestifyUITests/Fixture_d2_cityTests`
- `QuestifyUITests/Fixture_d2_homeTests`
- `QuestifyUITests/Fixture_d2_inboxTests`
- `QuestifyUITests/Fixture_d2_meTests`
- `QuestifyUITests/Fixture_d2_npcTests`
- `QuestifyUITests/Fixture_d2_playTests`
- `QuestifyUITests/Fixture_d2_roamTests`
- `QuestifyUITests/Fixture_d2_searchTests`
- `QuestifyUITests/Fixture_d2_search_resultsTests`
- `QuestifyUITests/Fixture_d2_squareTests`
- `QuestifyUITests/Fixture_d4_badgesTests`
- `QuestifyUITests/Fixture_d4_badges_emptyTests`
- `QuestifyUITests/Fixture_d4_badges_errorTests`
- `QuestifyUITests/Fixture_d4_channel_chatTests`
- `QuestifyUITests/Fixture_d4_channelsTests`
- `QuestifyUITests/Fixture_d4_confirmTests`
- `QuestifyUITests/Fixture_d4_detailTests`
- `QuestifyUITests/Fixture_d4_directoryTests`
- `QuestifyUITests/Fixture_d4_enrollTests`
- `QuestifyUITests/Fixture_d4_govTests`
- `QuestifyUITests/Fixture_d4_growthTests`
- `QuestifyUITests/Fixture_d4_join_confirmTests`
- `QuestifyUITests/Fixture_d4_leaderboardTests`
- `QuestifyUITests/Fixture_d4_membersTests`
- `QuestifyUITests/Fixture_d4_opsTests`
- `QuestifyUITests/Fixture_d4_ops_createTests`
- `QuestifyUITests/Fixture_d4_owner_detailTests`
- `QuestifyUITests/Fixture_d4_settingsTests`
- `QuestifyUITests/Fixture_d4_stampsTests`
- `QuestifyUITests/Fixture_d4_stamps_emptyTests`
- `QuestifyUITests/Fixture_d4_tab_eventsTests`
- `QuestifyUITests/Fixture_d4_tab_overviewTests`
- `QuestifyUITests/Fixture_d4_tab_postsTests`
- `QuestifyUITests/Fixture_d6_liveTests`
- `QuestifyUITests/Fixture_d6_playTests`
- `QuestifyUITests/Fixture_d6_play_loadingTests`
- `QuestifyUITests/Fixture_d6_real_liveTests`
- `QuestifyUITests/Fixture_d6_roamTests`
- `QuestifyUITests/Fixture_d6_searchTests`
- `QuestifyUITests/Fixture_detailTests`
- `QuestifyUITests/Fixture_e1_activitiesTests`
- `QuestifyUITests/Fixture_e1_activity_detailTests`
- `QuestifyUITests/Fixture_e1_bundle_detailTests`
- `QuestifyUITests/Fixture_e1_bundle_detail_offTests`
- `QuestifyUITests/Fixture_e1_bundle_shelfTests`
- `QuestifyUITests/Fixture_e1_bundle_shelf_emptyTests`
- `QuestifyUITests/Fixture_e1_bundle_shelf_errorTests`
- `QuestifyUITests/Fixture_e1_discoveryTests`
- `QuestifyUITests/MotionTourTests`
- `QuestifyUITests/PageFlowGoldenPathTests`

## New Tests & Contract Checks Not in `rc/20261108` Manifest (1,732)

| Test / Check | Status | Evidence |
|---|---|---|
| `QuestifyUITests/Fixture_consentTests/testConsentEnglish` | Added (new file) | `Tests/AppUITests/Fixture_consentTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_consentTests/testConsentSimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_consentTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_couponsTests/testCouponsDesignFixtureEnglish` | Added (new file) | `Tests/AppUITests/Fixture_couponsTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_couponsTests/testCouponsDesignFixtureSimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_couponsTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d2_cityTests/testD2CityEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d2_cityTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d2_cityTests/testD2CitySimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_d2_cityTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d2_homeTests/testD2HomeEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d2_homeTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d2_homeTests/testD2HomeZhHans` | Added (new file) | `Tests/AppUITests/Fixture_d2_homeTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d2_inboxTests/testD2InboxEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d2_inboxTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d2_inboxTests/testD2InboxSimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_d2_inboxTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d2_meTests/testD2MeEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d2_meTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d2_meTests/testD2MeZhHans` | Added (new file) | `Tests/AppUITests/Fixture_d2_meTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d2_npcTests/testD2NPCEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d2_npcTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d2_npcTests/testD2NPCSimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_d2_npcTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d2_playTests/testD2PlayEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d2_playTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d2_playTests/testD2PlaySimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_d2_playTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d2_roamTests/testD2RoamEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d2_roamTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d2_roamTests/testD2RoamSimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_d2_roamTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d2_searchTests/testD2SearchChinese` | Added (new file) | `Tests/AppUITests/Fixture_d2_searchTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d2_searchTests/testD2SearchEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d2_searchTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d2_search_resultsTests/testD2SearchResultsEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d2_search_resultsTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d2_search_resultsTests/testD2SearchResultsZhHans` | Added (new file) | `Tests/AppUITests/Fixture_d2_search_resultsTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d2_squareTests/testD2SquareEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d2_squareTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d2_squareTests/testD2SquareSimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_d2_squareTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_badgesTests/testD4BadgesEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d4_badgesTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_badgesTests/testD4BadgesSimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_d4_badgesTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_badges_emptyTests/testEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d4_badges_emptyTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_badges_emptyTests/testSimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_d4_badges_emptyTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_badges_errorTests/testD4BadgesErrorEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d4_badges_errorTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_badges_errorTests/testD4BadgesErrorSimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_d4_badges_errorTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_channel_chatTests/testEnglishDesignFixture` | Added (new file) | `Tests/AppUITests/Fixture_d4_channel_chatTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_channel_chatTests/testSimplifiedChineseDesignFixture` | Added (new file) | `Tests/AppUITests/Fixture_d4_channel_chatTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_channelsTests/testD4ChannelsEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d4_channelsTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_channelsTests/testD4ChannelsSimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_d4_channelsTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_confirmTests/testD4ConfirmEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d4_confirmTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_confirmTests/testD4ConfirmZhHans` | Added (new file) | `Tests/AppUITests/Fixture_d4_confirmTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_detailTests/testD4DetailEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d4_detailTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_detailTests/testD4DetailSimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_d4_detailTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_directoryTests/testDirectoryEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d4_directoryTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_directoryTests/testDirectorySimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_d4_directoryTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_enrollTests/testD4EnrollChinese` | Added (new file) | `Tests/AppUITests/Fixture_d4_enrollTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_enrollTests/testD4EnrollEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d4_enrollTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_govTests/testD4GovEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d4_govTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_govTests/testD4GovSimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_d4_govTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_growthTests/testD4GrowthEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d4_growthTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_growthTests/testD4GrowthSimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_d4_growthTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_join_confirmTests/testEnglishJoinConfirmFixture` | Added (new file) | `Tests/AppUITests/Fixture_d4_join_confirmTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_join_confirmTests/testSimplifiedChineseJoinConfirmFixture` | Added (new file) | `Tests/AppUITests/Fixture_d4_join_confirmTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_leaderboardTests/testD4LeaderboardEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d4_leaderboardTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_leaderboardTests/testD4LeaderboardZhHans` | Added (new file) | `Tests/AppUITests/Fixture_d4_leaderboardTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_membersTests/testD4MembersChinese` | Added (new file) | `Tests/AppUITests/Fixture_d4_membersTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_membersTests/testD4MembersEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d4_membersTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_opsTests/testD4OpsEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d4_opsTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_opsTests/testD4OpsZhHans` | Added (new file) | `Tests/AppUITests/Fixture_d4_opsTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_ops_createTests/testD4OpsCreateEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d4_ops_createTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_ops_createTests/testD4OpsCreateZhHans` | Added (new file) | `Tests/AppUITests/Fixture_d4_ops_createTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_owner_detailTests/testD4OwnerDetailEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d4_owner_detailTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_owner_detailTests/testD4OwnerDetailSimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_d4_owner_detailTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_settingsTests/testEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d4_settingsTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_settingsTests/testSimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_d4_settingsTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_stampsTests/testD4StampsEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d4_stampsTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_stampsTests/testD4StampsZhHans` | Added (new file) | `Tests/AppUITests/Fixture_d4_stampsTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_stamps_emptyTests/testEnglishDesignFixture` | Added (new file) | `Tests/AppUITests/Fixture_d4_stamps_emptyTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_stamps_emptyTests/testSimplifiedChineseDesignFixture` | Added (new file) | `Tests/AppUITests/Fixture_d4_stamps_emptyTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_tab_eventsTests/testD4TabEventsEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d4_tab_eventsTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_tab_eventsTests/testD4TabEventsSimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_d4_tab_eventsTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_tab_overviewTests/testEnglishDesignFixture` | Added (new file) | `Tests/AppUITests/Fixture_d4_tab_overviewTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_tab_overviewTests/testSimplifiedChineseDesignFixture` | Added (new file) | `Tests/AppUITests/Fixture_d4_tab_overviewTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_tab_postsTests/testEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d4_tab_postsTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d4_tab_postsTests/testSimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_d4_tab_postsTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d6_liveTests/testD6LiveEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d6_liveTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d6_liveTests/testD6LiveSimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_d6_liveTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d6_playTests/testD6PlayEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d6_playTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d6_playTests/testD6PlaySimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_d6_playTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d6_play_loadingTests/testD6PlayLoadingEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d6_play_loadingTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d6_play_loadingTests/testD6PlayLoadingSimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_d6_play_loadingTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d6_real_liveTests/testD6RealLiveEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d6_real_liveTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d6_real_liveTests/testD6RealLiveSimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_d6_real_liveTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d6_roamTests/testD6RoamEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d6_roamTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d6_roamTests/testD6RoamSimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_d6_roamTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d6_searchTests/testD6SearchEnglish` | Added (new file) | `Tests/AppUITests/Fixture_d6_searchTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_d6_searchTests/testD6SearchSimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_d6_searchTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_detailTests/testDetailEnglish` | Added (new file) | `Tests/AppUITests/Fixture_detailTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_detailTests/testDetailSimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_detailTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_e1_activitiesTests/testE1ActivitiesEnglish` | Added (new file) | `Tests/AppUITests/Fixture_e1_activitiesTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_e1_activitiesTests/testE1ActivitiesSimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_e1_activitiesTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_e1_activity_detailTests/testE1ActivityDetailEnglish` | Added (new file) | `Tests/AppUITests/Fixture_e1_activity_detailTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_e1_activity_detailTests/testE1ActivityDetailSimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_e1_activity_detailTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_e1_bundle_detailTests/testE1BundleDetailEnglish` | Added (new file) | `Tests/AppUITests/Fixture_e1_bundle_detailTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_e1_bundle_detailTests/testE1BundleDetailZhHans` | Added (new file) | `Tests/AppUITests/Fixture_e1_bundle_detailTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_e1_bundle_detail_offTests/testE1BundleDetailOffEnglish` | Added (new file) | `Tests/AppUITests/Fixture_e1_bundle_detail_offTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_e1_bundle_detail_offTests/testE1BundleDetailOffSimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_e1_bundle_detail_offTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_e1_bundle_shelfTests/testE1BundleShelfEnglish` | Added (new file) | `Tests/AppUITests/Fixture_e1_bundle_shelfTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_e1_bundle_shelfTests/testE1BundleShelfSimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_e1_bundle_shelfTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_e1_bundle_shelf_emptyTests/testE1BundleShelfEmptyEnglish` | Added (new file) | `Tests/AppUITests/Fixture_e1_bundle_shelf_emptyTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_e1_bundle_shelf_emptyTests/testE1BundleShelfEmptyZhHans` | Added (new file) | `Tests/AppUITests/Fixture_e1_bundle_shelf_emptyTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_e1_bundle_shelf_errorTests/testE1BundleShelfErrorEnglish` | Added (new file) | `Tests/AppUITests/Fixture_e1_bundle_shelf_errorTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_e1_bundle_shelf_errorTests/testE1BundleShelfErrorSimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_e1_bundle_shelf_errorTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_e1_discoveryTests/testE1DiscoveryEnglish` | Added (new file) | `Tests/AppUITests/Fixture_e1_discoveryTests.swift` · `ba3b229cf` |
| `QuestifyUITests/Fixture_e1_discoveryTests/testE1DiscoverySimplifiedChinese` | Added (new file) | `Tests/AppUITests/Fixture_e1_discoveryTests.swift` · `ba3b229cf` |
| `QuestifyUITests/GrowthNormalEntryPresentationTests/testFootprintMetricsStayAvailableAcrossNativeBoardReturn` | Added (existing file) | `Tests/AppUITests/GrowthNormalEntryPresentationTests.swift` · `e04147107` |
| `QuestifyUITests/IMMessagingParityUITests/testInboxRowTapNavigatesToConversation` | Added (existing file) | `Tests/AppUITests/IMMessagingParityUITests.swift` · `7bdf4dfda` |
| `QuestifyUITests/MotionTourTests/testTour1TodayAndRailCardsZoom` | Added (new file) | `Tests/AppUITests/MotionTourTests.swift` · `526577aa2`, `3e106992b`, `c466dc67c`, `36fba42ef` |
| `QuestifyUITests/MotionTourTests/testTour2ClubCardZoom` | Added (new file) | `Tests/AppUITests/MotionTourTests.swift` · `526577aa2`, `3e106992b`, `c466dc67c`, `36fba42ef` |
| `QuestifyUITests/MotionTourTests/testTour3PassportStampZoom` | Added (new file) | `Tests/AppUITests/MotionTourTests.swift` · `526577aa2`, `3e106992b`, `c466dc67c`, `36fba42ef` |
| `QuestifyUITests/MotionTourTests/testTour4TabPill` | Added (new file) | `Tests/AppUITests/MotionTourTests.swift` · `526577aa2`, `3e106992b`, `c466dc67c`, `36fba42ef` |
| `QuestifyUITests/PageFlowGoldenPathTests/testGuestWalksFourTabRootsAndBack` | Added (new file) | `Tests/AppUITests/PageFlowGoldenPathTests.swift` · `05230cef3` |
| `QuestifyUITests/SettingsNativeFlowTests/testSettingsRowTapsNavigate` | Added (existing file) | `Tests/AppUITests/SettingsNativeFlowTests.swift` · `4a157c02c`, `7bdf4dfda` |
| `QuestifyAppUnitTests/AppCompositionRootTests/testColdRestoreKeepsStoredLoginRoleWhenUserInfoOmitsRole` | Added (existing file) | `Tests/AppUnitTests/AppCompositionRootTests.swift` · `4c5e89ecc` |
| `QuestifyAppUnitTests/AppCompositionRootTests/testColdRestoreNeverAppliesStoredRoleToAnotherAccount` | Added (existing file) | `Tests/AppUnitTests/AppCompositionRootTests.swift` · `4c5e89ecc` |
| `QuestifyAppUnitTests/BNDMountGuardTests/testCancelFactoryStillGatedByDefault` | Added (new file) | `Tests/AppUnitTests/BNDMountGuardTests.swift` · `4dfde0b58` |
| `QuestifyAppUnitTests/BNDMountGuardTests/testMoneySwitchesStayFalse` | Added (new file) | `Tests/AppUnitTests/BNDMountGuardTests.swift` · `4dfde0b58` |
| `QuestifyAppUnitTests/BNDMountGuardTests/testNoBundleProviderNonNilInShippedBuild` | Added (new file) | `Tests/AppUnitTests/BNDMountGuardTests.swift` · `4dfde0b58` |
| `QuestifyAppUnitTests/BNDMountGuardTests/testRefundAndReadFactoriesStayClosedWithoutAnApprovalAndDoNotSend` | Added (new file) | `Tests/AppUnitTests/BNDMountGuardTests.swift` · `4dfde0b58` |
| `QuestifyAppUnitTests/BNDMountGuardTests/testReservationDispatchStillOffByDefault` | Added (new file) | `Tests/AppUnitTests/BNDMountGuardTests.swift` · `4dfde0b58` |
| `QuestifyAppUnitTests/BNDMountGuardTests/testShippedCompositionStillUnconfigured` | Added (new file) | `Tests/AppUnitTests/BNDMountGuardTests.swift` · `4dfde0b58` |
| `QuestifyAppUnitTests/BeGapMerchantSwitchTests/testDebugNonProductionHostOpensTheFourSwitches` | Added (new file) | `Tests/AppUnitTests/BeGapMerchantSwitchTests.swift` · `3bfd9bfc0` |
| `QuestifyAppUnitTests/BeGapMerchantSwitchTests/testOwnerGrantAdmitsMerchantReadsAndStillRefusesMoney` | Added (new file) | `Tests/AppUnitTests/BeGapMerchantSwitchTests.swift` · `3bfd9bfc0` |
| `QuestifyAppUnitTests/BeGapMerchantSwitchTests/testReleaseAndProductionHostStayClosed` | Added (new file) | `Tests/AppUnitTests/BeGapMerchantSwitchTests.swift` · `3bfd9bfc0` |
| `QuestifyAppUnitTests/BundleCommerceMountTests/testAbsentCapabilityHidesEveryEntry` | Added (new file) | `Tests/AppUnitTests/BundleCommerceMountTests.swift` · `76d2b1089`, `517c3d4ee` |
| `QuestifyAppUnitTests/BundleCommerceMountTests/testCancelWriteIsNotSentWhenDisabled` | Added (new file) | `Tests/AppUnitTests/BundleCommerceMountTests.swift` · `76d2b1089`, `517c3d4ee` |
| `QuestifyAppUnitTests/BundleCommerceMountTests/testChinaShowsOnlyAdmittedReads` | Added (new file) | `Tests/AppUnitTests/BundleCommerceMountTests.swift` · `76d2b1089`, `517c3d4ee` |
| `QuestifyAppUnitTests/BundleCommerceMountTests/testFixtureHostMountsEveryNonMoneyEntry` | Added (new file) | `Tests/AppUnitTests/BundleCommerceMountTests.swift` · `76d2b1089`, `517c3d4ee` |
| `QuestifyAppUnitTests/BundleCommerceMountTests/testMoneyActionsStayUnmounted` | Added (new file) | `Tests/AppUnitTests/BundleCommerceMountTests.swift` · `76d2b1089`, `517c3d4ee` |
| `QuestifyAppUnitTests/BundleCommerceMountTests/testNilBaseHidesEveryEntry` | Added (new file) | `Tests/AppUnitTests/BundleCommerceMountTests.swift` · `76d2b1089`, `517c3d4ee` |
| `QuestifyAppUnitTests/BundleCommerceMountTests/testQuoteTransportAllowsOnlyTheBoundGet` | Added (new file) | `Tests/AppUnitTests/BundleCommerceMountTests.swift` · `76d2b1089`, `517c3d4ee` |
| `QuestifyAppUnitTests/CYCachedAsyncImageTests/testADifferentImageDoesNotReuseAnotherCacheEntry` | Added (new file) | `Tests/AppUnitTests/CYCachedAsyncImageTests.swift` · `8f92c0fcc` |
| `QuestifyAppUnitTests/CYCachedAsyncImageTests/testCoverAndShelfFramesStayDistinct` | Added (new file) | `Tests/AppUnitTests/CYCachedAsyncImageTests.swift` · `8f92c0fcc` |
| `QuestifyAppUnitTests/CYCachedAsyncImageTests/testEmptyOversizedAndUndecodableBytesFailAndStayUncached` | Added (new file) | `Tests/AppUnitTests/CYCachedAsyncImageTests.swift` · `8f92c0fcc` |
| `QuestifyAppUnitTests/CYCachedAsyncImageTests/testImageMissingFromTheCacheStaysOnThePlaceholder` | Added (new file) | `Tests/AppUnitTests/CYCachedAsyncImageTests.swift` · `8f92c0fcc` |
| `QuestifyAppUnitTests/CYCachedAsyncImageTests/testLeastRecentlyUsedImageIsEvicted` | Added (new file) | `Tests/AppUnitTests/CYCachedAsyncImageTests.swift` · `8f92c0fcc` |
| `QuestifyAppUnitTests/CYCachedAsyncImageTests/testLoadFailureIsVisibleAndNotCached` | Added (new file) | `Tests/AppUnitTests/CYCachedAsyncImageTests.swift` · `8f92c0fcc` |
| `QuestifyAppUnitTests/CYCachedAsyncImageTests/testLocalLoadIsCachedAndASecondLookupDoesNotLoadAgain` | Added (new file) | `Tests/AppUnitTests/CYCachedAsyncImageTests.swift` · `8f92c0fcc` |
| `QuestifyAppUnitTests/CYCachedAsyncImageTests/testStateIdentifiersStayOnPlaceholderFailureAndImage` | Added (new file) | `Tests/AppUnitTests/CYCachedAsyncImageTests.swift` · `8f92c0fcc` |
| `QuestifyAppUnitTests/CYCachedAsyncImageTests/testUnknownReferenceStaysOnThePlaceholderWithoutLoading` | Added (new file) | `Tests/AppUnitTests/CYCachedAsyncImageTests.swift` · `8f92c0fcc` |
| `QuestifyAppUnitTests/FogOverlayLayerPixelTests/testConfirmedCellCentresAreCutOut` | Added (new file) | `Tests/AppUnitTests/FogOverlayLayerPixelTests.swift` · `6dc788d27`, `157877aef`, `4c5a21b1e`, `d7e9fbd84` |
| `QuestifyAppUnitTests/FogOverlayLayerPixelTests/testEveryUnknownCoveragePrintsAnEmDashNeverZero` | Added (new file) | `Tests/AppUnitTests/FogOverlayLayerPixelTests.swift` · `6dc788d27`, `157877aef`, `4c5a21b1e`, `d7e9fbd84` |
| `QuestifyAppUnitTests/FogOverlayLayerPixelTests/testFeatherMathKeepsInteriorClearAndOutsideFogged` | Added (new file) | `Tests/AppUnitTests/FogOverlayLayerPixelTests.swift` · `6dc788d27`, `157877aef`, `4c5a21b1e`, `d7e9fbd84` |
| `QuestifyAppUnitTests/FogOverlayLayerPixelTests/testFeatherRoundsCornersInsteadOfAxisAlignedRectangles` | Added (new file) | `Tests/AppUnitTests/FogOverlayLayerPixelTests.swift` · `6dc788d27`, `157877aef`, `4c5a21b1e`, `d7e9fbd84` |
| `QuestifyAppUnitTests/FogOverlayLayerPixelTests/testFrontierGlowIsWarm` | Added (new file) | `Tests/AppUnitTests/FogOverlayLayerPixelTests.swift` · `6dc788d27`, `157877aef`, `4c5a21b1e`, `d7e9fbd84` |
| `QuestifyAppUnitTests/FogOverlayLayerPixelTests/testMaskRebuildsOnlyOnBitmapWindowOrLevelOfDetailChange` | Added (new file) | `Tests/AppUnitTests/FogOverlayLayerPixelTests.swift` · `6dc788d27`, `157877aef`, `4c5a21b1e`, `d7e9fbd84` |
| `QuestifyAppUnitTests/FogOverlayLayerPixelTests/testPendingCellsAreClearWithADashedOutlineNotAHatchBlock` | Added (new file) | `Tests/AppUnitTests/FogOverlayLayerPixelTests.swift` · `6dc788d27`, `157877aef`, `4c5a21b1e`, `d7e9fbd84` |
| `QuestifyAppUnitTests/FogOverlayLayerPixelTests/testPlainScrimMatchesTheStyleOpacity` | Added (new file) | `Tests/AppUnitTests/FogOverlayLayerPixelTests.swift` · `6dc788d27`, `157877aef`, `4c5a21b1e`, `d7e9fbd84` |
| `QuestifyAppUnitTests/FogOverlayLayerPixelTests/testScrimIsClearlyVisibleOutsideAndGoneInsideInBothAppearances` | Added (new file) | `Tests/AppUnitTests/FogOverlayLayerPixelTests.swift` · `6dc788d27`, `157877aef`, `4c5a21b1e`, `d7e9fbd84` |
| `QuestifyAppUnitTests/FogOverlayLayerPixelTests/testSoftEdgeRollsOffMonotonicallyAcrossTheBoundary` | Added (new file) | `Tests/AppUnitTests/FogOverlayLayerPixelTests.swift` · `6dc788d27`, `157877aef`, `4c5a21b1e`, `d7e9fbd84` |
| `QuestifyAppUnitTests/FogOverlayLayerPixelTests/testViewportCentreMapsToViewCentreAndWindowFillsView` | Added (new file) | `Tests/AppUnitTests/FogOverlayLayerPixelTests.swift` · `6dc788d27`, `157877aef`, `4c5a21b1e`, `d7e9fbd84` |
| `QuestifyAppUnitTests/G6CapabilityGrantTests/testShippedChinaAdmitsG6PathsAndKeepsMoneyClosed` | Added (new file) | `Tests/AppUnitTests/G6CapabilityGrantTests.swift` · `83796dab6` |
| `QuestifyAppUnitTests/HomeFeedReturnModelTests/testReadinessStartsLoadingThenBecomesEmptyErrorOrReady` | Added (existing file) | `Tests/AppUnitTests/HomeFeedReturnModelTests.swift` · `c5150bf32` |
| `QuestifyAppUnitTests/IMInviteReminderControllerTests/testAllowedPrimerAndVisibleAlertsTurnsOn` | Added (new file) | `Tests/AppUnitTests/IMInviteReminderControllerTests.swift` · `6e23c33e3`, `e8e6cbbc9` |
| `QuestifyAppUnitTests/IMInviteReminderControllerTests/testAllowedPrimerWithSystemDenialStaysOff` | Added (new file) | `Tests/AppUnitTests/IMInviteReminderControllerTests.swift` · `6e23c33e3`, `e8e6cbbc9` |
| `QuestifyAppUnitTests/IMInviteReminderControllerTests/testAlreadyDeniedDoesNotShowThePrimer` | Added (new file) | `Tests/AppUnitTests/IMInviteReminderControllerTests.swift` · `6e23c33e3`, `e8e6cbbc9` |
| `QuestifyAppUnitTests/IMInviteReminderControllerTests/testDeniedPrimerStaysOffAndDoesNotRequest` | Added (new file) | `Tests/AppUnitTests/IMInviteReminderControllerTests.swift` · `6e23c33e3`, `e8e6cbbc9` |
| `QuestifyAppUnitTests/IMInviteReminderControllerTests/testExistingVisibleGrantStoresTheLocalChoiceWithoutASecondPrompt` | Added (new file) | `Tests/AppUnitTests/IMInviteReminderControllerTests.swift` · `6e23c33e3`, `e8e6cbbc9` |
| `QuestifyAppUnitTests/IMInviteReminderControllerTests/testQuietAndUnknownSystemStatusesAreNotAVisibleGrant` | Added (new file) | `Tests/AppUnitTests/IMInviteReminderControllerTests.swift` · `6e23c33e3`, `e8e6cbbc9` |
| `QuestifyAppUnitTests/IMInviteReminderControllerTests/testReloadKeepsUnknownPermissionAsUnknownAndOff` | Added (new file) | `Tests/AppUnitTests/IMInviteReminderControllerTests.swift` · `6e23c33e3`, `e8e6cbbc9` |
| `QuestifyAppUnitTests/IMInviteReminderControllerTests/testStoredChoiceWithVisibleAlertsTurnsOn` | Added (new file) | `Tests/AppUnitTests/IMInviteReminderControllerTests.swift` · `6e23c33e3`, `e8e6cbbc9` |
| `QuestifyAppUnitTests/IMInviteReminderControllerTests/testStoredChoiceWithoutAlertsStaysOff` | Added (new file) | `Tests/AppUnitTests/IMInviteReminderControllerTests.swift` · `6e23c33e3`, `e8e6cbbc9` |
| `QuestifyAppUnitTests/IMInviteReminderControllerTests/testTurningOffClearsTheLocalChoiceWithoutClaimingAGrant` | Added (new file) | `Tests/AppUnitTests/IMInviteReminderControllerTests.swift` · `6e23c33e3`, `e8e6cbbc9` |
| `QuestifyAppUnitTests/IMInviteReminderControllerTests/testUnavailablePrimerStaysOffAndDoesNotClaimAGrant` | Added (new file) | `Tests/AppUnitTests/IMInviteReminderControllerTests.swift` · `6e23c33e3`, `e8e6cbbc9` |
| `QuestifyAppUnitTests/IMInviteReminderControllerTests/testUnknownMarkIsAnEmDash` | Added (new file) | `Tests/AppUnitTests/IMInviteReminderControllerTests.swift` · `6e23c33e3`, `e8e6cbbc9` |
| `QuestifyAppUnitTests/IMInviteReminderControllerTests/testUnreadableCurrentPermissionDoesNotPromptOrGrant` | Added (new file) | `Tests/AppUnitTests/IMInviteReminderControllerTests.swift` · `6e23c33e3`, `e8e6cbbc9` |
| `QuestifyAppUnitTests/IMInviteReminderControllerTests/testUnreadablePermissionAfterThePrimerStaysUnknown` | Added (new file) | `Tests/AppUnitTests/IMInviteReminderControllerTests.swift` · `6e23c33e3`, `e8e6cbbc9` |
| `QuestifyAppUnitTests/IMPreviewTemplateLeaseFactoryTests/testFactoryIssuesOnlyCatalogTemplatesForTheBoundConversation` | Added (new file) | `Tests/AppUnitTests/IMPreviewTemplateLeaseFactoryTests.swift` · `f4d67c77e` |
| `QuestifyAppUnitTests/IMRecipientPreviewConversationSourceTests/testClosedLeaseAndNilIssueShowAnEmDash` | Added (new file) | `Tests/AppUnitTests/IMRecipientPreviewConversationSourceTests.swift` · `4567bbc00` |
| `QuestifyAppUnitTests/IMRecipientPreviewConversationSourceTests/testLeaseForConversationADoesNotPreviewMessageInConversationB` | Added (new file) | `Tests/AppUnitTests/IMRecipientPreviewConversationSourceTests.swift` · `4567bbc00` |
| `QuestifyAppUnitTests/IMRecipientPreviewConversationSourceTests/testLoadingEmptyErrorAndRefusedStayVisible` | Added (new file) | `Tests/AppUnitTests/IMRecipientPreviewConversationSourceTests.swift` · `4567bbc00` |
| `QuestifyAppUnitTests/IMRecipientPreviewConversationSourceTests/testMessageConversationIDIsTheDecodedMessageConversationID` | Added (new file) | `Tests/AppUnitTests/IMRecipientPreviewConversationSourceTests.swift` · `4567bbc00` |
| `QuestifyAppUnitTests/IMRecipientPreviewConversationSourceTests/testScreenIssuesTheSixGetsForTheDecodedConversation` | Added (new file) | `Tests/AppUnitTests/IMRecipientPreviewConversationSourceTests.swift` · `4567bbc00` |
| `QuestifyAppUnitTests/IMReviewAuditReaderTests/testClosedGroupTitlesAndBadIdsDoNotSend` | Added (new file) | `Tests/AppUnitTests/IMReviewAuditReaderTests.swift` · `639acb5df` |
| `QuestifyAppUnitTests/IMReviewAuditReaderTests/testFailureStatusesDoNotInventARecordOrAWrite` | Added (new file) | `Tests/AppUnitTests/IMReviewAuditReaderTests.swift` · `639acb5df` |
| `QuestifyAppUnitTests/IMReviewAuditReaderTests/testKnownTaskReadsStatusAndTimelineFromTheApplicantDetail` | Added (new file) | `Tests/AppUnitTests/IMReviewAuditReaderTests.swift` · `639acb5df` |
| `QuestifyAppUnitTests/IMReviewAuditReaderTests/testUnknownFieldsAreAnEmDashAndAMissingTaskIsNotARecord` | Added (new file) | `Tests/AppUnitTests/IMReviewAuditReaderTests.swift` · `639acb5df` |
| `QuestifyAppUnitTests/MPParityDeepLinkRouteTests/testEveryReviewedPageMapsToARoute` | Added (new file) | `Tests/AppUnitTests/MPParityDeepLinkRouteTests.swift` · `10d2596e8` |
| `QuestifyAppUnitTests/MPParityDeepLinkRouteTests/testGiftAndJourneyLandingAreReachable` | Added (new file) | `Tests/AppUnitTests/MPParityDeepLinkRouteTests.swift` · `10d2596e8` |
| `QuestifyAppUnitTests/MPParityDeepLinkRouteTests/testRevealFromALinkCarriesNoPaidFacts` | Added (new file) | `Tests/AppUnitTests/MPParityDeepLinkRouteTests.swift` · `10d2596e8` |
| `QuestifyAppUnitTests/MPParityPassBindingTests/testBindingSourceDoesNotCallWriteMethods` | Added (new file) | `Tests/AppUnitTests/MPParityPassBindingTests.swift` · `11b0b01d1`, `ae8a67be3` |
| `QuestifyAppUnitTests/MPParityPassBindingTests/testReadTransportRefusesPurchaseQuoteOrderAndClaim` | Added (new file) | `Tests/AppUnitTests/MPParityPassBindingTests.swift` · `11b0b01d1`, `ae8a67be3` |
| `QuestifyAppUnitTests/MPParityPassBindingTests/testStoreCardCheckoutAndOrderFactsDoNotOpenPurchase` | Added (new file) | `Tests/AppUnitTests/MPParityPassBindingTests.swift` · `11b0b01d1`, `ae8a67be3` |
| `QuestifyAppUnitTests/MPParityPassBindingTests/testViewerMerchantAndMembershipStayReadOnly` | Added (new file) | `Tests/AppUnitTests/MPParityPassBindingTests.swift` · `11b0b01d1`, `ae8a67be3` |
| `QuestifyAppUnitTests/MapPublicLayerAppIntegrationTests/testHiddenPublicLayerRouteIsNotAttached` | Added (existing file) | `Tests/AppUnitTests/MapPublicLayerAppIntegrationTests.swift` · `01215d654` |
| `QuestifyAppUnitTests/MerchantOpsWp03GateTests/testProductionHostKeepsMoneyAndMerchantWritesClosed` | Added (new file) | `Tests/AppUnitTests/MerchantOpsWp03GateTests.swift` · `0b309ba6e` |
| `QuestifyAppUnitTests/NativeAudioLifecycleTests/testBackgroundDuringInterruptionStopsAndNeverResumes` | Added (existing file) | `Tests/AppUnitTests/NativePlatformAppTests.swift` · `1e48434aa` |
| `QuestifyAppUnitTests/NativeAudioLifecycleTests/testInterruptionEndedNeverResumesUserPausedAudio` | Added (existing file) | `Tests/AppUnitTests/NativePlatformAppTests.swift` · `1e48434aa` |
| `QuestifyAppUnitTests/NativeAudioLifecycleTests/testInterruptionResumesOnlyAudioThatWasPlaying` | Added (existing file) | `Tests/AppUnitTests/NativePlatformAppTests.swift` · `1e48434aa` |
| `QuestifyAppUnitTests/PayoutReceiverAppTests/testAppLeaseNamesEveryPayoutRouteOnce` | Added (new file) | `Tests/AppUnitTests/PayoutReceiverAppTests.swift` · `501efe8b6`, `af74412be`, `051e5cde7` |
| `QuestifyAppUnitTests/PayoutReceiverAppTests/testMiniProgramPayoutPagesParseToRoutes` | Added (new file) | `Tests/AppUnitTests/PayoutReceiverAppTests.swift` · `501efe8b6`, `af74412be`, `051e5cde7` |
| `QuestifyAppUnitTests/PayoutReceiverAppTests/testProductionHostKeepsEveryMoneyRouteClosed` | Added (new file) | `Tests/AppUnitTests/PayoutReceiverAppTests.swift` · `501efe8b6`, `af74412be`, `051e5cde7` |
| `QuestifyAppUnitTests/PayoutReceiverAppTests/testTestHostOpensPayoutAndMoneyButNotVirtualGoods` | Added (new file) | `Tests/AppUnitTests/PayoutReceiverAppTests.swift` · `501efe8b6`, `af74412be`, `051e5cde7` |
| `QuestifyAppUnitTests/PlayGapOwnerGrantTests/testCreatorTailRoutesAreGrantedInBothListsAndMoneyStaysOff` | Added (new file) | `Tests/AppUnitTests/PlayGapOwnerGrantTests.swift` · `c943799a6`, `2ea1db2c8`, `8f061385e`, `3edf0d032`, `5f15cb741` |
| `QuestifyAppUnitTests/PlayGapOwnerGrantTests/testGrantDoesNotRaiseTheContractBaseline` | Added (new file) | `Tests/AppUnitTests/PlayGapOwnerGrantTests.swift` · `c943799a6`, `2ea1db2c8`, `8f061385e`, `3edf0d032`, `5f15cb741` |
| `QuestifyAppUnitTests/PlayGapOwnerGrantTests/testProductNamesUseAnEmDashWhenMissing` | Added (new file) | `Tests/AppUnitTests/PlayGapOwnerGrantTests.swift` · `c943799a6`, `2ea1db2c8`, `8f061385e`, `3edf0d032`, `5f15cb741` |
| `QuestifyAppUnitTests/PlayGapOwnerGrantTests/testSwitchesStayClosedOnProduction` | Added (new file) | `Tests/AppUnitTests/PlayGapOwnerGrantTests.swift` · `c943799a6`, `2ea1db2c8`, `8f061385e`, `3edf0d032`, `5f15cb741` |
| `QuestifyAppUnitTests/PlayerJourneyProductionTests/testShippedChinaConstructsTheReadersAndPurchaseStaysUnreachable` | Added (new file) | `Tests/AppUnitTests/PlayerJourneyProductionTests.swift` · `5d0e87739`, `40b6de9a0` |
| `QuestifyAppUnitTests/PlayerJourneyPromoTests/testAuthAndFailureDoNotBecomeAnEmptyBalance` | Added (new file) | `Tests/AppUnitTests/PlayerJourneyPromoTests.swift` · `37d78247a`, `5d0e87739` |
| `QuestifyAppUnitTests/PlayerJourneyPromoTests/testShippedChinaLoadsTheSummaryAndLeavesWritesUnsent` | Added (new file) | `Tests/AppUnitTests/PlayerJourneyPromoTests.swift` · `37d78247a`, `5d0e87739` |
| `QuestifyAppUnitTests/PlayerJourneyPromoTests/testSummaryReadProjectsServerFactsAndDoesNotInventABalance` | Added (new file) | `Tests/AppUnitTests/PlayerJourneyPromoTests.swift` · `37d78247a`, `5d0e87739` |
| `QuestifyAppUnitTests/PostGameProjectionTests/testBoardsUseEntriesAndRefuseAnotherScope` | Added (new file) | `Tests/AppUnitTests/PostGameProjectionTests.swift` · `74fe013d7` |
| `QuestifyAppUnitTests/PostGameProjectionTests/testMemoryHidesPeerPhotosWithoutConsentAndRejectsAnotherRun` | Added (new file) | `Tests/AppUnitTests/PostGameProjectionTests.swift` · `74fe013d7` |
| `QuestifyAppUnitTests/PostGameProjectionTests/testReportShowsServerResultScoreAndRank` | Added (new file) | `Tests/AppUnitTests/PostGameProjectionTests.swift` · `74fe013d7` |
| `QuestifyAppUnitTests/PublicCatalogViewsTests/testUnknownPriceRowIsAnEmDash` | Added (new file) | `Tests/AppUnitTests/PublicCatalogViewsTests.swift` · `ca4f39acd` |
| `QuestifyAppUnitTests/PublicCatalogViewsTests/testViewAndWiringKeepMoneyOff` | Added (new file) | `Tests/AppUnitTests/PublicCatalogViewsTests.swift` · `ca4f39acd` |
| `QuestifyAppUnitTests/RevealChoreographerTests/testEmptyEventDoesNothing` | Added (new file) | `Tests/AppUnitTests/RevealChoreographerTests.swift` · `d7e9fbd84` |
| `QuestifyAppUnitTests/RevealChoreographerTests/testHapticsNeverFireCloserThan150Milliseconds` | Added (new file) | `Tests/AppUnitTests/RevealChoreographerTests.swift` · `d7e9fbd84` |
| `QuestifyAppUnitTests/RevealChoreographerTests/testLowPowerSkipsTheWipeLikeReduceMotion` | Added (new file) | `Tests/AppUnitTests/RevealChoreographerTests.swift` · `d7e9fbd84` |
| `QuestifyAppUnitTests/RevealChoreographerTests/testReduceMotionBakesEverythingAndCrossfadesOnce` | Added (new file) | `Tests/AppUnitTests/RevealChoreographerTests.swift` · `d7e9fbd84` |
| `QuestifyAppUnitTests/RevealChoreographerTests/testSettleReturnsFinishedWipesForBakingAndEmptiesTheLayer` | Added (new file) | `Tests/AppUnitTests/RevealChoreographerTests.swift` · `d7e9fbd84` |
| `QuestifyAppUnitTests/RevealChoreographerTests/testWipesAreStaggeredAndCappedAtSixWithTheRestBakedAtOnce` | Added (new file) | `Tests/AppUnitTests/RevealChoreographerTests.swift` · `d7e9fbd84` |
| `QuestifyAppUnitTests/ReviewedAreaSwitchTests/testDebugMoneyWriteSwitchFollowsTheHostAndRestoresClosed` | Added (new file) | `Tests/AppUnitTests/ReviewedAreaSwitchTests.swift` · `8f061385e`, `dd579e03d`, `88b42020f` |
| `QuestifyAppUnitTests/ReviewedAreaSwitchTests/testExternalGameSigningKeyIsPinnedPerEnvironment` | Added (new file) | `Tests/AppUnitTests/ReviewedAreaSwitchTests.swift` · `8f061385e`, `dd579e03d`, `88b42020f` |
| `QuestifyAppUnitTests/ReviewedAreaSwitchTests/testExternalGamesFollowTheHostOnly` | Added (new file) | `Tests/AppUnitTests/ReviewedAreaSwitchTests.swift` · `8f061385e`, `dd579e03d`, `88b42020f` |
| `QuestifyAppUnitTests/ReviewedAreaSwitchTests/testMoneySwitchesOpenOnlyForATestBuildOffTheProductionHost` | Added (new file) | `Tests/AppUnitTests/ReviewedAreaSwitchTests.swift` · `8f061385e`, `dd579e03d`, `88b42020f` |
| `QuestifyAppUnitTests/ReviewedChinaLaunchCompositionTests/testShippedChinaAdmitsAFreeQuoteAndSignupConsentAndRefusesAPaidQuote` | Added (existing file) | `Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift` · `af74412be`, `0752a7eff`, `bcdb4d00e`, `9bc393834`, `a9d609a61` (+32 more) |
| `QuestifyAppUnitTests/ReviewedChinaLaunchCompositionTests/testShippedChinaAdmitsCreatorStudioAndKeepsMoneyClosed` | Added (existing file) | `Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift` · `af74412be`, `0752a7eff`, `bcdb4d00e`, `9bc393834`, `a9d609a61` (+32 more) |
| `QuestifyAppUnitTests/ReviewedChinaLaunchCompositionTests/testShippedChinaAdmitsFreePlayerWritesAndKeepsMoneyClosed` | Added (existing file) | `Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift` · `af74412be`, `0752a7eff`, `bcdb4d00e`, `9bc393834`, `a9d609a61` (+32 more) |
| `QuestifyAppUnitTests/ReviewedChinaLaunchCompositionTests/testShippedChinaAdmitsHintLadderUseAndSkipAndKeepsMoneyClosed` | Added (existing file) | `Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift` · `af74412be`, `0752a7eff`, `bcdb4d00e`, `9bc393834`, `a9d609a61` (+32 more) |
| `QuestifyAppUnitTests/ReviewedChinaLaunchCompositionTests/testShippedChinaAdmitsInvoiceOrderCenterAndTopicEditorAndKeepsMoneyClosed` | Added (existing file) | `Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift` · `af74412be`, `0752a7eff`, `bcdb4d00e`, `9bc393834`, `a9d609a61` (+32 more) |
| `QuestifyAppUnitTests/ReviewedChinaLaunchCompositionTests/testShippedChinaAdmitsLivePlayerReadsAndKeepsMoneyClosed` | Added (existing file) | `Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift` · `af74412be`, `0752a7eff`, `bcdb4d00e`, `9bc393834`, `a9d609a61` (+32 more) |
| `QuestifyAppUnitTests/ReviewedChinaLaunchCompositionTests/testShippedChinaAdmitsParityBRoutesAndKeepsMoneyClosed` | Added (existing file) | `Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift` · `af74412be`, `0752a7eff`, `bcdb4d00e`, `9bc393834`, `a9d609a61` (+32 more) |
| `QuestifyAppUnitTests/ReviewedChinaLaunchCompositionTests/testShippedChinaAdmitsPlayRuntimeAndKeepsMoneyClosed` | Added (existing file) | `Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift` · `af74412be`, `0752a7eff`, `bcdb4d00e`, `9bc393834`, `a9d609a61` (+32 more) |
| `QuestifyAppUnitTests/ReviewedChinaLaunchCompositionTests/testShippedChinaAdmitsPlayerGapRoutesAndKeepsMoneyAndHostClosed` | Added (existing file) | `Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift` · `af74412be`, `0752a7eff`, `bcdb4d00e`, `9bc393834`, `a9d609a61` (+32 more) |
| `QuestifyAppUnitTests/ReviewedChinaLaunchCompositionTests/testShippedChinaAdmitsRunFeedbackAndKeepsMoneyClosed` | Added (existing file) | `Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift` · `af74412be`, `0752a7eff`, `bcdb4d00e`, `9bc393834`, `a9d609a61` (+32 more) |
| `QuestifyAppUnitTests/ReviewedChinaLaunchCompositionTests/testShippedChinaAdmitsSocialRoamTemplateMapRoutesAndKeepsMoneyClosed` | Added (existing file) | `Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift` · `af74412be`, `0752a7eff`, `bcdb4d00e`, `9bc393834`, `a9d609a61` (+32 more) |
| `QuestifyAppUnitTests/ReviewedChinaLaunchCompositionTests/testShippedChinaAdmitsTeamCreateAndTeamItemCommands` | Added (existing file) | `Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift` · `af74412be`, `0752a7eff`, `bcdb4d00e`, `9bc393834`, `a9d609a61` (+32 more) |
| `QuestifyAppUnitTests/ReviewedChinaLaunchCompositionTests/testShippedChinaAdmitsTemplateAdoptionAndKeepsMoneyClosed` | Added (existing file) | `Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift` · `af74412be`, `0752a7eff`, `bcdb4d00e`, `9bc393834`, `a9d609a61` (+32 more) |
| `QuestifyAppUnitTests/ReviewedChinaLaunchCompositionTests/testShippedChinaAdmitsTheOwnersTicketEntryCodeIssueOnly` | Added (existing file) | `Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift` · `af74412be`, `0752a7eff`, `bcdb4d00e`, `9bc393834`, `a9d609a61` (+32 more) |
| `QuestifyAppUnitTests/ReviewedChinaLaunchCompositionTests/testShippedChinaApprovesClubPublicActivitiesAndAccessMe` | Added (existing file) | `Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift` · `af74412be`, `0752a7eff`, `bcdb4d00e`, `9bc393834`, `a9d609a61` (+32 more) |
| `QuestifyAppUnitTests/ReviewedChinaLaunchCompositionTests/testShippedChinaE2EPlayerBlockersAreOpenAndMoneyStaysClosed` | Added (existing file) | `Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift` · `af74412be`, `0752a7eff`, `bcdb4d00e`, `9bc393834`, `a9d609a61` (+32 more) |
| `QuestifyAppUnitTests/ReviewedChinaLaunchCompositionTests/testShippedChinaGrantsPlayerProjectEditorAndKeepsMoneyAndMerchantPublishingClosed` | Added (existing file) | `Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift` · `af74412be`, `0752a7eff`, `bcdb4d00e`, `9bc393834`, `a9d609a61` (+32 more) |
| `QuestifyAppUnitTests/ReviewedChinaLaunchCompositionTests/testShippedChinaGrantsSignedInContentDetailReads` | Added (existing file) | `Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift` · `af74412be`, `0752a7eff`, `bcdb4d00e`, `9bc393834`, `a9d609a61` (+32 more) |
| `QuestifyAppUnitTests/ReviewedSocialWriteLeaseTests/testChannelManagementLeaseCoversClubsAndTeamsOnly` | Added (new file) | `Tests/AppUnitTests/ReviewedSocialWriteLeaseTests.swift` · `689134de7` |
| `QuestifyAppUnitTests/ReviewedSocialWriteLeaseTests/testPlayerWriteRouteAdmitsAdmissionAndTeamPoolButNotMoney` | Added (new file) | `Tests/AppUnitTests/ReviewedSocialWriteLeaseTests.swift` · `689134de7` |
| `QuestifyAppUnitTests/ReviewedSocialWriteLeaseTests/testSocialLeasesNeedPlayerWritesAndAPlayerOrClubRole` | Added (new file) | `Tests/AppUnitTests/ReviewedSocialWriteLeaseTests.swift` · `689134de7` |
| `QuestifyAppUnitTests/RootPresentationCoordinatorTests/testConsentGoesFirst` | Added (new file) | `Tests/AppUnitTests/RootPresentationCoordinatorTests.swift` · `ba7cb6e0c`, `21a2705bb` |
| `QuestifyAppUnitTests/RootPresentationCoordinatorTests/testLastLinkWins` | Added (new file) | `Tests/AppUnitTests/RootPresentationCoordinatorTests.swift` · `ba7cb6e0c`, `21a2705bb` |
| `QuestifyAppUnitTests/RootPresentationCoordinatorTests/testLinkExpiresAfterFiveMinutes` | Added (new file) | `Tests/AppUnitTests/RootPresentationCoordinatorTests.swift` · `ba7cb6e0c`, `21a2705bb` |
| `QuestifyAppUnitTests/RootPresentationCoordinatorTests/testLinkWaitsForTabsThenReplaysOnce` | Added (new file) | `Tests/AppUnitTests/RootPresentationCoordinatorTests.swift` · `ba7cb6e0c`, `21a2705bb` |
| `QuestifyAppUnitTests/RootPresentationCoordinatorTests/testOpenPassportSheetHoldsTheLinkUntilItCloses` | Added (new file) | `Tests/AppUnitTests/RootPresentationCoordinatorTests.swift` · `ba7cb6e0c`, `21a2705bb` |
| `QuestifyAppUnitTests/RootPresentationCoordinatorTests/testSeatLandingDoesNotWaitForSignInAndRecordsIntake` | Added (new file) | `Tests/AppUnitTests/RootPresentationCoordinatorTests.swift` · `ba7cb6e0c`, `21a2705bb` |
| `QuestifyAppUnitTests/RootPresentationCoordinatorTests/testTicketWaitsForSignIn` | Added (new file) | `Tests/AppUnitTests/RootPresentationCoordinatorTests.swift` · `ba7cb6e0c`, `21a2705bb` |
| `QuestifyAppUnitTests/SquareRouteMapProviderTests/testMismatchedDetailIsUnavailable` | Added (new file) | `Tests/AppUnitTests/SquareRouteMapProviderTests.swift` · `d091fdab3` |
| `QuestifyAppUnitTests/SquareRouteMapProviderTests/testNonPositiveTopicDoesNotRead` | Added (new file) | `Tests/AppUnitTests/SquareRouteMapProviderTests.swift` · `d091fdab3` |
| `QuestifyAppUnitTests/SquareRouteMapProviderTests/testUnverifiedGeometryHidesTheMap` | Added (new file) | `Tests/AppUnitTests/SquareRouteMapProviderTests.swift` · `d091fdab3` |
| `QuestifyAppUnitTests/SquareRouteMapProviderTests/testVerifiedRoadKeepsChapterSegmentsAndAnEmDashForABlankStop` | Added (new file) | `Tests/AppUnitTests/SquareRouteMapProviderTests.swift` · `d091fdab3` |
| `QuestifyAppUnitTests/WP06PartialPageHostTests/testOpensEveryPartialPageScreen` | Added (new file) | `Tests/AppUnitTests/WP06PartialPageHostTests.swift` · `731dd1001` |
| `QuestifyAppUnitTests/WP07CommerceLeaseTests/testBothGrantsListTheFourRoutesAndWritesStayClosed` | Added (new file) | `Tests/AppUnitTests/WP07CommerceLeaseTests.swift` · `3e2dca3ec`, `4a3fbac20` |
| `QuestifyAppUnitTests/WP07CommerceLeaseTests/testLeaseAdmitsQuoteAndUsabilityAndRefusesPricedOrWriteBodies` | Added (new file) | `Tests/AppUnitTests/WP07CommerceLeaseTests.swift` · `3e2dca3ec`, `4a3fbac20` |
| `QuestifyAppUnitTests/WP08HostTipLeaseTests/testPlayerLeaseAdmitsTheSurfaceAndRefusesAPayChannel` | Added (new file) | `Tests/AppUnitTests/WP08HostTipLeaseTests.swift` · `0242ef8d3` |
| `QuestifyAppUnitTests/WP08ReceiveNativeURLAuditTests/testCheinLinkStillRecordsPendingWithoutOpeningPayment` | Added (new file) | `Tests/AppUnitTests/WP08ReceiveNativeURLAuditTests.swift` · `7febb7051` |
| `QuestifyAppUnitTests/WP08ReceiveNativeURLAuditTests/testPaymentAndPasswordRoutesDoNotNavigate` | Added (new file) | `Tests/AppUnitTests/WP08ReceiveNativeURLAuditTests.swift` · `7febb7051` |
| `QuestifyAppUnitTests/WP08ReceiveNativeURLAuditTests/testSafePublicTopicLinkRoutes` | Added (new file) | `Tests/AppUnitTests/WP08ReceiveNativeURLAuditTests.swift` · `7febb7051` |
| `QuestifyAppUnitTests/WP08ReceiveNativeURLAuditTests/testUnauthenticatedProtectedLinkDoesNotNavigate` | Added (new file) | `Tests/AppUnitTests/WP08ReceiveNativeURLAuditTests.swift` · `7febb7051` |
| `QuestifyAppUnitTests/WP08ReceiveNativeURLAuditTests/testUnsafeSchemeIsInertNoNavigation` | Added (new file) | `Tests/AppUnitTests/WP08ReceiveNativeURLAuditTests.swift` · `7febb7051` |
| `QuestifyAppUnitTests/WP08ReceiveNativeURLAuditTests/testWrongRealmRejected` | Added (new file) | `Tests/AppUnitTests/WP08ReceiveNativeURLAuditTests.swift` · `7febb7051` |
| `QuestifyAppUnitTests/WP09PresetsTeamAfterSaleTests/testOWN_21_1_presetDraftOpensEditableDraftOnTEST` | Added (new file) | `Tests/AppUnitTests/WP09PresetsTeamAfterSaleTests.swift` · `6feee423a`, `266f91284` |
| `QuestifyAppUnitTests/WP09PresetsTeamAfterSaleTests/testOWN_21_2_presetListAndInfo` | Added (new file) | `Tests/AppUnitTests/WP09PresetsTeamAfterSaleTests.swift` · `6feee423a`, `266f91284` |
| `QuestifyAppUnitTests/WP09PresetsTeamAfterSaleTests/testOWN_U02_04_sourceVersion` | Added (new file) | `Tests/AppUnitTests/WP09PresetsTeamAfterSaleTests.swift` · `6feee423a`, `266f91284` |
| `QuestifyAppUnitTests/WP09PresetsTeamAfterSaleTests/testOWN_U06_02_myRoleAndPrivateClues` | Added (new file) | `Tests/AppUnitTests/WP09PresetsTeamAfterSaleTests.swift` · `6feee423a`, `266f91284` |
| `QuestifyAppUnitTests/WP09PresetsTeamAfterSaleTests/testOWN_U06_04_organizerSharedResults` | Added (new file) | `Tests/AppUnitTests/WP09PresetsTeamAfterSaleTests.swift` · `6feee423a`, `266f91284` |
| `QuestifyAppUnitTests/WP09PresetsTeamAfterSaleTests/testOWN_U07_01_delivery` | Added (new file) | `Tests/AppUnitTests/WP09PresetsTeamAfterSaleTests.swift` · `6feee423a`, `266f91284` |
| `QuestifyAppUnitTests/WP09PresetsTeamAfterSaleTests/testOWN_U07_02_paymentReturn` | Added (new file) | `Tests/AppUnitTests/WP09PresetsTeamAfterSaleTests.swift` · `6feee423a`, `266f91284` |
| `QuestifyAppUnitTests/WP09PresetsTeamAfterSaleTests/testOWN_U07_03_workshopInstallStaysClosedOnProduction` | Added (new file) | `Tests/AppUnitTests/WP09PresetsTeamAfterSaleTests.swift` · `6feee423a`, `266f91284` |
| `QuestifyAppUnitTests/WP09PresetsTeamAfterSaleTests/testOWN_U07_04_partialRefundServerAmounts` | Added (new file) | `Tests/AppUnitTests/WP09PresetsTeamAfterSaleTests.swift` · `6feee423a`, `266f91284` |
| `QuestifyAppUnitTests/WP09PresetsTeamAfterSaleTests/testOWN_U07_05_creatorAccrual` | Added (new file) | `Tests/AppUnitTests/WP09PresetsTeamAfterSaleTests.swift` · `6feee423a`, `266f91284` |
| `Tests/ContractChecks/test_activity_detail_page_ready.py::ActivityDetailPageReadyContractTests.test_fixture_data_is_debug_only_and_parses` | Added (new file) | `Tests/ContractChecks/test_activity_detail_page_ready.py` · `3a6bf530f`, `773af19aa` |
| `Tests/ContractChecks/test_activity_detail_page_ready.py::ActivityDetailPageReadyContractTests.test_model_has_loading_empty_error_and_em_dash_unknown` | Added (new file) | `Tests/ContractChecks/test_activity_detail_page_ready.py` · `3a6bf530f`, `773af19aa` |
| `Tests/ContractChecks/test_activity_detail_page_ready.py::ActivityDetailPageReadyContractTests.test_strings_match_catalog_and_identifiers_exist` | Added (new file) | `Tests/ContractChecks/test_activity_detail_page_ready.py` · `3a6bf530f`, `773af19aa` |
| `Tests/ContractChecks/test_activity_detail_page_ready.py::ActivityDetailPageReadyContractTests.test_swift_tests_cover_states_without_removing_host_cancel_tests` | Added (new file) | `Tests/ContractChecks/test_activity_detail_page_ready.py` · `3a6bf530f`, `773af19aa` |
| `Tests/ContractChecks/test_activity_publishing_page_readiness.py::ActivityPublishingPageReadinessContract.test_model_keeps_four_states_and_hides_missing_routes` | Added (new file) | `Tests/ContractChecks/test_activity_publishing_page_readiness.py` · `66344a1cd` |
| `Tests/ContractChecks/test_activity_publishing_page_readiness.py::ActivityPublishingPageReadinessContract.test_string_file_has_english_chinese_and_accessibility_ids` | Added (new file) | `Tests/ContractChecks/test_activity_publishing_page_readiness.py` · `66344a1cd` |
| `Tests/ContractChecks/test_app_store_privacy_launch_contracts.py::AppStorePrivacyLaunchContracts.test_no_always_location_and_only_session_background_location` | Added (existing file) | `Tests/ContractChecks/test_app_store_privacy_launch_contracts.py` · `1e48434aa`, `b75bdd223` |
| `Tests/ContractChecks/test_assetcenter_analysis_page_ready.py::AssetCenterAnalysisPageReadyTests.test_existing_analysis_closure_tests_stay_intact` | Added (new file) | `Tests/ContractChecks/test_assetcenter_analysis_page_ready.py` · `83d1e5122` |
| `Tests/ContractChecks/test_assetcenter_analysis_page_ready.py::AssetCenterAnalysisPageReadyTests.test_fixture_data_is_debug_only_and_does_not_enable_payout` | Added (new file) | `Tests/ContractChecks/test_assetcenter_analysis_page_ready.py` · `83d1e5122` |
| `Tests/ContractChecks/test_assetcenter_analysis_page_ready.py::AssetCenterAnalysisPageReadyTests.test_model_states_use_em_dash_and_the_existing_income_route` | Added (new file) | `Tests/ContractChecks/test_assetcenter_analysis_page_ready.py` · `83d1e5122` |
| `Tests/ContractChecks/test_assetcenter_analysis_page_ready.py::AssetCenterAnalysisPageReadyTests.test_string_catalog_has_both_languages_and_existing_identifiers` | Added (new file) | `Tests/ContractChecks/test_assetcenter_analysis_page_ready.py` · `83d1e5122` |
| `Tests/ContractChecks/test_cb212_official_detail_page_ready.py::OfficialDetailPageReadyChecks.test_detail_fixture_data_is_debug_only` | Added (new file) | `Tests/ContractChecks/test_cb212_official_detail_page_ready.py` · `3a6bf530f`, `773af19aa` |
| `Tests/ContractChecks/test_cb212_official_detail_page_ready.py::OfficialDetailPageReadyChecks.test_model_has_loading_empty_error_and_unknown_without_a_new_route` | Added (new file) | `Tests/ContractChecks/test_cb212_official_detail_page_ready.py` · `3a6bf530f`, `773af19aa` |
| `Tests/ContractChecks/test_cb212_official_detail_page_ready.py::OfficialDetailPageReadyChecks.test_string_catalog_is_bilingual_and_matches_existing_keys` | Added (new file) | `Tests/ContractChecks/test_cb212_official_detail_page_ready.py` · `3a6bf530f`, `773af19aa` |
| `Tests/ContractChecks/test_cb212_official_detail_page_ready.py::OfficialDetailPageReadyChecks.test_unknown_dash_and_literal_zero_tests_stay` | Added (new file) | `Tests/ContractChecks/test_cb212_official_detail_page_ready.py` · `3a6bf530f`, `773af19aa` |
| `Tests/ContractChecks/test_cb219_income_detail_page_ready.py::IncomeDetailPageReadyContracts.test_catalog_has_both_languages_and_accessibility_ids` | Added (new file) | `Tests/ContractChecks/test_cb219_income_detail_page_ready.py` · `d93a0769a` |
| `Tests/ContractChecks/test_cb219_income_detail_page_ready.py::IncomeDetailPageReadyContracts.test_debug_fixture_data_preserves_the_existing_income_payload` | Added (new file) | `Tests/ContractChecks/test_cb219_income_detail_page_ready.py` · `d93a0769a` |
| `Tests/ContractChecks/test_cb219_income_detail_page_ready.py::IncomeDetailPageReadyContracts.test_existing_income_detail_tests_remain` | Added (new file) | `Tests/ContractChecks/test_cb219_income_detail_page_ready.py` · `d93a0769a` |
| `Tests/ContractChecks/test_cb219_income_detail_page_ready.py::IncomeDetailPageReadyContracts.test_model_states_and_existing_read_stay_hidden_when_off` | Added (new file) | `Tests/ContractChecks/test_cb219_income_detail_page_ready.py` · `d93a0769a` |
| `Tests/ContractChecks/test_cb220_earnings_overview_page_ready.py::EarningsOverviewPageReady.test_fixture_is_debug_only_and_money_switches_stay_off` | Added (new file) | `Tests/ContractChecks/test_cb220_earnings_overview_page_ready.py` · `e416a3354` |
| `Tests/ContractChecks/test_cb220_earnings_overview_page_ready.py::EarningsOverviewPageReady.test_strings_match_catalogs_and_name_accessibility_ids` | Added (new file) | `Tests/ContractChecks/test_cb220_earnings_overview_page_ready.py` · `e416a3354` |
| `Tests/ContractChecks/test_cb224_stamp_camera_page_ready.py::StampCameraPageReadyContract.test_catalog_matches_the_view_and_the_live_bilingual_strings` | Added (new file) | `Tests/ContractChecks/test_cb224_stamp_camera_page_ready.py` · `731dd1001`, `4a157c02c`, `d8b396d1a` |
| `Tests/ContractChecks/test_cb224_stamp_camera_page_ready.py::StampCameraPageReadyContract.test_existing_stamp_tests_remain` | Added (new file) | `Tests/ContractChecks/test_cb224_stamp_camera_page_ready.py` · `731dd1001`, `4a157c02c`, `d8b396d1a` |
| `Tests/ContractChecks/test_cb224_stamp_camera_page_ready.py::StampCameraPageReadyContract.test_model_keeps_unknown_as_a_dash_and_hides_missing_writes` | Added (new file) | `Tests/ContractChecks/test_cb224_stamp_camera_page_ready.py` · `731dd1001`, `4a157c02c`, `d8b396d1a` |
| `Tests/ContractChecks/test_cb225_stamp_album_index_page.py::StampAlbumIndexPageTests.test_catalog_has_both_languages_and_the_same_accessibility_identifiers` | Added (new file) | `Tests/ContractChecks/test_cb225_stamp_album_index_page.py` · `484677f45` |
| `Tests/ContractChecks/test_cb225_stamp_album_index_page.py::StampAlbumIndexPageTests.test_denied_sign_in_and_bad_payloads_do_not_invent_a_count` | Added (new file) | `Tests/ContractChecks/test_cb225_stamp_album_index_page.py` · `484677f45` |
| `Tests/ContractChecks/test_cb225_stamp_album_index_page.py::StampAlbumIndexPageTests.test_empty_and_unknown_are_an_em_dash_and_a_numeric_string_is_not_zero` | Added (new file) | `Tests/ContractChecks/test_cb225_stamp_album_index_page.py` · `484677f45` |
| `Tests/ContractChecks/test_cb225_stamp_album_index_page.py::StampAlbumIndexPageTests.test_loading_wins_and_error_tokens_stay_distinct_from_zero` | Added (new file) | `Tests/ContractChecks/test_cb225_stamp_album_index_page.py` · `484677f45` |
| `Tests/ContractChecks/test_cb225_stamp_album_index_page.py::StampAlbumIndexPageTests.test_server_total_is_not_replaced_by_the_visible_count` | Added (new file) | `Tests/ContractChecks/test_cb225_stamp_album_index_page.py` · `484677f45` |
| `Tests/ContractChecks/test_cb225_stamp_album_index_page.py::StampAlbumIndexPageTests.test_source_keeps_the_existing_route_hidden_flags_and_debug_fixture` | Added (new file) | `Tests/ContractChecks/test_cb225_stamp_album_index_page.py` · `484677f45` |
| `Tests/ContractChecks/test_cb231_publish_fabu_page_model.py::PublishFabuPageModelContract.test_empty_and_unknown_are_an_em_dash_and_zero_stays_zero` | Added (new file) | `Tests/ContractChecks/test_cb231_publish_fabu_page_model.py` · `b23db8968` |
| `Tests/ContractChecks/test_cb231_publish_fabu_page_model.py::PublishFabuPageModelContract.test_error_token_and_gated_failure` | Added (new file) | `Tests/ContractChecks/test_cb231_publish_fabu_page_model.py` · `b23db8968` |
| `Tests/ContractChecks/test_cb231_publish_fabu_page_model.py::PublishFabuPageModelContract.test_existing_debug_fixtures_and_payment_switches` | Added (new file) | `Tests/ContractChecks/test_cb231_publish_fabu_page_model.py` · `b23db8968` |
| `Tests/ContractChecks/test_cb231_publish_fabu_page_model.py::PublishFabuPageModelContract.test_loading_and_unknown_outcome_do_not_show_zero` | Added (new file) | `Tests/ContractChecks/test_cb231_publish_fabu_page_model.py` · `b23db8968` |
| `Tests/ContractChecks/test_cb231_publish_fabu_page_model.py::PublishFabuPageModelContract.test_missing_capability_stays_hidden` | Added (new file) | `Tests/ContractChecks/test_cb231_publish_fabu_page_model.py` · `b23db8968` |
| `Tests/ContractChecks/test_cb231_publish_fabu_page_model.py::PublishFabuPageModelContract.test_page_is_not_mounted_and_player_entry_stays_closed` | Added (new file) | `Tests/ContractChecks/test_cb231_publish_fabu_page_model.py` · `b23db8968` |
| `Tests/ContractChecks/test_cb231_publish_fabu_page_model.py::PublishFabuPageModelContract.test_strings_are_bilingual_and_match_identifiers` | Added (new file) | `Tests/ContractChecks/test_cb231_publish_fabu_page_model.py` · `b23db8968` |
| `Tests/ContractChecks/test_cb231_publish_fabu_page_model.py::PublishFabuPageModelContract.test_swift_source_locks_states_dash_and_gate` | Added (new file) | `Tests/ContractChecks/test_cb231_publish_fabu_page_model.py` · `b23db8968` |
| `Tests/ContractChecks/test_cb36_offline.py::CB36OfflineContract.test_existing_unconfigured_routes_still_refuse_before_send` | Added (new file) | `Tests/ContractChecks/test_cb36_offline.py` · `51c876d43` |
| `Tests/ContractChecks/test_cb36_offline.py::CB36OfflineContract.test_game_node_receipt_fails_before_send_unless_offline_harness` | Added (new file) | `Tests/ContractChecks/test_cb36_offline.py` · `51c876d43` |
| `Tests/ContractChecks/test_cb36_offline.py::CB36OfflineContract.test_payment_withdrawal_and_launch_defaults_stay_closed` | Added (new file) | `Tests/ContractChecks/test_cb36_offline.py` · `51c876d43` |
| `Tests/ContractChecks/test_cb36_offline.py::CB36OfflineContract.test_unknown_lock_survives_not_configured_and_existing_tests_remain` | Added (new file) | `Tests/ContractChecks/test_cb36_offline.py` · `51c876d43` |
| `Tests/ContractChecks/test_cb50_error_catalog.py::CB50ErrorCatalogTests.test_catalog_is_bilingual_and_app_has_no_localized_string_literal` | Added (new file) | `Tests/ContractChecks/test_cb50_error_catalog.py` · `4a157c02c`, `e466e6e63` |
| `Tests/ContractChecks/test_cb50_error_catalog.py::CB50ErrorCatalogTests.test_known_code_message_and_status` | Added (new file) | `Tests/ContractChecks/test_cb50_error_catalog.py` · `4a157c02c`, `e466e6e63` |
| `Tests/ContractChecks/test_cb50_error_catalog.py::CB50ErrorCatalogTests.test_missing_configuration_is_not_configured_before_a_request` | Added (new file) | `Tests/ContractChecks/test_cb50_error_catalog.py` · `4a157c02c`, `e466e6e63` |
| `Tests/ContractChecks/test_cb50_error_catalog.py::CB50ErrorCatalogTests.test_outputs_match_the_map` | Added (new file) | `Tests/ContractChecks/test_cb50_error_catalog.py` · `4a157c02c`, `e466e6e63` |
| `Tests/ContractChecks/test_cb50_error_catalog.py::CB50ErrorCatalogTests.test_release_defaults_stay_closed` | Added (new file) | `Tests/ContractChecks/test_cb50_error_catalog.py` · `4a157c02c`, `e466e6e63` |
| `Tests/ContractChecks/test_cb50_error_catalog.py::CB50ErrorCatalogTests.test_unknown_code_stays_generic_and_hides_the_server_text` | Added (new file) | `Tests/ContractChecks/test_cb50_error_catalog.py` · `4a157c02c`, `e466e6e63` |
| `Tests/ContractChecks/test_cb51_diagnostics.py::CB51DiagnosticsContracts.test_flag_off_records_no_secrets` | Added (new file) | `Tests/ContractChecks/test_cb51_diagnostics.py` · `1e48434aa`, `d06b6df4c` |
| `Tests/ContractChecks/test_cb51_diagnostics.py::CB51DiagnosticsContracts.test_flag_on_keeps_name_and_count_only` | Added (new file) | `Tests/ContractChecks/test_cb51_diagnostics.py` · `1e48434aa`, `d06b6df4c` |
| `Tests/ContractChecks/test_cb51_diagnostics.py::CB51DiagnosticsContracts.test_swift_recorder_matches_the_flag_and_drops_the_secret` | Added (new file) | `Tests/ContractChecks/test_cb51_diagnostics.py` · `1e48434aa`, `d06b6df4c` |
| `Tests/ContractChecks/test_cb51_diagnostics.py::CB51DiagnosticsContracts.test_swift_test_asserts_the_samples_are_absent` | Added (new file) | `Tests/ContractChecks/test_cb51_diagnostics.py` · `1e48434aa`, `d06b6df4c` |
| `Tests/ContractChecks/test_cb51_diagnostics.py::CB51DiagnosticsContracts.test_version_background_location_and_packages_stay_put` | Added (new file) | `Tests/ContractChecks/test_cb51_diagnostics.py` · `1e48434aa`, `d06b6df4c` |
| `Tests/ContractChecks/test_cb97_payment_gating.py::ReleasePaymentGatingTests.test_a_sending_function_cannot_name_a_write_without_its_switch` | Added (new file) | `Tests/ContractChecks/test_cb97_payment_gating.py` · `4a157c02c`, `3f9afa676` |
| `Tests/ContractChecks/test_cb97_payment_gating.py::ReleasePaymentGatingTests.test_admit_asks_the_switch_before_the_wired_catalog` | Added (new file) | `Tests/ContractChecks/test_cb97_payment_gating.py` · `4a157c02c`, `3f9afa676` |
| `Tests/ContractChecks/test_cb97_payment_gating.py::ReleasePaymentGatingTests.test_each_release_switch_is_its_own_constant_and_off` | Added (new file) | `Tests/ContractChecks/test_cb97_payment_gating.py` · `4a157c02c`, `3f9afa676` |
| `Tests/ContractChecks/test_cb97_payment_gating.py::ReleasePaymentGatingTests.test_one_switch_does_not_open_another_kind` | Added (new file) | `Tests/ContractChecks/test_cb97_payment_gating.py` · `4a157c02c`, `3f9afa676` |
| `Tests/ContractChecks/test_cb97_payment_gating.py::ReleasePaymentGatingTests.test_payout_write_has_no_sender_outside_the_switch` | Added (new file) | `Tests/ContractChecks/test_cb97_payment_gating.py` · `4a157c02c`, `3f9afa676` |
| `Tests/ContractChecks/test_cb97_payment_gating.py::ReleasePaymentGatingTests.test_release_call_sites_check_the_matching_switch` | Added (new file) | `Tests/ContractChecks/test_cb97_payment_gating.py` · `4a157c02c`, `3f9afa676` |
| `Tests/ContractChecks/test_cb97_payment_gating.py::ReleasePaymentGatingTests.test_required_writes_stay_classified_on_their_own_switch` | Added (new file) | `Tests/ContractChecks/test_cb97_payment_gating.py` · `4a157c02c`, `3f9afa676` |
| `Tests/ContractChecks/test_city_game_base.py::CityGameBaseContracts.test_capability_comes_only_from_the_city_lease` | Added (existing file) | `Tests/ContractChecks/test_city_game_base.py` · `0808f6cfe`, `8e8fa748a`, `4a157c02c`, `5a7e5d8f0` |
| `Tests/ContractChecks/test_city_game_base.py::CityGameBaseContracts.test_city_routes_move_no_money` | Added (existing file) | `Tests/ContractChecks/test_city_game_base.py` · `0808f6cfe`, `8e8fa748a`, `4a157c02c`, `5a7e5d8f0` |
| `Tests/ContractChecks/test_city_game_base.py::CityGameBaseContracts.test_only_the_production_service_and_debug_fixtures_conform` | Added (existing file) | `Tests/ContractChecks/test_city_game_base.py` · `0808f6cfe`, `8e8fa748a`, `4a157c02c`, `5a7e5d8f0` |
| `Tests/ContractChecks/test_city_game_base.py::CityGameBaseContracts.test_production_entry_points_pass_the_leased_game_and_no_restore_model` | Added (existing file) | `Tests/ContractChecks/test_city_game_base.py` · `0808f6cfe`, `8e8fa748a`, `4a157c02c`, `5a7e5d8f0` |
| `Tests/ContractChecks/test_club_create_page_ready.py::ClubCreatePageReadyContract.test_debug_fixture_data_and_unit_tests_exist` | Added (new file) | `Tests/ContractChecks/test_club_create_page_ready.py` · `4f180d862` |
| `Tests/ContractChecks/test_club_create_page_ready.py::ClubCreatePageReadyContract.test_model_keeps_unknown_as_em_dash_and_creation_gated` | Added (new file) | `Tests/ContractChecks/test_club_create_page_ready.py` · `4f180d862` |
| `Tests/ContractChecks/test_club_create_page_ready.py::ClubCreatePageReadyContract.test_strings_have_both_languages_and_accessibility_identifiers` | Added (new file) | `Tests/ContractChecks/test_club_create_page_ready.py` · `4f180d862` |
| `Tests/ContractChecks/test_club_create_view_wire.py::ClubCreateViewWireContract.test_view_reads_interpret` | Added (new file) | `Tests/ContractChecks/test_club_create_view_wire.py` · `5f44a544a` |
| `Tests/ContractChecks/test_club_customer_detail_page_view.py::ClubCustomerDetailPageViewContract.test_view_reads_core_count` | Added (new file) | `Tests/ContractChecks/test_club_customer_detail_page_view.py` · `d73e820d4`, `d4811a683` |
| `Tests/ContractChecks/test_club_detail_page_ready.py::ClubDetailPageReadyContract.test_accessibility_identifiers_are_real_literals` | Added (new file) | `Tests/ContractChecks/test_club_detail_page_ready.py` · `8792ad621`, `4f180d862` |
| `Tests/ContractChecks/test_club_detail_page_ready.py::ClubDetailPageReadyContract.test_model_keeps_states_unknown_dash_and_debug_fixture` | Added (new file) | `Tests/ContractChecks/test_club_detail_page_ready.py` · `8792ad621`, `4f180d862` |
| `Tests/ContractChecks/test_club_detail_page_ready.py::ClubDetailPageReadyContract.test_strings_match_catalog_in_both_languages` | Added (new file) | `Tests/ContractChecks/test_club_detail_page_ready.py` · `8792ad621`, `4f180d862` |
| `Tests/ContractChecks/test_club_detail_page_ready.py::ClubDetailPageReadyContract.test_swift_tests_were_added_without_removing_existing_ones` | Added (new file) | `Tests/ContractChecks/test_club_detail_page_ready.py` · `8792ad621`, `4f180d862` |
| `Tests/ContractChecks/test_club_edit_page_ready.py::ClubEditPageReadyContract.test_debug_fixture_data_keeps_unknown_distinct_from_zero` | Added (new file) | `Tests/ContractChecks/test_club_edit_page_ready.py` · `8792ad621`, `4f180d862` |
| `Tests/ContractChecks/test_club_edit_page_ready.py::ClubEditPageReadyContract.test_existing_dissolve_tests_and_live_routes_stay` | Added (new file) | `Tests/ContractChecks/test_club_edit_page_ready.py` · `8792ad621`, `4f180d862` |
| `Tests/ContractChecks/test_club_edit_page_ready.py::ClubEditPageReadyContract.test_model_states_unknown_mark_and_player_first_gate` | Added (new file) | `Tests/ContractChecks/test_club_edit_page_ready.py` · `8792ad621`, `4f180d862` |
| `Tests/ContractChecks/test_club_edit_page_ready.py::ClubEditPageReadyContract.test_strings_are_bilingual_and_identified` | Added (new file) | `Tests/ContractChecks/test_club_edit_page_ready.py` · `8792ad621`, `4f180d862` |
| `Tests/ContractChecks/test_club_edit_page_ready.py::ClubEditPageReadyContract.test_views_project_and_manifest_were_not_the_edit_surface` | Added (new file) | `Tests/ContractChecks/test_club_edit_page_ready.py` · `8792ad621`, `4f180d862` |
| `Tests/ContractChecks/test_club_governance_page_ready.py::ClubGovernancePageReadyChecks.test_governance_page_states_stay_off_player_entry` | Added (new file) | `Tests/ContractChecks/test_club_governance_page_ready.py` · `f760f1977` |
| `Tests/ContractChecks/test_club_group_code_page_ready.py::ClubGroupCodePageReadyChecks.test_group_code_page_states_stay_off_player_entry` | Added (new file) | `Tests/ContractChecks/test_club_group_code_page_ready.py` · `3a6bf530f`, `7dec57c38` |
| `Tests/ContractChecks/test_club_host_apply_page_model.py::ClubHostApplyPageModelContract.test_model_keeps_existing_routes_and_hides_a_missing_capability` | Added (new file) | `Tests/ContractChecks/test_club_host_apply_page_model.py` · `4f180d862` |
| `Tests/ContractChecks/test_club_host_apply_page_model.py::ClubHostApplyPageModelContract.test_string_catalog_has_both_locales_and_identifiers` | Added (new file) | `Tests/ContractChecks/test_club_host_apply_page_model.py` · `4f180d862` |
| `Tests/ContractChecks/test_club_notify_page_ready.py::ClubNotifyPageReady.test_page_uses_existing_routes_and_stays_off_player_entry` | Added (new file) | `Tests/ContractChecks/test_club_notify_page_ready.py` · `8af8ffb77` |
| `Tests/ContractChecks/test_club_notify_page_ready.py::ClubNotifyPageReady.test_unknown_counts_are_an_em_dash_and_broadcast_stays_gated` | Added (new file) | `Tests/ContractChecks/test_club_notify_page_ready.py` · `8af8ffb77` |
| `Tests/ContractChecks/test_club_ops_customer.py::ClubCustomerDetailPageReadyChecks.test_customer_detail_page_states_stay_off_player_entry` | Added (existing file) | `Tests/ContractChecks/test_club_ops_customer.py` · `8eb7281ec`, `528bd0a9e`, `4f180d862` |
| `Tests/ContractChecks/test_completeness_rollups_cl02r.py::CompletenessRollupRuleTests.test_matrix_rollups_parse_and_wp_r_rows_are_rollups` | Added (new file) | `Tests/ContractChecks/test_completeness_rollups_cl02r.py` · `e5b3abb4c` |
| `Tests/ContractChecks/test_completeness_rollups_cl02r.py::CompletenessRollupRuleTests.test_production_off_child_counts_and_nested_rollups_close` | Added (new file) | `Tests/ContractChecks/test_completeness_rollups_cl02r.py` · `e5b3abb4c` |
| `Tests/ContractChecks/test_completeness_rollups_cl02r.py::CompletenessRollupRuleTests.test_status_rules_carry_cl02r` | Added (new file) | `Tests/ContractChecks/test_completeness_rollups_cl02r.py` · `e5b3abb4c` |
| `Tests/ContractChecks/test_completeness_rollups_cl02r.py::CompletenessRollupRuleTests.test_unfinished_code_child_does_not_count` | Added (new file) | `Tests/ContractChecks/test_completeness_rollups_cl02r.py` · `e5b3abb4c` |
| `Tests/ContractChecks/test_coop_invite_detail_page_ready.py::CoopInviteDetailPageReadyTests.test_existing_list_contract_is_wired_and_not_marked_live_here` | Added (new file) | `Tests/ContractChecks/test_coop_invite_detail_page_ready.py` · `5eecc80fe`, `79dc714c2` |
| `Tests/ContractChecks/test_coop_invite_detail_page_ready.py::CoopInviteDetailPageReadyTests.test_missing_keys_are_listed_and_now_catalogued` | Added (new file) | `Tests/ContractChecks/test_coop_invite_detail_page_ready.py` · `5eecc80fe`, `79dc714c2` |
| `Tests/ContractChecks/test_coop_invite_index_page_ready.py::CoopInviteIndexPageReadyContract.test_missing_keys_are_listed_and_not_invented_as_a_surface` | Added (new file) | `Tests/ContractChecks/test_coop_invite_index_page_ready.py` · `8eb7281ec`, `f67e8ab15` |
| `Tests/ContractChecks/test_coop_invite_index_page_ready.py::CoopInviteIndexPageReadyContract.test_model_keeps_states_unknown_dash_and_hides_missing_capabilities` | Added (new file) | `Tests/ContractChecks/test_coop_invite_index_page_ready.py` · `8eb7281ec`, `f67e8ab15` |
| `Tests/ContractChecks/test_coop_invite_index_page_ready.py::CoopInviteIndexPageReadyContract.test_swift_tests_were_added_without_removing_existing_ones` | Added (new file) | `Tests/ContractChecks/test_coop_invite_index_page_ready.py` · `8eb7281ec`, `f67e8ab15` |
| `Tests/ContractChecks/test_coop_list_page_ready.py::CoopListPageReadyTests.test_existing_list_route_stays_live_and_the_view_is_wired` | Added (new file) | `Tests/ContractChecks/test_coop_list_page_ready.py` · `06010091e`, `9e73a7d67` |
| `Tests/ContractChecks/test_coop_list_page_ready.py::CoopListPageReadyTests.test_missing_keys_are_listed_and_absent_from_the_catalog` | Added (new file) | `Tests/ContractChecks/test_coop_list_page_ready.py` · `06010091e`, `9e73a7d67` |
| `Tests/ContractChecks/test_coop_list_page_ready.py::CoopListPageReadyTests.test_model_states_keep_unknown_counts_and_hidden_capabilities` | Added (new file) | `Tests/ContractChecks/test_coop_list_page_ready.py` · `06010091e`, `9e73a7d67` |
| `Tests/ContractChecks/test_coupon_info_page_ready.py::CouponInfoPageReady.test_missing_keys_are_listed_and_not_invented` | Added (new file) | `Tests/ContractChecks/test_coupon_info_page_ready.py` · `731dd1001`, `5eecc80fe`, `81b1419c8` |
| `Tests/ContractChecks/test_coupon_info_page_ready.py::CouponInfoPageReady.test_referenced_keys_already_exist` | Added (new file) | `Tests/ContractChecks/test_coupon_info_page_ready.py` · `731dd1001`, `5eecc80fe`, `81b1419c8` |
| `Tests/ContractChecks/test_coupon_info_page_ready.py::CouponInfoPageReady.test_route_stays_partial_and_payment_stays_off` | Added (new file) | `Tests/ContractChecks/test_coupon_info_page_ready.py` · `731dd1001`, `5eecc80fe`, `81b1419c8` |
| `Tests/ContractChecks/test_cy_cached_async_image.py::CachedAsyncImageContract.test_component_and_tests_do_not_fetch` | Added (new file) | `Tests/ContractChecks/test_cy_cached_async_image.py` · `396251290`, `8f92c0fcc` |
| `Tests/ContractChecks/test_cy_cached_async_image.py::CachedAsyncImageContract.test_copy_is_bilingual` | Added (new file) | `Tests/ContractChecks/test_cy_cached_async_image.py` · `396251290`, `8f92c0fcc` |
| `Tests/ContractChecks/test_cy_cached_async_image.py::CachedAsyncImageContract.test_unknown_reference_returns_placeholder_before_any_loader` | Added (new file) | `Tests/ContractChecks/test_cy_cached_async_image.py` · `396251290`, `8f92c0fcc` |
| `Tests/ContractChecks/test_deregister_index_page_ready.py::DeregisterIndexPageReadyContract.test_existing_status_rules_tests_remain` | Added (new file) | `Tests/ContractChecks/test_deregister_index_page_ready.py` · `8792ad621`, `8c12a6417`, `c5150bf32` |
| `Tests/ContractChecks/test_deregister_index_page_ready.py::DeregisterIndexPageReadyContract.test_model_keeps_unknown_as_em_dash_and_hides_the_missing_result_route` | Added (new file) | `Tests/ContractChecks/test_deregister_index_page_ready.py` · `8792ad621`, `8c12a6417`, `c5150bf32` |
| `Tests/ContractChecks/test_deregister_index_page_ready.py::DeregisterIndexPageReadyContract.test_model_names_state_keys_and_unknown_mark` | Added (new file) | `Tests/ContractChecks/test_deregister_index_page_ready.py` · `8792ad621`, `8c12a6417`, `c5150bf32` |
| `Tests/ContractChecks/test_e2e_20261113_r12_r13.py::E2E20261113R12R13.test_home_continuation_keys_are_translated` | Added (new file) | `Tests/ContractChecks/test_e2e_20261113_r12_r13.py` · `ba831b510` |
| `Tests/ContractChecks/test_e2e_20261113_r12_r13.py::E2E20261113R12R13.test_journey_reader_reads_with_the_china_player_grant` | Added (new file) | `Tests/ContractChecks/test_e2e_20261113_r12_r13.py` · `ba831b510` |
| `Tests/ContractChecks/test_e2e_20261113_r12_r13.py::E2E20261113R12R13.test_post_review_unavailable_note_follows_the_write_grant` | Added (new file) | `Tests/ContractChecks/test_e2e_20261113_r12_r13.py` · `ba831b510` |
| `Tests/ContractChecks/test_e2e_activity_signup_cta.py::ActivitySignupCTA.test_session_activity_details_enable_registration` | Added (new file) | `Tests/ContractChecks/test_e2e_activity_signup_cta.py` · `4f38fb85b` |
| `Tests/ContractChecks/test_e2e_activity_signup_cta.py::ActivitySignupCTA.test_topic_detail_activity_link_enables_registration` | Added (new file) | `Tests/ContractChecks/test_e2e_activity_signup_cta.py` · `4f38fb85b` |
| `Tests/ContractChecks/test_growth_center_index_page_ready.py::GrowthCenterIndexPageReady.test_catalog_matches_live_copy_and_identifiers` | Added (new file) | `Tests/ContractChecks/test_growth_center_index_page_ready.py` · `f689933ef` |
| `Tests/ContractChecks/test_growth_center_index_page_ready.py::GrowthCenterIndexPageReady.test_debug_fixture_data_already_exists` | Added (new file) | `Tests/ContractChecks/test_growth_center_index_page_ready.py` · `f689933ef` |
| `Tests/ContractChecks/test_growth_center_index_page_ready.py::GrowthCenterIndexPageReady.test_unknown_stays_nil_in_the_model_and_live_routes_stay_closed` | Added (new file) | `Tests/ContractChecks/test_growth_center_index_page_ready.py` · `f689933ef` |
| `Tests/ContractChecks/test_growth_leaderboard_page_ready.py::GrowthLeaderboardPageReadyContract.test_accessibility_identifiers_match_the_existing_page` | Added (new file) | `Tests/ContractChecks/test_growth_leaderboard_page_ready.py` · `cdfc87b7b` |
| `Tests/ContractChecks/test_growth_leaderboard_page_ready.py::GrowthLeaderboardPageReadyContract.test_catalog_has_english_and_chinese_and_unknown_is_an_em_dash` | Added (new file) | `Tests/ContractChecks/test_growth_leaderboard_page_ready.py` · `cdfc87b7b` |
| `Tests/ContractChecks/test_growth_leaderboard_page_ready.py::GrowthLeaderboardPageReadyContract.test_debug_fixture_data_already_covers_the_board` | Added (new file) | `Tests/ContractChecks/test_growth_leaderboard_page_ready.py` · `cdfc87b7b` |
| `Tests/ContractChecks/test_growth_leaderboard_page_ready.py::GrowthLeaderboardPageReadyContract.test_model_keeps_loading_empty_error_and_unknown_and_hides_missing_boards` | Added (new file) | `Tests/ContractChecks/test_growth_leaderboard_page_ready.py` · `cdfc87b7b` |
| `Tests/ContractChecks/test_home_city_location_consent.py::HomeCityLocationConsentWiring.test_agree_records_privacy_policy_home_city_and_decline_saves_locally` | Added (new file) | `Tests/ContractChecks/test_home_city_location_consent.py` · `4c5e89ecc`, `88fdb6b8b` |
| `Tests/ContractChecks/test_home_city_location_consent.py::HomeCityLocationConsentWiring.test_glue_files_stay_at_the_ratchet_ceiling` | Added (new file) | `Tests/ContractChecks/test_home_city_location_consent.py` · `4c5e89ecc`, `88fdb6b8b` |
| `Tests/ContractChecks/test_home_city_location_consent.py::HomeCityLocationConsentWiring.test_row_17_wires_the_existing_card_without_a_second_search_or_a_new_order` | Added (new file) | `Tests/ContractChecks/test_home_city_location_consent.py` · `4c5e89ecc`, `88fdb6b8b` |
| `Tests/ContractChecks/test_home_city_location_consent.py::HomeCityLocationConsentWiring.test_unknown_is_an_em_dash_in_both_languages` | Added (new file) | `Tests/ContractChecks/test_home_city_location_consent.py` · `4c5e89ecc`, `88fdb6b8b` |
| `Tests/ContractChecks/test_im_coop_invite_strip_wiring.py::IMCoopInviteStripWiringTests.test_message_list_calls_factory_once_and_wires_the_local_reminder` | Added (new file) | `Tests/ContractChecks/test_im_coop_invite_strip_wiring.py` · `e8e6cbbc9`, `a1bcb311c` |
| `Tests/ContractChecks/test_im_coop_invite_strip_wiring.py::IMCoopInviteStripWiringTests.test_reminder_is_local_permission_not_a_server_or_push_topic` | Added (new file) | `Tests/ContractChecks/test_im_coop_invite_strip_wiring.py` · `e8e6cbbc9`, `a1bcb311c` |
| `Tests/ContractChecks/test_im_coop_invite_strip_wiring.py::IMCoopInviteStripWiringTests.test_strip_load_uses_coop_list_only_on_the_session_reader` | Added (new file) | `Tests/ContractChecks/test_im_coop_invite_strip_wiring.py` · `e8e6cbbc9`, `a1bcb311c` |
| `Tests/ContractChecks/test_im_coop_invite_strip_wiring.py::IMCoopInviteStripWiringTests.test_unknown_mark_is_an_em_dash_in_english_and_simplified_chinese` | Added (new file) | `Tests/ContractChecks/test_im_coop_invite_strip_wiring.py` · `e8e6cbbc9`, `a1bcb311c` |
| `Tests/ContractChecks/test_im_preview_lease_conversation_source.py::IMPreviewLeaseConversationSource.test_conversation_id_comes_from_a_server_message_record` | Added (new file) | `Tests/ContractChecks/test_im_preview_lease_conversation_source.py` · `a453a6ec9`, `78b59426a` |
| `Tests/ContractChecks/test_im_preview_lease_conversation_source.py::IMPreviewLeaseConversationSource.test_lease_refuses_a_message_from_another_conversation` | Added (new file) | `Tests/ContractChecks/test_im_preview_lease_conversation_source.py` · `a453a6ec9`, `78b59426a` |
| `Tests/ContractChecks/test_im_send_receipt_composition.py::IMSendReceiptCompositionContracts.test_signed_in_receipt_is_admitted_without_opening_send` | Added (new file) | `Tests/ContractChecks/test_im_send_receipt_composition.py` · `b5f0ade75` |
| `Tests/ContractChecks/test_information_detail_page_ready.py::InformationDetailPageReady.test_fixture_data_is_debug_only_and_uses_the_existing_path` | Added (new file) | `Tests/ContractChecks/test_information_detail_page_ready.py` · `4a157c02c`, `b2565e4dc` |
| `Tests/ContractChecks/test_information_detail_page_ready.py::InformationDetailPageReady.test_model_keeps_existing_detail_path_and_unknown_em_dash` | Added (new file) | `Tests/ContractChecks/test_information_detail_page_ready.py` · `4a157c02c`, `b2565e4dc` |
| `Tests/ContractChecks/test_information_detail_page_ready.py::InformationDetailPageReady.test_strings_are_bilingual_and_name_accessibility_ids` | Added (new file) | `Tests/ContractChecks/test_information_detail_page_ready.py` · `4a157c02c`, `b2565e4dc` |
| `Tests/ContractChecks/test_information_detail_page_ready.py::InformationDetailPageReady.test_unit_tests_cover_states_without_removing_prior_files` | Added (new file) | `Tests/ContractChecks/test_information_detail_page_ready.py` · `4a157c02c`, `b2565e4dc` |
| `Tests/ContractChecks/test_invoice_apply_page_ready.py::InvoiceApplyPageReady.test_referenced_keys_already_exist_in_the_invoice_catalog` | Added (new file) | `Tests/ContractChecks/test_invoice_apply_page_ready.py` · `731dd1001`, `4716aafdc` |
| `Tests/ContractChecks/test_invoice_apply_page_ready.py::InvoiceApplyPageReady.test_route_stays_partial_and_payment_stays_off` | Added (new file) | `Tests/ContractChecks/test_invoice_apply_page_ready.py` · `731dd1001`, `4716aafdc` |
| `Tests/ContractChecks/test_invoice_apply_page_ready.py::InvoiceApplyPageReady.test_unlabeled_order_fields_are_not_given_invented_copy` | Added (new file) | `Tests/ContractChecks/test_invoice_apply_page_ready.py` · `731dd1001`, `4716aafdc` |
| `Tests/ContractChecks/test_member_home_page_ready.py::MemberHomePageReadyContractTests.test_accessibility_identifiers_are_declared_once` | Added (new file) | `Tests/ContractChecks/test_member_home_page_ready.py` · `8c12a6417`, `c5150bf32` |
| `Tests/ContractChecks/test_member_home_page_ready.py::MemberHomePageReadyContractTests.test_states_routes_and_money_switches_stay_off` | Added (new file) | `Tests/ContractChecks/test_member_home_page_ready.py` · `8c12a6417`, `c5150bf32` |
| `Tests/ContractChecks/test_member_home_page_ready.py::MemberHomePageReadyContractTests.test_unknown_is_an_em_dash_in_the_model` | Added (new file) | `Tests/ContractChecks/test_member_home_page_ready.py` · `8c12a6417`, `c5150bf32` |
| `Tests/ContractChecks/test_mylike_page_ready.py::MyLikePageReadyContract.test_model_keeps_states_unknown_dash_and_does_not_mark_a_route` | Added (new file) | `Tests/ContractChecks/test_mylike_page_ready.py` · `4a157c02c`, `b91de3b4a`, `b1de1db35` |
| `Tests/ContractChecks/test_mylike_page_ready.py::MyLikePageReadyContract.test_note_lists_missing_keys_and_leaves_the_view_alone` | Added (new file) | `Tests/ContractChecks/test_mylike_page_ready.py` · `4a157c02c`, `b91de3b4a`, `b1de1db35` |
| `Tests/ContractChecks/test_mylike_page_ready.py::MyLikePageReadyContract.test_swift_tests_were_added_without_removing_existing_ones` | Added (new file) | `Tests/ContractChecks/test_mylike_page_ready.py` · `4a157c02c`, `b91de3b4a`, `b1de1db35` |
| `Tests/ContractChecks/test_myproject_page_ready.py::MyProjectPageReadyContract.test_accessibility_identifiers_exist_in_non_view_or_existing_app_sources` | Added (new file) | `Tests/ContractChecks/test_myproject_page_ready.py` · `714e8566b` |
| `Tests/ContractChecks/test_myproject_page_ready.py::MyProjectPageReadyContract.test_fixture_data_is_debug_only_and_existing_tests_stay` | Added (new file) | `Tests/ContractChecks/test_myproject_page_ready.py` · `714e8566b` |
| `Tests/ContractChecks/test_myproject_page_ready.py::MyProjectPageReadyContract.test_model_keeps_unknown_counts_and_hides_missing_writes` | Added (new file) | `Tests/ContractChecks/test_myproject_page_ready.py` · `714e8566b` |
| `Tests/ContractChecks/test_myproject_page_ready.py::MyProjectPageReadyContract.test_string_manifest_matches_catalogs_and_names_unknown_as_em_dash` | Added (new file) | `Tests/ContractChecks/test_myproject_page_ready.py` · `714e8566b` |
| `Tests/ContractChecks/test_object_badge_3d_preview.py::ObjectBadge3DPreviewContract.test_existing_turntable_tests_and_new_preview_tests_both_stay` | Added (new file) | `Tests/ContractChecks/test_object_badge_3d_preview.py` · `d63e66aed` |
| `Tests/ContractChecks/test_object_badge_3d_preview.py::ObjectBadge3DPreviewContract.test_model_keeps_four_states_unknown_mark_and_debug_fixture_only` | Added (new file) | `Tests/ContractChecks/test_object_badge_3d_preview.py` · `d63e66aed` |
| `Tests/ContractChecks/test_object_badge_3d_preview.py::ObjectBadge3DPreviewContract.test_string_catalog_has_both_languages_and_the_unknown_mark` | Added (new file) | `Tests/ContractChecks/test_object_badge_3d_preview.py` · `d63e66aed` |
| `Tests/ContractChecks/test_object_badge_wall_page_state.py::ObjectBadgeWallPageStateContract.test_model_states_use_em_dash_and_existing_read` | Added (new file) | `Tests/ContractChecks/test_object_badge_wall_page_state.py` · `107ad8663` |
| `Tests/ContractChecks/test_object_badge_wall_page_state.py::ObjectBadgeWallPageStateContract.test_new_tests_do_not_weaken_existing_badge_wall_tests` | Added (new file) | `Tests/ContractChecks/test_object_badge_wall_page_state.py` · `107ad8663` |
| `Tests/ContractChecks/test_object_badge_wall_page_state.py::ObjectBadgeWallPageStateContract.test_strings_are_bilingual_and_name_accessibility_identifiers` | Added (new file) | `Tests/ContractChecks/test_object_badge_wall_page_state.py` · `107ad8663` |
| `Tests/ContractChecks/test_official_event_contracts.py::OfficialSourceChecks.test_activity_list_page_states_and_string_spec` | Added (existing file) | `Tests/ContractChecks/test_official_event_contracts.py` · `4a157c02c`, `fd75ee0ca`, `773af19aa` |
| `Tests/ContractChecks/test_official_inbox_page_ready.py::OfficialInboxPageReadyChecks.test_fixture_data_is_debug_only_and_flags_stay_off` | Added (new file) | `Tests/ContractChecks/test_official_inbox_page_ready.py` · `8792ad621`, `773af19aa` |
| `Tests/ContractChecks/test_official_inbox_page_ready.py::OfficialInboxPageReadyChecks.test_model_keeps_unknown_distinct_from_zero_and_hides_missing_routes` | Added (new file) | `Tests/ContractChecks/test_official_inbox_page_ready.py` · `8792ad621`, `773af19aa` |
| `Tests/ContractChecks/test_official_inbox_page_ready.py::OfficialInboxPageReadyChecks.test_string_catalog_has_both_languages_and_identifiers` | Added (new file) | `Tests/ContractChecks/test_official_inbox_page_ready.py` · `8792ad621`, `773af19aa` |
| `Tests/ContractChecks/test_official_mine_page_ready.py::OfficialMinePageReadyChecks.test_coordinator_uses_existing_reads_and_hides_a_missing_grant` | Added (new file) | `Tests/ContractChecks/test_official_mine_page_ready.py` · `773af19aa` |
| `Tests/ContractChecks/test_official_mine_page_ready.py::OfficialMinePageReadyChecks.test_debug_fixture_data_stays_inside_debug` | Added (new file) | `Tests/ContractChecks/test_official_mine_page_ready.py` · `773af19aa` |
| `Tests/ContractChecks/test_official_mine_page_ready.py::OfficialMinePageReadyChecks.test_existing_published_presentation_tests_remain` | Added (new file) | `Tests/ContractChecks/test_official_mine_page_ready.py` · `773af19aa` |
| `Tests/ContractChecks/test_official_mine_page_ready.py::OfficialMinePageReadyChecks.test_model_has_loading_empty_error_and_unknown_em_dash` | Added (new file) | `Tests/ContractChecks/test_official_mine_page_ready.py` · `773af19aa` |
| `Tests/ContractChecks/test_official_mine_page_ready.py::OfficialMinePageReadyChecks.test_string_file_has_both_languages_and_identifiers` | Added (new file) | `Tests/ContractChecks/test_official_mine_page_ready.py` · `773af19aa` |
| `Tests/ContractChecks/test_offline_pack_and_nav_consent.py::OfflinePackAndNavConsentContracts.test_limited_offline_claims_do_not_widen_play_or_hide_empty_api` | Added (existing file) | `Tests/ContractChecks/test_offline_pack_and_nav_consent.py` · `f9c5e19c0` |
| `Tests/ContractChecks/test_pages_activity_baoming_baoming.py::ActivityBaomingPageReadyTests.test_fixture_data_is_debug_only_and_offline` | Added (new file) | `Tests/ContractChecks/test_pages_activity_baoming_baoming.py` · `773af19aa` |
| `Tests/ContractChecks/test_pages_activity_baoming_baoming.py::ActivityBaomingPageReadyTests.test_model_has_four_states_and_unknown_is_an_em_dash` | Added (new file) | `Tests/ContractChecks/test_pages_activity_baoming_baoming.py` · `773af19aa` |
| `Tests/ContractChecks/test_pages_activity_baoming_baoming.py::ActivityBaomingPageReadyTests.test_string_catalog_has_english_chinese_and_accessibility_identifiers` | Added (new file) | `Tests/ContractChecks/test_pages_activity_baoming_baoming.py` · `773af19aa` |
| `Tests/ContractChecks/test_pages_activity_baoming_baoming.py::ActivityBaomingPageReadyTests.test_unit_tests_cover_phases_without_removing_the_previous_case` | Added (new file) | `Tests/ContractChecks/test_pages_activity_baoming_baoming.py` · `773af19aa` |
| `Tests/ContractChecks/test_pages_address_address_page_ready.py::AddressListPageReadyContract.test_list_card_does_not_add_contact_fields` | Added (new file) | `Tests/ContractChecks/test_pages_address_address_page_ready.py` · `a3cba9cbd` |
| `Tests/ContractChecks/test_pages_address_address_page_ready.py::AddressListPageReadyContract.test_model_keeps_unknown_counts_as_em_dash` | Added (new file) | `Tests/ContractChecks/test_pages_address_address_page_ready.py` · `a3cba9cbd` |
| `Tests/ContractChecks/test_pages_address_address_page_ready.py::AddressListPageReadyContract.test_note_lists_missing_keys_and_tests_cover_states` | Added (new file) | `Tests/ContractChecks/test_pages_address_address_page_ready.py` · `a3cba9cbd` |
| `Tests/ContractChecks/test_pages_agreement_index.py::PagesAgreementIndexTests.test_accessibility_identifiers_and_unknown_live_in_the_model` | Added (new file) | `Tests/ContractChecks/test_pages_agreement_index.py` · `8c12a6417`, `c5150bf32` |
| `Tests/ContractChecks/test_pages_agreement_index.py::PagesAgreementIndexTests.test_debug_fixture_data_is_compiled_out_of_release` | Added (new file) | `Tests/ContractChecks/test_pages_agreement_index.py` · `8c12a6417`, `c5150bf32` |
| `Tests/ContractChecks/test_pages_agreement_index.py::PagesAgreementIndexTests.test_existing_legal_tests_remain` | Added (new file) | `Tests/ContractChecks/test_pages_agreement_index.py` · `8c12a6417`, `c5150bf32` |
| `Tests/ContractChecks/test_pages_agreement_index.py::PagesAgreementIndexTests.test_page_facts_keep_unknown_as_an_em_dash_and_hide_the_missing_route` | Added (new file) | `Tests/ContractChecks/test_pages_agreement_index.py` · `8c12a6417`, `c5150bf32` |
| `Tests/ContractChecks/test_pages_crop_index.py::PagesCropIndexTests.test_missing_keys_are_listed_and_not_added_to_the_catalog` | Added (new file) | `Tests/ContractChecks/test_pages_crop_index.py` · `4a157c02c`, `e60225394` |
| `Tests/ContractChecks/test_pages_crop_index.py::PagesCropIndexTests.test_page_model_keeps_unknown_as_an_em_dash_and_does_not_upload` | Added (new file) | `Tests/ContractChecks/test_pages_crop_index.py` · `4a157c02c`, `e60225394` |
| `Tests/ContractChecks/test_pages_index_index_strings.py::PagesIndexIndexStrings.test_fixture_data_stays_debug_only_and_omits_a_price` | Added (new file) | `Tests/ContractChecks/test_pages_index_index_strings.py` · `8c12a6417`, `c5150bf32` |
| `Tests/ContractChecks/test_pages_index_index_strings.py::PagesIndexIndexStrings.test_unknown_is_an_em_dash_in_the_model` | Added (new file) | `Tests/ContractChecks/test_pages_index_index_strings.py` · `8c12a6417`, `c5150bf32` |
| `Tests/ContractChecks/test_pages_privacy_index_page_ready.py::PagesPrivacyIndexPageReadyTests.test_accessibility_constants_name_states_and_unknown` | Added (new file) | `Tests/ContractChecks/test_pages_privacy_index_page_ready.py` · `8792ad621`, `8c12a6417`, `c5150bf32` |
| `Tests/ContractChecks/test_pages_privacy_index_page_ready.py::PagesPrivacyIndexPageReadyTests.test_existing_view_identifiers_stay_on_the_model` | Added (new file) | `Tests/ContractChecks/test_pages_privacy_index_page_ready.py` · `8792ad621`, `8c12a6417`, `c5150bf32` |
| `Tests/ContractChecks/test_pages_privacy_index_page_ready.py::PagesPrivacyIndexPageReadyTests.test_model_has_states_and_does_not_invent_a_live_route` | Added (new file) | `Tests/ContractChecks/test_pages_privacy_index_page_ready.py` · `8792ad621`, `8c12a6417`, `c5150bf32` |
| `Tests/ContractChecks/test_pages_shezhi_shezhi.py::PagesShezhiShezhiTests.test_debug_fixture_data_is_compiled_out_of_release` | Added (new file) | `Tests/ContractChecks/test_pages_shezhi_shezhi.py` · `4bb11befa`, `039b51051`, `8708c66e0` |
| `Tests/ContractChecks/test_pages_shezhi_shezhi.py::PagesShezhiShezhiTests.test_existing_settings_offer_behavior_is_unchanged` | Added (new file) | `Tests/ContractChecks/test_pages_shezhi_shezhi.py` · `4bb11befa`, `039b51051`, `8708c66e0` |
| `Tests/ContractChecks/test_pages_shezhi_shezhi.py::PagesShezhiShezhiTests.test_home_page_keeps_unknown_as_an_em_dash_and_does_not_mark_a_route_live` | Added (new file) | `Tests/ContractChecks/test_pages_shezhi_shezhi.py` · `4bb11befa`, `039b51051`, `8708c66e0` |
| `Tests/ContractChecks/test_pages_shezhi_shezhi.py::PagesShezhiShezhiTests.test_missing_phase_keys_are_listed_and_not_invented_in_the_catalog` | Added (new file) | `Tests/ContractChecks/test_pages_shezhi_shezhi.py` · `4bb11befa`, `039b51051`, `8708c66e0` |
| `Tests/ContractChecks/test_pages_template_index_page_ready.py::PagesTemplateIndexPageReadyTests.test_missing_chapter_is_not_treated_as_a_known_zero` | Added (new file) | `Tests/ContractChecks/test_pages_template_index_page_ready.py` · `8c12a6417`, `c5150bf32` |
| `Tests/ContractChecks/test_pages_template_index_page_ready.py::PagesTemplateIndexPageReadyTests.test_model_names_phase_accessibility_and_unknown` | Added (new file) | `Tests/ContractChecks/test_pages_template_index_page_ready.py` · `8c12a6417`, `c5150bf32` |
| `Tests/ContractChecks/test_pages_template_index_page_ready.py::PagesTemplateIndexPageReadyTests.test_model_states_and_existing_reads_stay_hidden_where_required` | Added (new file) | `Tests/ContractChecks/test_pages_template_index_page_ready.py` · `8c12a6417`, `c5150bf32` |
| `Tests/ContractChecks/test_play_guide_information_list_page.py::PlayGuideInformationListPageContract.test_closed_flags_and_routes_are_not_introduced` | Added (new file) | `Tests/ContractChecks/test_play_guide_information_list_page.py` · `b04f3230c`, `d1fef1b00` |
| `Tests/ContractChecks/test_play_guide_information_list_page.py::PlayGuideInformationListPageContract.test_model_keeps_four_states_and_the_existing_list_path` | Added (new file) | `Tests/ContractChecks/test_play_guide_information_list_page.py` · `b04f3230c`, `d1fef1b00` |
| `Tests/ContractChecks/test_play_guide_information_list_page.py::PlayGuideInformationListPageContract.test_strings_have_both_languages_and_accessibility_identifiers` | Added (new file) | `Tests/ContractChecks/test_play_guide_information_list_page.py` · `b04f3230c`, `d1fef1b00` |
| `Tests/ContractChecks/test_play_poi_challenge_page.py::PlayPoiChallengePageContract.test_debug_fixture_is_debug_only` | Added (new file) | `Tests/ContractChecks/test_play_poi_challenge_page.py` · `773af19aa` |
| `Tests/ContractChecks/test_play_poi_challenge_page.py::PlayPoiChallengePageContract.test_existing_gates_stay_closed` | Added (new file) | `Tests/ContractChecks/test_play_poi_challenge_page.py` · `773af19aa` |
| `Tests/ContractChecks/test_play_poi_challenge_page.py::PlayPoiChallengePageContract.test_model_keeps_unknown_as_em_dash_and_hides_a_missing_grant` | Added (new file) | `Tests/ContractChecks/test_play_poi_challenge_page.py` · `773af19aa` |
| `Tests/ContractChecks/test_play_poi_challenge_page.py::PlayPoiChallengePageContract.test_strings_have_english_chinese_and_accessibility_ids` | Added (new file) | `Tests/ContractChecks/test_play_poi_challenge_page.py` · `773af19aa` |
| `Tests/ContractChecks/test_player_write_grant.py::PlayerWriteGrantContracts.test_writers_are_inside_the_reviewed_gate` | Added (new file) | `Tests/ContractChecks/test_player_write_grant.py` · `268c4c3c8`, `4afc37c32`, `aafc5179c`, `37415f606`, `c2e572797` |
| `Tests/ContractChecks/test_roam_anniversary_navigation.py::RoamAnniversaryNavigationContracts.test_tool_destinations_are_hoisted_off_the_list_rows` | Added (existing file) | `Tests/ContractChecks/test_roam_anniversary_navigation.py` · `ed888be64` |
| `Tests/ContractChecks/test_shezhi_marketing_index_page_ready.py::ShezhiMarketingIndexPageReadyContract.test_existing_marketing_journey_tests_remain` | Added (new file) | `Tests/ContractChecks/test_shezhi_marketing_index_page_ready.py` · `8792ad621`, `2aee69a86` |
| `Tests/ContractChecks/test_shezhi_marketing_index_page_ready.py::ShezhiMarketingIndexPageReadyContract.test_model_keeps_unknown_as_em_dash_and_hides_the_unlisted_result_route` | Added (new file) | `Tests/ContractChecks/test_shezhi_marketing_index_page_ready.py` · `8792ad621`, `2aee69a86` |
| `Tests/ContractChecks/test_shezhi_marketing_index_page_ready.py::ShezhiMarketingIndexPageReadyContract.test_note_lists_missing_keys_and_existing_copy_stays_bilingual` | Added (new file) | `Tests/ContractChecks/test_shezhi_marketing_index_page_ready.py` · `8792ad621`, `2aee69a86` |
| `Tests/ContractChecks/test_sign_in_with_apple_flow.py::SignInWithAppleFlowContract.test_china_host_and_realm_stay_on_the_reviewed_profile_only` | Added (new file) | `Tests/ContractChecks/test_sign_in_with_apple_flow.py` · `67d0b107e` |
| `Tests/ContractChecks/test_sign_in_with_apple_flow.py::SignInWithAppleFlowContract.test_core_tests_cover_the_hidden_and_entitlement_paths` | Added (new file) | `Tests/ContractChecks/test_sign_in_with_apple_flow.py` · `67d0b107e` |
| `Tests/ContractChecks/test_sign_in_with_apple_flow.py::SignInWithAppleFlowContract.test_empty_base_build_does_not_enable_or_name_a_host` | Added (new file) | `Tests/ContractChecks/test_sign_in_with_apple_flow.py` · `67d0b107e` |
| `Tests/ContractChecks/test_sign_in_with_apple_flow.py::SignInWithAppleFlowContract.test_entitlement_file_is_only_the_default_sign_in_value` | Added (new file) | `Tests/ContractChecks/test_sign_in_with_apple_flow.py` · `67d0b107e` |
| `Tests/ContractChecks/test_sign_in_with_apple_flow.py::SignInWithAppleFlowContract.test_flow_refuses_an_empty_url_and_is_not_mounted` | Added (new file) | `Tests/ContractChecks/test_sign_in_with_apple_flow.py` · `67d0b107e` |
| `Tests/ContractChecks/test_square_detail_page_ready.py::SquareDetailPageReadyContract.test_model_keeps_states_unknown_dash_and_does_not_mark_a_route` | Added (new file) | `Tests/ContractChecks/test_square_detail_page_ready.py` · `4a157c02c`, `4bb11befa`, `b91de3b4a`, `7e7896137` |
| `Tests/ContractChecks/test_square_detail_page_ready.py::SquareDetailPageReadyContract.test_note_lists_missing_keys_and_leaves_the_view_alone` | Added (new file) | `Tests/ContractChecks/test_square_detail_page_ready.py` · `4a157c02c`, `4bb11befa`, `b91de3b4a`, `7e7896137` |
| `Tests/ContractChecks/test_square_detail_page_ready.py::SquareDetailPageReadyContract.test_swift_tests_were_added_without_removing_existing_ones` | Added (new file) | `Tests/ContractChecks/test_square_detail_page_ready.py` · `4a157c02c`, `4bb11befa`, `b91de3b4a`, `7e7896137` |
| `Tests/ContractChecks/test_subpackage_member_invoice_titles_index.py::InvoiceTitlesPageReadyTests.test_existing_title_form_rules_are_unchanged` | Added (new file) | `Tests/ContractChecks/test_subpackage_member_invoice_titles_index.py` · `8eb7281ec`, `75a3f71ba`, `b0165a252` |
| `Tests/ContractChecks/test_subpackage_member_invoice_titles_index.py::InvoiceTitlesPageReadyTests.test_missing_keys_are_listed_and_existing_title_keys_stay_translated` | Added (new file) | `Tests/ContractChecks/test_subpackage_member_invoice_titles_index.py` · `8eb7281ec`, `75a3f71ba`, `b0165a252` |
| `Tests/ContractChecks/test_subpackage_member_invoice_titles_index.py::InvoiceTitlesPageReadyTests.test_projection_keeps_unknown_as_an_em_dash_and_does_not_mark_a_route_live` | Added (new file) | `Tests/ContractChecks/test_subpackage_member_invoice_titles_index.py` · `8eb7281ec`, `75a3f71ba`, `b0165a252` |
| `Tests/ContractChecks/test_team_invitation_detail_navigation.py::JoinedInvitationDetailNavigationTests.test_join_page_unknown_count_contract` | Added (existing file) | `Tests/ContractChecks/test_team_invitation_detail_navigation.py` · `8c12a6417`, `c5150bf32` |
| `Tests/ContractChecks/test_template_authoring_page_readiness.py::TemplateAuthoringPageReadinessContract.test_coordinator_classifies_without_a_new_send` | Added (new file) | `Tests/ContractChecks/test_template_authoring_page_readiness.py` · `3a6bf530f`, `eb4f54a0c` |
| `Tests/ContractChecks/test_template_authoring_page_readiness.py::TemplateAuthoringPageReadinessContract.test_fixture_data_stays_debug_only` | Added (new file) | `Tests/ContractChecks/test_template_authoring_page_readiness.py` · `3a6bf530f`, `eb4f54a0c` |
| `Tests/ContractChecks/test_template_authoring_page_readiness.py::TemplateAuthoringPageReadinessContract.test_page_stays_gated_and_flags_stay_off` | Added (new file) | `Tests/ContractChecks/test_template_authoring_page_readiness.py` · `3a6bf530f`, `eb4f54a0c` |
| `Tests/ContractChecks/test_template_authoring_page_readiness.py::TemplateAuthoringPageReadinessContract.test_phases_and_em_dash_are_in_the_model` | Added (new file) | `Tests/ContractChecks/test_template_authoring_page_readiness.py` · `3a6bf530f`, `eb4f54a0c` |
| `Tests/ContractChecks/test_template_authoring_page_readiness.py::TemplateAuthoringPageReadinessContract.test_strings_are_bilingual_and_name_identifiers` | Added (new file) | `Tests/ContractChecks/test_template_authoring_page_readiness.py` · `3a6bf530f`, `eb4f54a0c` |
| `Tests/ContractChecks/test_template_intro_page_ready.py::TemplateIntroPageReadyContract.test_model_states_and_fixture_stay_debug_only` | Added (new file) | `Tests/ContractChecks/test_template_intro_page_ready.py` · `4f180d862` |
| `Tests/ContractChecks/test_template_intro_page_ready.py::TemplateIntroPageReadyContract.test_strings_have_en_and_zh_hans_and_identifiers` | Added (new file) | `Tests/ContractChecks/test_template_intro_page_ready.py` · `4f180d862` |
| `Tests/ContractChecks/test_template_own_shelf_read_state.py::TemplateOwnShelfReadStateContract.test_fragment_is_the_mini_wording_and_is_merged` | Added (existing file) | `Tests/ContractChecks/test_template_own_shelf_read_state.py` · `d1c5378e4` |
| `Tests/ContractChecks/test_universal_link_associated_domains.py::UniversalLinkAssociatedDomains.test_configuration_stays_empty_and_production_allowlist_stays_empty` | Added (new file) | `Tests/ContractChecks/test_universal_link_associated_domains.py` · `ab93558a1` |
| `Tests/ContractChecks/test_universal_link_associated_domains.py::UniversalLinkAssociatedDomains.test_entitlement_claims_sign_in_with_apple_only` | Added (new file) | `Tests/ContractChecks/test_universal_link_associated_domains.py` · `ab93558a1` |
| `Tests/ContractChecks/test_universal_link_associated_domains.py::UniversalLinkAssociatedDomains.test_plan_names_a_placeholder_host_and_no_real_applink` | Added (new file) | `Tests/ContractChecks/test_universal_link_associated_domains.py` · `ab93558a1` |
| `Tests/ContractChecks/test_universal_link_associated_domains.py::UniversalLinkAssociatedDomains.test_release_identity_stays_unconfigured` | Added (new file) | `Tests/ContractChecks/test_universal_link_associated_domains.py` · `ab93558a1` |
| `Tests/ContractChecks/test_wire13_governance_project.py::T.test_view_reads_governance_page_project` | Added (new file) | `Tests/ContractChecks/test_wire13_governance_project.py` · `98cbc7350` |
| `Tests/ContractChecks/test_wire14_group_code_view.py::ClubGroupCodeViewWireContract.test_group_code_view_reads_project` | Added (new file) | `Tests/ContractChecks/test_wire14_group_code_view.py` · `b3c5c2586` |
| `Tests/ContractChecks/test_workshop_paid_lifecycle_closure.py::PaidInstallLifecycleSourceContracts.test_paid_install_follows_the_money_switch` | Added (existing file) | `Tests/ContractChecks/test_workshop_paid_lifecycle_closure.py` · `fad470999`, `f9fc85147`, `0b170ed55` |
| `Tests/ContractChecks/test_workshop_paid_lifecycle_closure.py::PaidInstallLifecycleSourceContracts.test_service_and_journal_exist` | Added (existing file) | `Tests/ContractChecks/test_workshop_paid_lifecycle_closure.py` · `fad470999`, `f9fc85147`, `0b170ed55` |
| `Tests/ContractChecks/test_wp11_session_location.py::WP11SessionLocationContracts.test_own_10_3c_schema_has_no_runtime_loader_or_validated_claim` | Added (new file) | `Tests/ContractChecks/test_wp11_session_location.py` · `ce5e28999`, `1e48434aa` |
| `Tests/ContractChecks/test_wp11_session_location.py::WP11SessionLocationContracts.test_own_d01c_app_and_core_have_no_client_point_deduct_rate` | Added (new file) | `Tests/ContractChecks/test_wp11_session_location.py` · `ce5e28999`, `1e48434aa` |
| `Tests/ContractChecks/test_wp11_session_location.py::WP11SessionLocationContracts.test_own_d07a_plist_declares_only_session_location_background_and_when_in_use` | Added (new file) | `Tests/ContractChecks/test_wp11_session_location.py` · `ce5e28999`, `1e48434aa` |
| `Tests/ContractChecks/test_wp11_session_location.py::WP11SessionLocationContracts.test_own_d07a_zh_and_en_purpose_strings_describe_session_background_and_no_sharing` | Added (new file) | `Tests/ContractChecks/test_wp11_session_location.py` · `ce5e28999`, `1e48434aa` |
| `Tests/ContractChecks/test_wp11_session_location.py::WP11SessionLocationContracts.test_own_d07bc_play_and_roam_hold_the_tracker` | Added (new file) | `Tests/ContractChecks/test_wp11_session_location.py` · `ce5e28999`, `1e48434aa` |
| `Tests/ContractChecks/test_wp11_session_location.py::WP11SessionLocationContracts.test_own_d07e_privacy_pages_show_holds_with_stop` | Added (new file) | `Tests/ContractChecks/test_wp11_session_location.py` · `ce5e28999`, `1e48434aa` |
| `Tests/ContractChecks/test_wp11_session_location.py::WP11SessionLocationContracts.test_own_d07f_personal_location_share_approvals_stay_nil` | Added (new file) | `Tests/ContractChecks/test_wp11_session_location.py` · `ce5e28999`, `1e48434aa` |
| `Tests/ContractChecks/test_wp11_session_location.py::WP11SessionLocationContracts.test_own_opt042b_countdown_does_not_tick_from_the_device_clock` | Added (new file) | `Tests/ContractChecks/test_wp11_session_location.py` · `ce5e28999`, `1e48434aa` |
| `Tests/ContractChecks/test_wp11_session_location.py::WP11SessionLocationContracts.test_own_opt072_reference_is_recorded_and_shown` | Added (new file) | `Tests/ContractChecks/test_wp11_session_location.py` · `ce5e28999`, `1e48434aa` |
| `QuestifyCoreTests/AccountCollectionFavoritesPageReadyTests/testEmptyRowsStayEmptyAndAMissingListStaysUnknown` | Added (existing file) | `Tests/CoreTests/AccountCollectionTests.swift` · `b1de1db35`, `7ad943a49` |
| `QuestifyCoreTests/AccountCollectionFavoritesPageReadyTests/testExistingFavoriteRoutesStayLiveWithoutANewMark` | Added (existing file) | `Tests/CoreTests/AccountCollectionTests.swift` · `b1de1db35`, `7ad943a49` |
| `QuestifyCoreTests/AccountCollectionFavoritesPageReadyTests/testFailureLoadingAndRejectedShapesStaySeparate` | Added (existing file) | `Tests/CoreTests/AccountCollectionTests.swift` · `b1de1db35`, `7ad943a49` |
| `QuestifyCoreTests/AccountCollectionFavoritesPageReadyTests/testNumericStringFractionAndBooleanCountsStayUnknown` | Added (existing file) | `Tests/CoreTests/AccountCollectionTests.swift` · `b1de1db35`, `7ad943a49` |
| `QuestifyCoreTests/AccountCollectionFavoritesPageReadyTests/testOmittedPostCountsStayUnknownAndLiteralZeroStaysZero` | Added (existing file) | `Tests/CoreTests/AccountCollectionTests.swift` · `b1de1db35`, `7ad943a49` |
| `QuestifyCoreTests/AccountCollectionFavoritesPageReadyTests/testReadyPostKeepsLiteralCountsAndIgnoresTotal` | Added (existing file) | `Tests/CoreTests/AccountCollectionTests.swift` · `b1de1db35`, `7ad943a49` |
| `QuestifyCoreTests/AccountCollectionFavoritesPageReadyTests/testTopicCountsKeepLiteralZeroAndDoNotReadANumericStringAsZero` | Added (existing file) | `Tests/CoreTests/AccountCollectionTests.swift` · `b1de1db35`, `7ad943a49` |
| `QuestifyCoreTests/AccountCollectionFavoritesPageReadyTests/testUnknownMarkIsAnEmDashAndNotZero` | Added (existing file) | `Tests/CoreTests/AccountCollectionTests.swift` · `b1de1db35`, `7ad943a49` |
| `QuestifyCoreTests/AccountCollectionTests/testPublicShopProjectionKeepsLiteralZeroAndLeavesUnknownCoordinatesUnknown` | Added (existing file) | `Tests/CoreTests/AccountCollectionTests.swift` · `b1de1db35`, `7ad943a49` |
| `QuestifyCoreTests/AccountComplianceTests/testDeregisterIndexPageReadsExistingStatusAndKeepsUnknownAsEmDash` | Added (existing file) | `Tests/CoreTests/AccountComplianceTests.swift` · `50d3ac23e`, `4c5e89ecc`, `c5150bf32` |
| `QuestifyCoreTests/AccountComplianceTests/testRoamAgreeSendsExpectedRequestIdAndIsIdempotent` | Added (existing file) | `Tests/CoreTests/AccountComplianceTests.swift` · `50d3ac23e`, `4c5e89ecc`, `c5150bf32` |
| `QuestifyCoreTests/AccountDeletionEndToEndTests/testDerivedReceiptJourneyRecordsTheHandoffAndNeverCallsTheMissingResultRoute` | Added (new file) | `Tests/CoreTests/AccountDeletionEndToEndTests.swift` · `50d3ac23e`, `11d463439` |
| `QuestifyCoreTests/AccountDeletionEndToEndTests/testEligiblePrecheckWithBlockersNeverConsentsOrApplies` | Added (new file) | `Tests/CoreTests/AccountDeletionEndToEndTests.swift` · `50d3ac23e`, `11d463439` |
| `QuestifyCoreTests/AccountDeletionEndToEndTests/testFailedStatusAfterHandoffStaysUnknownAndDoesNotResend` | Added (new file) | `Tests/CoreTests/AccountDeletionEndToEndTests.swift` · `50d3ac23e`, `11d463439` |
| `QuestifyCoreTests/AccountDeletionEndToEndTests/testLostApplyRecoversTheReceiptOnANewClientWithoutPostingAgain` | Added (new file) | `Tests/CoreTests/AccountDeletionEndToEndTests.swift` · `50d3ac23e`, `11d463439` |
| `QuestifyCoreTests/AccountDeletionEndToEndTests/testPendingStatusBeforeApplyIsNotThisRequestsReceipt` | Added (new file) | `Tests/CoreTests/AccountDeletionEndToEndTests.swift` · `50d3ac23e`, `11d463439` |
| `QuestifyCoreTests/AccountScopedPersistenceTests/testAccountSwitchWipesOnlyThePreviousAccountAndRecoversTheNext` | Added (new file) | `Tests/CoreTests/AccountScopedPersistenceTests.swift` · `7c998d8ee` |
| `QuestifyCoreTests/AccountScopedPersistenceTests/testClassifyAuthorizesDeletionOnlyForADifferentAccount` | Added (new file) | `Tests/CoreTests/AccountScopedPersistenceTests.swift` · `7c998d8ee` |
| `QuestifyCoreTests/AccountScopedPersistenceTests/testCorruptReaderKeysStayOnMigrationAndClearOnAccountSwitch` | Added (new file) | `Tests/CoreTests/AccountScopedPersistenceTests.swift` · `7c998d8ee` |
| `QuestifyCoreTests/AccountScopedPersistenceTests/testExistingSchema2EnvelopeIsNotReplacedByOlderReaderKeys` | Added (new file) | `Tests/CoreTests/AccountScopedPersistenceTests.swift` · `7c998d8ee` |
| `QuestifyCoreTests/AccountScopedPersistenceTests/testFutureSchemaIsNotMigratedOrWiped` | Added (new file) | `Tests/CoreTests/AccountScopedPersistenceTests.swift` · `7c998d8ee` |
| `QuestifyCoreTests/AccountScopedPersistenceTests/testLegacySchemaMigratesWithoutDeletingTheReaderKeys` | Added (new file) | `Tests/CoreTests/AccountScopedPersistenceTests.swift` · `7c998d8ee` |
| `QuestifyCoreTests/AccountScopedPersistenceTests/testLogoutSameAccountAndEmptyNamespaceDoNotWipe` | Added (new file) | `Tests/CoreTests/AccountScopedPersistenceTests.swift` · `7c998d8ee` |
| `QuestifyCoreTests/AccountScopedPersistenceTests/testRecordContinuationRefreshesSchema2AndDoesNotDelete` | Added (new file) | `Tests/CoreTests/AccountScopedPersistenceTests.swift` · `7c998d8ee` |
| `QuestifyCoreTests/AccountScopedPersistenceTests/testSchemaVersionsAndReaderKeys` | Added (new file) | `Tests/CoreTests/AccountScopedPersistenceTests.swift` · `7c998d8ee` |
| `QuestifyCoreTests/ActivityDetailPageReadyTests/testCapabilityStaysOnTheLiveReadAndKeepsWritesHidden` | Added (new file) | `Tests/CoreTests/ActivityDetailPageReadyTests.swift` · `8f061385e`, `88b42020f`, `773af19aa` |
| `QuestifyCoreTests/ActivityDetailPageReadyTests/testClubGateHidesTheActivityBody` | Added (new file) | `Tests/CoreTests/ActivityDetailPageReadyTests.swift` · `8f061385e`, `88b42020f`, `773af19aa` |
| `QuestifyCoreTests/ActivityDetailPageReadyTests/testDateOnlyActivityStaysReadyWithUnknownCounts` | Added (new file) | `Tests/CoreTests/ActivityDetailPageReadyTests.swift` · `8f061385e`, `88b42020f`, `773af19aa` |
| `QuestifyCoreTests/ActivityDetailPageReadyTests/testEmptyShellAndBlankTitle` | Added (new file) | `Tests/CoreTests/ActivityDetailPageReadyTests.swift` · `8f061385e`, `88b42020f`, `773af19aa` |
| `QuestifyCoreTests/ActivityDetailPageReadyTests/testExplicitZeroStaysZero` | Added (new file) | `Tests/CoreTests/ActivityDetailPageReadyTests.swift` · `8f061385e`, `88b42020f`, `773af19aa` |
| `QuestifyCoreTests/ActivityDetailPageReadyTests/testLoadingAndFailureDoNotInventCounts` | Added (new file) | `Tests/CoreTests/ActivityDetailPageReadyTests.swift` · `8f061385e`, `88b42020f`, `773af19aa` |
| `QuestifyCoreTests/ActivityDetailPageReadyTests/testReadyFixtureKeepsKnownNumbers` | Added (new file) | `Tests/CoreTests/ActivityDetailPageReadyTests.swift` · `8f061385e`, `88b42020f`, `773af19aa` |
| `QuestifyCoreTests/ActivityDetailPageReadyTests/testUnknownFixtureIsAnEmDashAndNotZero` | Added (new file) | `Tests/CoreTests/ActivityDetailPageReadyTests.swift` · `8f061385e`, `88b42020f`, `773af19aa` |
| `QuestifyCoreTests/ActivityHostCancelRulesTests/testUnknownPaidPlayerCountIsAnEmDash` | Added (existing file) | `Tests/CoreTests/ActivityHostCancelTests.swift` · `773af19aa` |
| `QuestifyCoreTests/ActivityPublishingPageReadinessTests/testCapabilityUsesLiveReadsAndKeepsMissingCreateRequestsHidden` | Added (new file) | `Tests/CoreTests/ActivityPublishingPageReadinessTests.swift` · `2ea1db2c8`, `66344a1cd` |
| `QuestifyCoreTests/ActivityPublishingPageReadinessTests/testCountKeepsZeroAndRendersUnknownAsEmDash` | Added (new file) | `Tests/CoreTests/ActivityPublishingPageReadinessTests.swift` · `2ea1db2c8`, `66344a1cd` |
| `QuestifyCoreTests/ActivityPublishingPageReadinessTests/testOptionPhasesAreLoadingEmptyErrorAndReady` | Added (new file) | `Tests/CoreTests/ActivityPublishingPageReadinessTests.swift` · `2ea1db2c8`, `66344a1cd` |
| `QuestifyCoreTests/ActivityPublishingPageReadinessTests/testSnapshotPrefersUnknownThenLoadingThenErrorThenEmpty` | Added (new file) | `Tests/CoreTests/ActivityPublishingPageReadinessTests.swift` · `2ea1db2c8`, `66344a1cd` |
| `QuestifyCoreTests/ActivityPublishingPageReadinessTests/testUnknownFollowIsEmDashAndZeroFollowStaysZero` | Added (new file) | `Tests/CoreTests/ActivityPublishingPageReadinessTests.swift` · `2ea1db2c8`, `66344a1cd` |
| `QuestifyCoreTests/ActivityRegistrationParityW206Tests/testBaomingCoordinatorProjectsTheExistingQuoteAndDoesNotCreateOrPay` | Added (existing file) | `Tests/CoreTests/ActivityRegistrationParityW206Tests.swift` · `ce5e28999`, `773af19aa` |
| `QuestifyCoreTests/ActivityRegistrationParityW206Tests/testBaomingPagePhasesHideAmountsUntilAKnownQuote` | Added (existing file) | `Tests/CoreTests/ActivityRegistrationParityW206Tests.swift` · `ce5e28999`, `773af19aa` |
| `QuestifyCoreTests/ActivityRegistrationParityW206Tests/testBaomingUnknownMoneyIsEmDashAndLiteralZeroStaysZero` | Added (existing file) | `Tests/CoreTests/ActivityRegistrationParityW206Tests.swift` · `ce5e28999`, `773af19aa` |
| `QuestifyCoreTests/AssetCenterAnalysisPageModelTests/testFixturePagesUseTheExistingIncomeListAndDoNotInventZero` | Added (new file) | `Tests/CoreTests/AssetCenterAnalysisPageModelTests.swift` · `83d1e5122` |
| `QuestifyCoreTests/AssetCenterAnalysisPageModelTests/testKnownZeroStaysZeroAndAMissingAmountDoesNot` | Added (new file) | `Tests/CoreTests/AssetCenterAnalysisPageModelTests.swift` · `83d1e5122` |
| `QuestifyCoreTests/AssetCenterAnalysisPageModelTests/testLoadingEmptyErrorAndUnknownMoneyStayAnEmDash` | Added (new file) | `Tests/CoreTests/AssetCenterAnalysisPageModelTests.swift` · `83d1e5122` |
| `QuestifyCoreTests/BNDContractsDecodingTests/testFulfilledMerchantsAndAFoundReceiptDoNotProveAbsence` | Added (existing file) | `Tests/CoreTests/BNDContractsDecodingTests.swift` · `776df1ac7` |
| `QuestifyCoreTests/BNDContractsDecodingTests/testStatusCatalogsKeepUnknownReservationAndCancelText` | Added (existing file) | `Tests/CoreTests/BNDContractsDecodingTests.swift` · `776df1ac7` |
| `QuestifyCoreTests/BNDContractsDecodingTests/testTimestampFailsClosedAndKeepsAnUnparsedRaw` | Added (existing file) | `Tests/CoreTests/BNDContractsDecodingTests.swift` · `776df1ac7` |
| `QuestifyCoreTests/BNDRefundProgressModelTests/testApplyCarriesServerQuoteRouteAndAmountVerbatim` | Added (new file) | `Tests/CoreTests/BNDRefundProgressModelTests.swift` · `4dfde0b58` |
| `QuestifyCoreTests/BNDRefundProgressModelTests/testClosedGateDoesNotSendEvenWhenWriteClosureIsTrue` | Added (new file) | `Tests/CoreTests/BNDRefundProgressModelTests.swift` · `4dfde0b58` |
| `QuestifyCoreTests/BNDRefundProgressModelTests/testNoClientSideAmountComputation` | Added (new file) | `Tests/CoreTests/BNDRefundProgressModelTests.swift` · `4dfde0b58` |
| `QuestifyCoreTests/BNDRefundProgressModelTests/testPartialUnitSelectionRejected` | Added (new file) | `Tests/CoreTests/BNDRefundProgressModelTests.swift` · `4dfde0b58` |
| `QuestifyCoreTests/BNDRefundProgressModelTests/testProcessingUnknownAndManualPayoutAreNotRefunded` | Added (new file) | `Tests/CoreTests/BNDRefundProgressModelTests.swift` · `4dfde0b58` |
| `QuestifyCoreTests/BNDRefundProgressModelTests/testProgressReadDoesNotTreatProcessingAsRefunded` | Added (new file) | `Tests/CoreTests/BNDRefundProgressModelTests.swift` · `4dfde0b58` |
| `QuestifyCoreTests/BNDRefundProgressModelTests/testUnavailableClientDoesNotApply` | Added (new file) | `Tests/CoreTests/BNDRefundProgressModelTests.swift` · `4dfde0b58` |
| `QuestifyCoreTests/BackendErrorCatalogTests/testKnownCodeMessageAndStatus` | Added (new file) | `Tests/CoreTests/BackendErrorCatalogTests.swift` · `6349d4e22`, `e466e6e63` |
| `QuestifyCoreTests/BackendErrorCatalogTests/testMissingConfigurationThrowsBeforeAnyRequest` | Added (new file) | `Tests/CoreTests/BackendErrorCatalogTests.swift` · `6349d4e22`, `e466e6e63` |
| `QuestifyCoreTests/BackendErrorCatalogTests/testUnknownCodeStaysGenericAndHidesServerText` | Added (new file) | `Tests/CoreTests/BackendErrorCatalogTests.swift` · `6349d4e22`, `e466e6e63` |
| `QuestifyCoreTests/CB51LocalDiagnosticsTests/testEmptyEnvironmentIsOffAndDropsTheSecret` | Added (new file) | `Tests/CoreTests/CB51LocalDiagnosticsTests.swift` · `d06b6df4c` |
| `QuestifyCoreTests/CB51LocalDiagnosticsTests/testFlagOnRecordsStaticNameAndCountOnly` | Added (new file) | `Tests/CoreTests/CB51LocalDiagnosticsTests.swift` · `d06b6df4c` |
| `QuestifyCoreTests/CB51LocalDiagnosticsTests/testNegativeMetricCountIsDroppedWithTheSecret` | Added (new file) | `Tests/CoreTests/CB51LocalDiagnosticsTests.swift` · `d06b6df4c` |
| `QuestifyCoreTests/CB51LocalDiagnosticsTests/testOtherFlagValuesStayOff` | Added (new file) | `Tests/CoreTests/CB51LocalDiagnosticsTests.swift` · `d06b6df4c` |
| `QuestifyCoreTests/CB51LocalDiagnosticsTests/testRecordedFieldsAreNameAndCount` | Added (new file) | `Tests/CoreTests/CB51LocalDiagnosticsTests.swift` · `d06b6df4c` |
| `QuestifyCoreTests/CB93RouteAdaptationTests/testAdaptedRoutesAreTheLiveChinaPathsOnly` | Added (new file) | `Tests/CoreTests/CB93RouteAdaptationTests.swift` · `2ea1db2c8`, `8f061385e`, `3c36389ad`, `c50b449dd`, `cf2884760` (+3 more) |
| `QuestifyCoreTests/CB93RouteAdaptationTests/testChinaTransportRewritesOnlyMatchingBodies` | Added (new file) | `Tests/CoreTests/CB93RouteAdaptationTests.swift` · `2ea1db2c8`, `8f061385e`, `3c36389ad`, `c50b449dd`, `cf2884760` (+3 more) |
| `QuestifyCoreTests/CB93RouteAdaptationTests/testClubJoinAndLeaveUseProductionRoutesOnlyOnTheChinaHost` | Added (new file) | `Tests/CoreTests/CB93RouteAdaptationTests.swift` · `2ea1db2c8`, `8f061385e`, `3c36389ad`, `c50b449dd`, `cf2884760` (+3 more) |
| `QuestifyCoreTests/CB93RouteAdaptationTests/testEmptyURLAndHiddenCapabilitiesAreNotAdapted` | Added (new file) | `Tests/CoreTests/CB93RouteAdaptationTests.swift` · `2ea1db2c8`, `8f061385e`, `3c36389ad`, `c50b449dd`, `cf2884760` (+3 more) |
| `QuestifyCoreTests/CB93RouteAdaptationTests/testMismatchedAndHiddenChinaRequestsDoNotLeave` | Added (new file) | `Tests/CoreTests/CB93RouteAdaptationTests.swift` · `2ea1db2c8`, `8f061385e`, `3c36389ad`, `c50b449dd`, `cf2884760` (+3 more) |
| `QuestifyCoreTests/ChannelsContractAppSideTests/testChannelsSocialGrantAdmitsSocialRoutesAndNeverMoney` | Added (new file) | `Tests/CoreTests/ChannelsContractAppSideTests.swift` · `3c36389ad`, `689134de7` |
| `QuestifyCoreTests/ChannelsContractAppSideTests/testFilePickerCapIsTenMegabytes` | Added (new file) | `Tests/CoreTests/ChannelsContractAppSideTests.swift` · `3c36389ad`, `689134de7` |
| `QuestifyCoreTests/ChannelsContractAppSideTests/testFlexibleFlagAcceptsBooleanAndZeroOneOnly` | Added (new file) | `Tests/CoreTests/ChannelsContractAppSideTests.swift` · `3c36389ad`, `689134de7` |
| `QuestifyCoreTests/ChannelsContractAppSideTests/testFriendPageDecodesIntegerHasMore` | Added (new file) | `Tests/CoreTests/ChannelsContractAppSideTests.swift` · `3c36389ad`, `689134de7` |
| `QuestifyCoreTests/ChannelsContractAppSideTests/testProgressScopeShowsFriendAggregateAsSelf` | Added (new file) | `Tests/CoreTests/ChannelsContractAppSideTests.swift` · `3c36389ad`, `689134de7` |
| `QuestifyCoreTests/ChannelsContractAppSideTests/testTeamPoolDefiniteRejectionNeedsMatchingStatus` | Added (new file) | `Tests/CoreTests/ChannelsContractAppSideTests.swift` · `3c36389ad`, `689134de7` |
| `QuestifyCoreTests/ChannelsContractAppSideTests/testTeamPoolHintDecodesAndRendersTheServerHint` | Added (new file) | `Tests/CoreTests/ChannelsContractAppSideTests.swift` · `3c36389ad`, `689134de7` |
| `QuestifyCoreTests/ChannelsContractAppSideTests/testVideoReceiptWithoutCoverDecodesAndBecomesReady` | Added (new file) | `Tests/CoreTests/ChannelsContractAppSideTests.swift` · `3c36389ad`, `689134de7` |
| `QuestifyCoreTests/ChannelsContractAppSideTests/testVideoReferenceStillRejectsHalfACoverAndBadDurations` | Added (new file) | `Tests/CoreTests/ChannelsContractAppSideTests.swift` · `3c36389ad`, `689134de7` |
| `QuestifyCoreTests/ChannelsContractAppSideTests/testVoiceReceiptUsesTheRecordedClipAndIgnoresASR` | Added (new file) | `Tests/CoreTests/ChannelsContractAppSideTests.swift` · `3c36389ad`, `689134de7` |
| `QuestifyCoreTests/CharacterCardPageReadTests/testBlankPhasesAndWireStatsNeverTurnUnknownIntoZero` | Added (new file) | `Tests/CoreTests/CharacterCardPageReadTests.swift` · `b8a6b8bb1` |
| `QuestifyCoreTests/CharacterCardPageReadTests/testEmptyErrorAndUnknownStayDistinctFromALiteralZero` | Added (new file) | `Tests/CoreTests/CharacterCardPageReadTests.swift` · `b8a6b8bb1` |
| `QuestifyCoreTests/CharacterCardPageReadTests/testLiteralZeroStaysZeroAndStatusSheetDoesNotInventARoute` | Added (new file) | `Tests/CoreTests/CharacterCardPageReadTests.swift` · `b8a6b8bb1` |
| `QuestifyCoreTests/CheinDeepLinkTests/testReferralGiftAndSeatLandingsCarryTheTokenAndDoNotClaim` | Added (new file) | `Tests/CoreTests/CheinDeepLinkTests.swift` · `ba7cb6e0c`, `7b4efc671` |
| `QuestifyCoreTests/CheinDeepLinkTests/testRejectsEverythingElse` | Added (new file) | `Tests/CoreTests/CheinDeepLinkTests.swift` · `ba7cb6e0c`, `7b4efc671` |
| `QuestifyCoreTests/CheinDeepLinkTests/testThreeSupportedLinksResolveToTheirOwningTab` | Added (new file) | `Tests/CoreTests/CheinDeepLinkTests.swift` · `ba7cb6e0c`, `7b4efc671` |
| `QuestifyCoreTests/ChinaReviewedRouteCapabilityTests/testEveryCallSiteHasOneMark` | Added (new file) | `Tests/CoreTests/ChinaReviewedRouteCapabilityTests.swift` · `2ea1db2c8`, `8f061385e`, `c50b449dd`, `50d3ac23e`, `969ea25ca` (+3 more) |
| `QuestifyCoreTests/ChinaReviewedRouteCapabilityTests/testHiddenRoutesAreNotOfferedOnChinaOrWithoutAHost` | Added (new file) | `Tests/CoreTests/ChinaReviewedRouteCapabilityTests.swift` · `2ea1db2c8`, `8f061385e`, `c50b449dd`, `50d3ac23e`, `969ea25ca` (+3 more) |
| `QuestifyCoreTests/ChinaReviewedRouteCapabilityTests/testLiveRoutesAndPrefixChildrenAreAdmitted` | Added (new file) | `Tests/CoreTests/ChinaReviewedRouteCapabilityTests.swift` · `2ea1db2c8`, `8f061385e`, `c50b449dd`, `50d3ac23e`, `969ea25ca` (+3 more) |
| `QuestifyCoreTests/ChinaReviewedRouteCapabilityTests/testMissingAndNewBackendRoutesStayDark` | Added (new file) | `Tests/CoreTests/ChinaReviewedRouteCapabilityTests.swift` · `2ea1db2c8`, `8f061385e`, `c50b449dd`, `50d3ac23e`, `969ea25ca` (+3 more) |
| `QuestifyCoreTests/ChinaReviewedRouteCapabilityTests/testOnlyTheChinaProductionHostIsGated` | Added (new file) | `Tests/CoreTests/ChinaReviewedRouteCapabilityTests.swift` · `2ea1db2c8`, `8f061385e`, `c50b449dd`, `50d3ac23e`, `969ea25ca` (+3 more) |
| `QuestifyCoreTests/ChinaReviewedRouteCapabilityTests/testPasswordBankAndVirtualGoodsStayHiddenByCapability` | Added (new file) | `Tests/CoreTests/ChinaReviewedRouteCapabilityTests.swift` · `2ea1db2c8`, `8f061385e`, `c50b449dd`, `50d3ac23e`, `969ea25ca` (+3 more) |
| `QuestifyCoreTests/CityGameCoordinatorTests/testCapabilityIsOffByDefault` | Added (existing file) | `Tests/CoreTests/CityGameCoordinatorTests.swift` · `8e8fa748a` |
| `QuestifyCoreTests/CityGameHTTPServiceTests/testActionRouteSendsTheCanonicalBodyAndDecodesTheServerFace` | Added (new file) | `Tests/CoreTests/CityGameHTTPServiceTests.swift` · `cf2884760`, `ee10e465f`, `8e8fa748a` |
| `QuestifyCoreTests/CityGameHTTPServiceTests/testCoordinatorRecoversALostRollThroughTheReceiptRoute` | Added (new file) | `Tests/CoreTests/CityGameHTTPServiceTests.swift` · `cf2884760`, `ee10e465f`, `8e8fa748a` |
| `QuestifyCoreTests/CityGameHTTPServiceTests/testDeltasRouteSendsTheCursor` | Added (new file) | `Tests/CoreTests/CityGameHTTPServiceTests.swift` · `cf2884760`, `ee10e465f`, `8e8fa748a` |
| `QuestifyCoreTests/CityGameHTTPServiceTests/testLeaseNeedsItsHostAndARegion` | Added (new file) | `Tests/CoreTests/CityGameHTTPServiceTests.swift` · `cf2884760`, `ee10e465f`, `8e8fa748a` |
| `QuestifyCoreTests/CityGameHTTPServiceTests/testOneLifecycleActionsOnlyWhenOpenReadsWhenOpenOrFrozen` | Added (new file) | `Tests/CoreTests/CityGameHTTPServiceTests.swift` · `cf2884760`, `ee10e465f`, `8e8fa748a` |
| `QuestifyCoreTests/CityGameHTTPServiceTests/testQuoteRoutePostsIdsOnly` | Added (new file) | `Tests/CoreTests/CityGameHTTPServiceTests.swift` · `cf2884760`, `ee10e465f`, `8e8fa748a` |
| `QuestifyCoreTests/CityGameHTTPServiceTests/testReceiptRejectsChargesAndFacesThatDoNotFit` | Added (new file) | `Tests/CoreTests/CityGameHTTPServiceTests.swift` · `cf2884760`, `ee10e465f`, `8e8fa748a` |
| `QuestifyCoreTests/CityGameHTTPServiceTests/testReceiptRouteAndUnknownReceipt` | Added (new file) | `Tests/CoreTests/CityGameHTTPServiceTests.swift` · `cf2884760`, `ee10e465f`, `8e8fa748a` |
| `QuestifyCoreTests/CityGameHTTPServiceTests/testSnapshotRouteDecodesTheTeamBlock` | Added (new file) | `Tests/CoreTests/CityGameHTTPServiceTests.swift` · `cf2884760`, `ee10e465f`, `8e8fa748a` |
| `QuestifyCoreTests/CityGameHTTPServiceTests/testTeamBlockGatesOccupyOnLanding` | Added (new file) | `Tests/CoreTests/CityGameHTTPServiceTests.swift` · `cf2884760`, `ee10e465f`, `8e8fa748a` |
| `QuestifyCoreTests/CityGameHTTPServiceTests/testUnauthorizedStaleAndChangedAnswers` | Added (new file) | `Tests/CoreTests/CityGameHTTPServiceTests.swift` · `cf2884760`, `ee10e465f`, `8e8fa748a` |
| `QuestifyCoreTests/CloudL5IMSquareTests/testCardKindsAndSystemTargets` | Added (new file) | `Tests/CoreTests/CloudL5IMSquareTests.swift` · `50d3ac23e`, `2866bade1`, `908ad33e7` |
| `QuestifyCoreTests/CloudL5IMSquareTests/testCommunityWritesUseV1IncludingPatchAndDeleteAndKeepTheRequestId` | Added (new file) | `Tests/CoreTests/CloudL5IMSquareTests.swift` · `50d3ac23e`, `2866bade1`, `908ad33e7` |
| `QuestifyCoreTests/CloudL5IMSquareTests/testFailedSendDoesNotResendUntilReceiptSaysMissing` | Added (new file) | `Tests/CoreTests/CloudL5IMSquareTests.swift` · `50d3ac23e`, `2866bade1`, `908ad33e7` |
| `QuestifyCoreTests/CloudL5IMSquareTests/testFeedPagesAndDraftRecovery` | Added (new file) | `Tests/CoreTests/CloudL5IMSquareTests.swift` · `50d3ac23e`, `2866bade1`, `908ad33e7` |
| `QuestifyCoreTests/CloudL5IMSquareTests/testFoundReceiptMergesAndNeverSends` | Added (new file) | `Tests/CoreTests/CloudL5IMSquareTests.swift` · `50d3ac23e`, `2866bade1`, `908ad33e7` |
| `QuestifyCoreTests/CloudL5IMSquareTests/testLedgerKeepsOnlyIdsAndRetiresStaleHandles` | Added (new file) | `Tests/CoreTests/CloudL5IMSquareTests.swift` · `50d3ac23e`, `2866bade1`, `908ad33e7` |
| `QuestifyCoreTests/CloudL5IMSquareTests/testMergeReplacesSameClientAndSenderButHistoryDoesNot` | Added (new file) | `Tests/CoreTests/CloudL5IMSquareTests.swift` · `50d3ac23e`, `2866bade1`, `908ad33e7` |
| `QuestifyCoreTests/CloudL5IMSquareTests/testReceiptReadsAreSharedAndAMissIsNotSilentForRetry` | Added (new file) | `Tests/CoreTests/CloudL5IMSquareTests.swift` · `50d3ac23e`, `2866bade1`, `908ad33e7` |
| `QuestifyCoreTests/CloudL5IMSquareTests/testRefreshPillOnlyOnSilentReloadOfALoadedList` | Added (new file) | `Tests/CoreTests/CloudL5IMSquareTests.swift` · `50d3ac23e`, `2866bade1`, `908ad33e7` |
| `QuestifyCoreTests/CloudL5IMSquareTests/testReportNoticesKeepTheNewestReportAndMarkReadWithAStableKey` | Added (new file) | `Tests/CoreTests/CloudL5IMSquareTests.swift` · `50d3ac23e`, `2866bade1`, `908ad33e7` |
| `QuestifyCoreTests/CloudL5IMSquareTests/testShareFollowDraftsActivityAndRouteMap` | Added (new file) | `Tests/CoreTests/CloudL5IMSquareTests.swift` · `50d3ac23e`, `2866bade1`, `908ad33e7` |
| `QuestifyCoreTests/CloudL5IMSquareTests/testStaleReceiptCannotSendOrMerge` | Added (new file) | `Tests/CoreTests/CloudL5IMSquareTests.swift` · `50d3ac23e`, `2866bade1`, `908ad33e7` |
| `QuestifyCoreTests/CloudX1AuditBugTests/testCityNodeCodeFromTheWrongPlaceSaysWhereToRedeem` | Added (new file) | `Tests/CoreTests/CloudX1AuditBugTests.swift` · `50d3ac23e`, `6763bb660` |
| `QuestifyCoreTests/CloudX1AuditBugTests/testClosingTheAdvancedPanelClosesThePlayKitSheet` | Added (new file) | `Tests/CoreTests/CloudX1AuditBugTests.swift` · `50d3ac23e`, `6763bb660` |
| `QuestifyCoreTests/CloudX1AuditBugTests/testClubRolePickerUpdatesTheDraft` | Added (new file) | `Tests/CoreTests/CloudX1AuditBugTests.swift` · `50d3ac23e`, `6763bb660` |
| `QuestifyCoreTests/CloudX1AuditBugTests/testCountdownFallbackTTLIs300Seconds` | Added (new file) | `Tests/CoreTests/CloudX1AuditBugTests.swift` · `50d3ac23e`, `6763bb660` |
| `QuestifyCoreTests/CloudX1AuditBugTests/testCreateResponseDataIsAScalarTopicId` | Added (new file) | `Tests/CoreTests/CloudX1AuditBugTests.swift` · `50d3ac23e`, `6763bb660` |
| `QuestifyCoreTests/CloudX1AuditBugTests/testDisabledCallToActionExplainsWhy` | Added (new file) | `Tests/CoreTests/CloudX1AuditBugTests.swift` · `50d3ac23e`, `6763bb660` |
| `QuestifyCoreTests/CloudX1AuditBugTests/testLeaderboardFetchFailureIsAnErrorNotEmpty` | Added (new file) | `Tests/CoreTests/CloudX1AuditBugTests.swift` · `50d3ac23e`, `6763bb660` |
| `QuestifyCoreTests/CloudX1AuditBugTests/testMode2ShopVisitCompletesOnlyFromMerchantRedemption` | Added (new file) | `Tests/CoreTests/CloudX1AuditBugTests.swift` · `50d3ac23e`, `6763bb660` |
| `QuestifyCoreTests/CloudX1AuditBugTests/testNullRemainingInventoryIsUnknownNotSoldOut` | Added (new file) | `Tests/CoreTests/CloudX1AuditBugTests.swift` · `50d3ac23e`, `6763bb660` |
| `QuestifyCoreTests/CloudX1AuditBugTests/testReactionBallShakeAndQuietHoldRequireStartBeforeSubmit` | Added (new file) | `Tests/CoreTests/CloudX1AuditBugTests.swift` · `50d3ac23e`, `6763bb660` |
| `QuestifyCoreTests/CloudX1AuditBugTests/testRegistrationFormRechecksSignupDeadline` | Added (new file) | `Tests/CoreTests/CloudX1AuditBugTests.swift` · `50d3ac23e`, `6763bb660` |
| `QuestifyCoreTests/CloudX1AuditBugTests/testResumeDraftAtTheSavedStep` | Added (new file) | `Tests/CoreTests/CloudX1AuditBugTests.swift` · `50d3ac23e`, `6763bb660` |
| `QuestifyCoreTests/CloudX1AuditBugTests/testSilentOrderGiveUpActsWithoutACompletionAction` | Added (new file) | `Tests/CoreTests/CloudX1AuditBugTests.swift` · `50d3ac23e`, `6763bb660` |
| `QuestifyCoreTests/CloudX1AuditBugTests/testTopicOrderCarriesSourceClubId` | Added (new file) | `Tests/CoreTests/CloudX1AuditBugTests.swift` · `50d3ac23e`, `6763bb660` |
| `QuestifyCoreTests/CloudX1AuditBugTests/testUnknownPaymentStateExplainsItself` | Added (new file) | `Tests/CoreTests/CloudX1AuditBugTests.swift` · `50d3ac23e`, `6763bb660` |
| `QuestifyCoreTests/ClubBadgePageReadyTests/testDebugFixtureDataHasNoNetworkAndUnknownIsEmDash` | Added (new file) | `Tests/CoreTests/ClubBadgePageReadyTests.swift` · `2ea1db2c8`, `21a2705bb`, `4f180d862` |
| `QuestifyCoreTests/ClubBadgePageReadyTests/testLiteralZeroStaysZeroAndMissingOrUnknownStaysEmDash` | Added (new file) | `Tests/CoreTests/ClubBadgePageReadyTests.swift` · `2ea1db2c8`, `21a2705bb`, `4f180d862` |
| `QuestifyCoreTests/ClubBadgePageReadyTests/testLiveBadgeRoutesStayWiredAndReceiptStaysHidden` | Added (new file) | `Tests/CoreTests/ClubBadgePageReadyTests.swift` · `2ea1db2c8`, `21a2705bb`, `4f180d862` |
| `QuestifyCoreTests/ClubBadgePageReadyTests/testLoadingAndErrorCountsAreEmDashWhileEmptyIsZero` | Added (new file) | `Tests/CoreTests/ClubBadgePageReadyTests.swift` · `2ea1db2c8`, `21a2705bb`, `4f180d862` |
| `QuestifyCoreTests/ClubBadgePageReadyTests/testMemberPickerEmptyIsZeroAndFailureIsEmDash` | Added (new file) | `Tests/CoreTests/ClubBadgePageReadyTests.swift` · `2ea1db2c8`, `21a2705bb`, `4f180d862` |
| `QuestifyCoreTests/ClubBadgePageReadyTests/testPlayerFirstLaunchDoesNotSurfaceBadgeManagement` | Added (new file) | `Tests/CoreTests/ClubBadgePageReadyTests.swift` · `2ea1db2c8`, `21a2705bb`, `4f180d862` |
| `QuestifyCoreTests/ClubBadgePageReadyTests/testStringCatalogHasBothLanguagesAndPageIdentifiers` | Added (new file) | `Tests/CoreTests/ClubBadgePageReadyTests.swift` · `2ea1db2c8`, `21a2705bb`, `4f180d862` |
| `QuestifyCoreTests/ClubBadgePageReadyTests/testUnconfirmedOriginalResultDoesNotBecomeAZeroBadgeId` | Added (new file) | `Tests/CoreTests/ClubBadgePageReadyTests.swift` · `2ea1db2c8`, `21a2705bb`, `4f180d862` |
| `QuestifyCoreTests/ClubCheckinRailTests/testLiteralZeroStaysZeroAndUnknownNumbersStayEmDash` | Added (existing file) | `Tests/CoreTests/ClubCheckinRailTests.swift` · `50d3ac23e`, `4f180d862` |
| `QuestifyCoreTests/ClubCheckinRailTests/testLoadingEmptyErrorAndUnknownDoNotBecomeZero` | Added (existing file) | `Tests/CoreTests/ClubCheckinRailTests.swift` · `50d3ac23e`, `4f180d862` |
| `QuestifyCoreTests/ClubCheckinRailTests/testMissingCapabilityStaysHiddenAndDoesNotInventARoute` | Added (existing file) | `Tests/CoreTests/ClubCheckinRailTests.swift` · `50d3ac23e`, `4f180d862` |
| `QuestifyCoreTests/ClubCheckinRailTests/testServerCanRefundDoesNotEnableDispatch` | Added (existing file) | `Tests/CoreTests/ClubCheckinRailTests.swift` · `50d3ac23e`, `4f180d862` |
| `QuestifyCoreTests/ClubContractTests/testPendingJoinRequestCountKeepsLiteralZeroAndUnknown` | Added (existing file) | `Tests/CoreTests/ClubContractTests.swift` · `1ebf994ac` |
| `QuestifyCoreTests/ClubCreatePageCoordinatorTests/testCoordinatorProjectsTheGateWithoutSending` | Added (new file) | `Tests/CoreTests/ClubCreatePageModelTests.swift` · `4f180d862` |
| `QuestifyCoreTests/ClubCreatePageCoordinatorTests/testNoFactsStayUnknownInsteadOfZero` | Added (new file) | `Tests/CoreTests/ClubCreatePageModelTests.swift` · `4f180d862` |
| `QuestifyCoreTests/ClubCreatePageFixtureDataTests/testDebugFixtureDataFeedsTheReadModel` | Added (new file) | `Tests/CoreTests/ClubCreatePageModelTests.swift` · `4f180d862` |
| `QuestifyCoreTests/ClubCreatePageModelTests/testCreationStaysGatedAndOffThePlayerFirstEntry` | Added (new file) | `Tests/CoreTests/ClubCreatePageModelTests.swift` · `4f180d862` |
| `QuestifyCoreTests/ClubCreatePageModelTests/testLoadingSignedOutAndFailedReadDoNotGuessACount` | Added (new file) | `Tests/CoreTests/ClubCreatePageModelTests.swift` · `4f180d862` |
| `QuestifyCoreTests/ClubCreatePageModelTests/testOwnedPayloadClassifiesEmptyErrorAndUnknown` | Added (new file) | `Tests/CoreTests/ClubCreatePageModelTests.swift` · `4f180d862` |
| `QuestifyCoreTests/ClubCreatePageModelTests/testReceivedReadbackOutranksAStaleSnapshot` | Added (new file) | `Tests/CoreTests/ClubCreatePageModelTests.swift` · `4f180d862` |
| `QuestifyCoreTests/ClubCreatePageModelTests/testUnknownCountIsAnEmDashAndNeverZero` | Added (new file) | `Tests/CoreTests/ClubCreatePageModelTests.swift` · `4f180d862` |
| `QuestifyCoreTests/ClubCustomersIndexPageReadyTests/testContractStaysTheExistingCustomersListAndOffThePlayerHome` | Added (new file) | `Tests/CoreTests/ClubCustomersIndexPageReadyTests.swift` · `4f180d862` |
| `QuestifyCoreTests/ClubCustomersIndexPageReadyTests/testFixtureDataMatchesTheExistingCustomersBody` | Added (new file) | `Tests/CoreTests/ClubCustomersIndexPageReadyTests.swift` · `4f180d862` |
| `QuestifyCoreTests/ClubCustomersIndexPageReadyTests/testLoadingEmptyErrorAndUnknownStayDistinct` | Added (new file) | `Tests/CoreTests/ClubCustomersIndexPageReadyTests.swift` · `4f180d862` |
| `QuestifyCoreTests/ClubCustomersIndexPageReadyTests/testMalformedRosterIsAnErrorAndKeepsTheExistingFailClosedParser` | Added (new file) | `Tests/CoreTests/ClubCustomersIndexPageReadyTests.swift` · `4f180d862` |
| `QuestifyCoreTests/ClubCustomersIndexPageReadyTests/testMissingDirectoryCapabilityStaysHidden` | Added (new file) | `Tests/CoreTests/ClubCustomersIndexPageReadyTests.swift` · `4f180d862` |
| `QuestifyCoreTests/ClubCustomersIndexPageReadyTests/testStaleClubSnapshotIsNotShown` | Added (new file) | `Tests/CoreTests/ClubCustomersIndexPageReadyTests.swift` · `4f180d862` |
| `QuestifyCoreTests/ClubCustomersIndexPageReadyTests/testStringsFileCarriesEnglishChineseAndIdentifiers` | Added (new file) | `Tests/CoreTests/ClubCustomersIndexPageReadyTests.swift` · `4f180d862` |
| `QuestifyCoreTests/ClubCustomersIndexPageReadyTests/testUnknownCountsNeverBecomeZeroOrTheRowCount` | Added (new file) | `Tests/CoreTests/ClubCustomersIndexPageReadyTests.swift` · `4f180d862` |
| `QuestifyCoreTests/ClubDetailPageReadyTests/testAcceptedPayloadWinsOverTheLoadingFlag` | Added (new file) | `Tests/CoreTests/ClubDetailPageReadyTests.swift` · `8f061385e`, `88b42020f`, `4f180d862` |
| `QuestifyCoreTests/ClubDetailPageReadyTests/testDebugFixtureDataCoversReadyUnknownZeroAndEmpty` | Added (new file) | `Tests/CoreTests/ClubDetailPageReadyTests.swift` · `8f061385e`, `88b42020f`, `4f180d862` |
| `QuestifyCoreTests/ClubDetailPageReadyTests/testKnownFactsAndBlankCityDoNotBorrowAnotherField` | Added (new file) | `Tests/CoreTests/ClubDetailPageReadyTests.swift` · `8f061385e`, `88b42020f`, `4f180d862` |
| `QuestifyCoreTests/ClubDetailPageReadyTests/testLoadingEmptyAndErrorStaySeparate` | Added (new file) | `Tests/CoreTests/ClubDetailPageReadyTests.swift` · `8f061385e`, `88b42020f`, `4f180d862` |
| `QuestifyCoreTests/ClubDetailPageReadyTests/testManagementStaysCapabilityGatedAndMissingChannelsStayHidden` | Added (new file) | `Tests/CoreTests/ClubDetailPageReadyTests.swift` · `8f061385e`, `88b42020f`, `4f180d862` |
| `QuestifyCoreTests/ClubDetailPageReadyTests/testOmittedNumbersStayUnknownAndLiteralZeroStaysZero` | Added (new file) | `Tests/CoreTests/ClubDetailPageReadyTests.swift` · `8f061385e`, `88b42020f`, `4f180d862` |
| `QuestifyCoreTests/ClubDetailPageReadyTests/testPostsEventsAndMoneyFlags` | Added (new file) | `Tests/CoreTests/ClubDetailPageReadyTests.swift` · `8f061385e`, `88b42020f`, `4f180d862` |
| `QuestifyCoreTests/ClubDetailPageReadyTests/testUnknownMarkIsAnEmDashAndNotZero` | Added (new file) | `Tests/CoreTests/ClubDetailPageReadyTests.swift` · `8f061385e`, `88b42020f`, `4f180d862` |
| `QuestifyCoreTests/ClubEditPageTests/testCoordinatorReadbackDoesNotInventANumberFromTheSnapshot` | Added (new file) | `Tests/CoreTests/ClubEditPageTests.swift` · `4f180d862` |
| `QuestifyCoreTests/ClubEditPageTests/testEnvelopeWrongClubAndFailedBody` | Added (new file) | `Tests/CoreTests/ClubEditPageTests.swift` · `4f180d862` |
| `QuestifyCoreTests/ClubEditPageTests/testExplicitZeroStaysZeroAndUnknownQuotaStaysAnEmDash` | Added (new file) | `Tests/CoreTests/ClubEditPageTests.swift` · `4f180d862` |
| `QuestifyCoreTests/ClubEditPageTests/testLoadingEmptyAndErrorUseTheEmDashAndHideActions` | Added (new file) | `Tests/CoreTests/ClubEditPageTests.swift` · `4f180d862` |
| `QuestifyCoreTests/ClubEditPageTests/testMissingGovernanceHidesDissolveAndKeepsOwnerEdit` | Added (new file) | `Tests/CoreTests/ClubEditPageTests.swift` · `4f180d862` |
| `QuestifyCoreTests/ClubEditPageTests/testOwnerAdminAndMemberCapabilitiesStayOnExistingPaths` | Added (new file) | `Tests/CoreTests/ClubEditPageTests.swift` · `4f180d862` |
| `QuestifyCoreTests/ClubEditPageTests/testPlayerFirstEntryHidesEditAndDissolve` | Added (new file) | `Tests/CoreTests/ClubEditPageTests.swift` · `4f180d862` |
| `QuestifyCoreTests/ClubEditPageTests/testUnknownBlockersAreNotCountedAsZero` | Added (new file) | `Tests/CoreTests/ClubEditPageTests.swift` · `4f180d862` |
| `QuestifyCoreTests/ClubEnrollmentTests/testAcceptedEmptyTopicListIsEmptyNotAnError` | Added (existing file) | `Tests/CoreTests/ClubEnrollmentTests.swift` · `4f180d862` |
| `QuestifyCoreTests/ClubEnrollmentTests/testNumericStringAndUnknownTokenStayEmDashWhileLiteralZeroStaysZero` | Added (existing file) | `Tests/CoreTests/ClubEnrollmentTests.swift` · `4f180d862` |
| `QuestifyCoreTests/ClubGapClientTests/testCatalogCoversEveryNamedPath` | Added (new file) | `Tests/CoreTests/ClubGapClientTests.swift` · `4ce602883`, `88b42020f` |
| `QuestifyCoreTests/ClubGapClientTests/testExportStaysUnsentUntilPayoutAndNeverTreatsAnErrorAsSuccess` | Added (new file) | `Tests/CoreTests/ClubGapClientTests.swift` · `4ce602883`, `88b42020f` |
| `QuestifyCoreTests/ClubGapClientTests/testGuestPostSendsAndASignedOutWriteDoesNot` | Added (new file) | `Tests/CoreTests/ClubGapClientTests.swift` · `4ce602883`, `88b42020f` |
| `QuestifyCoreTests/ClubGapClientTests/testMerchantInvitePinsPostWhenTheWriteSwitchIsOn` | Added (new file) | `Tests/CoreTests/ClubGapClientTests.swift` · `4ce602883`, `88b42020f` |
| `QuestifyCoreTests/ClubGapClientTests/testMerchantWriteIsWithheldAndLeadUsesGET` | Added (new file) | `Tests/CoreTests/ClubGapClientTests.swift` · `4ce602883`, `88b42020f` |
| `QuestifyCoreTests/ClubGapClientTests/testRemainingCatalogCallsPinMethodAndPath` | Added (new file) | `Tests/CoreTests/ClubGapClientTests.swift` · `4ce602883`, `88b42020f` |
| `QuestifyCoreTests/ClubGapClientTests/testSuccessRequiresHTTPAndBodyCodeAndUnknownStaysAnEmDash` | Added (new file) | `Tests/CoreTests/ClubGapClientTests.swift` · `4ce602883`, `88b42020f` |
| `QuestifyCoreTests/ClubGroupCodePageReadyTests/testGroupCodeIssueCommandUsesExistingContractAndDoesNotSend` | Added (new file) | `Tests/CoreTests/ClubGroupCodePageReadyTests.swift` · `7dec57c38` |
| `QuestifyCoreTests/ClubGroupCodePageReadyTests/testGroupCodeLoadUsesTopicOverviewAndHidesADeniedGrant` | Added (new file) | `Tests/CoreTests/ClubGroupCodePageReadyTests.swift` · `7dec57c38` |
| `QuestifyCoreTests/ClubGroupCodePageReadyTests/testGroupCodePageLoadingEmptyReadyAndLiteralZero` | Added (new file) | `Tests/CoreTests/ClubGroupCodePageReadyTests.swift` · `7dec57c38` |
| `QuestifyCoreTests/ClubGroupCodePageReadyTests/testGroupCodePageStaysHiddenWithoutCheckInCapability` | Added (new file) | `Tests/CoreTests/ClubGroupCodePageReadyTests.swift` · `7dec57c38` |
| `QuestifyCoreTests/ClubGroupCodePageReadyTests/testGroupCodeUnknownHeadcountIsEmDashNeverZero` | Added (new file) | `Tests/CoreTests/ClubGroupCodePageReadyTests.swift` · `7dec57c38` |
| `QuestifyCoreTests/ClubHostApplyPageModelTests/testExistingHostStatusAndBecomeLeaderContractsAreTheOnlyPaths` | Added (new file) | `Tests/CoreTests/ClubHostApplyPageModelTests.swift` · `88b42020f`, `4f180d862` |
| `QuestifyCoreTests/ClubHostApplyPageModelTests/testIntroMerchantAndDraftCountsDoNotGuess` | Added (new file) | `Tests/CoreTests/ClubHostApplyPageModelTests.swift` · `88b42020f`, `4f180d862` |
| `QuestifyCoreTests/ClubHostApplyPageModelTests/testLoadingEmptyErrorAndUnknownStayDistinct` | Added (new file) | `Tests/CoreTests/ClubHostApplyPageModelTests.swift` · `88b42020f`, `4f180d862` |
| `QuestifyCoreTests/ClubHostApplyPageModelTests/testMissingCapabilityAndPlayerFirstEntryStayHidden` | Added (new file) | `Tests/CoreTests/ClubHostApplyPageModelTests.swift` · `88b42020f`, `4f180d862` |
| `QuestifyCoreTests/ClubHostApplyPageModelTests/testStringCatalogCoversStatesAndBothLocales` | Added (new file) | `Tests/CoreTests/ClubHostApplyPageModelTests.swift` · `88b42020f`, `4f180d862` |
| `QuestifyCoreTests/ClubHostApplyPageModelTests/testUnknownNumbersAreAnEmDashAndExplicitZeroStaysZero` | Added (new file) | `Tests/CoreTests/ClubHostApplyPageModelTests.swift` · `88b42020f`, `4f180d862` |
| `QuestifyCoreTests/ClubNotifyPageTests/testAudienceLoadingEmptyReadyAndLiteralZero` | Added (new file) | `Tests/CoreTests/ClubNotifyPageTests.swift` · `8af8ffb77` |
| `QuestifyCoreTests/ClubNotifyPageTests/testDeliveryUnknownIsEmDashWhileLiteralZeroStaysZero` | Added (new file) | `Tests/CoreTests/ClubNotifyPageTests.swift` · `8af8ffb77` |
| `QuestifyCoreTests/ClubNotifyPageTests/testLoadUsesTheExistingReadsAndDoesNotSend` | Added (new file) | `Tests/CoreTests/ClubNotifyPageTests.swift` · `8af8ffb77` |
| `QuestifyCoreTests/ClubNotifyPageTests/testNotifyPageStaysHiddenWithoutTheBroadcastGrant` | Added (new file) | `Tests/CoreTests/ClubNotifyPageTests.swift` · `8af8ffb77` |
| `QuestifyCoreTests/ClubNotifyPageTests/testUnknownAudienceCountsAreEmDashNeverZero` | Added (new file) | `Tests/CoreTests/ClubNotifyPageTests.swift` · `8af8ffb77` |
| `QuestifyCoreTests/ClubOpsCustomerPresentationTests/testCustomerDetailLoadUsesExistingReadAndHidesADeniedGrant` | Added (existing file) | `Tests/CoreTests/ClubOpsCustomerPresentationTests.swift` · `4f180d862` |
| `QuestifyCoreTests/ClubOpsCustomerPresentationTests/testCustomerDetailPageLoadingEmptyReadyAndLiteralZero` | Added (existing file) | `Tests/CoreTests/ClubOpsCustomerPresentationTests.swift` · `4f180d862` |
| `QuestifyCoreTests/ClubOpsCustomerPresentationTests/testCustomerDetailPageStaysHiddenWithoutDirectoryCapability` | Added (existing file) | `Tests/CoreTests/ClubOpsCustomerPresentationTests.swift` · `4f180d862` |
| `QuestifyCoreTests/ClubOpsCustomerPresentationTests/testCustomerDetailUnknownCountsAreEmDashNeverZero` | Added (existing file) | `Tests/CoreTests/ClubOpsCustomerPresentationTests.swift` · `4f180d862` |
| `QuestifyCoreTests/ClubOpsGovernancePageTests/testGovernanceLoadUsesExistingReadsAndHidesADeniedGrant` | Added (new file) | `Tests/CoreTests/ClubOpsGovernancePageTests.swift` · `50d3ac23e`, `f760f1977` |
| `QuestifyCoreTests/ClubOpsGovernancePageTests/testGovernancePageLoadingEmptyReadyAndLiteralZero` | Added (new file) | `Tests/CoreTests/ClubOpsGovernancePageTests.swift` · `50d3ac23e`, `f760f1977` |
| `QuestifyCoreTests/ClubOpsGovernancePageTests/testGovernancePageStaysHiddenWithoutCapabilityAndOffPlayerEntry` | Added (new file) | `Tests/CoreTests/ClubOpsGovernancePageTests.swift` · `50d3ac23e`, `f760f1977` |
| `QuestifyCoreTests/ClubOpsGovernancePageTests/testGovernanceUnknownCountsAreEmDashNeverZero` | Added (new file) | `Tests/CoreTests/ClubOpsGovernancePageTests.swift` · `50d3ac23e`, `f760f1977` |
| `QuestifyCoreTests/ClubOpsJoinRequestPresentationTests/testJoinRequestPageStaysHiddenAndUnknownIsAnEmDash` | Added (existing file) | `Tests/CoreTests/ClubOpsJoinNotifyTests.swift` · `1ebf994ac` |
| `QuestifyCoreTests/ClubPlayerFlowTests/testAccessWithoutANameCheckDoesNotInventAnAnswer` | Added (new file) | `Tests/CoreTests/ClubPlayerFlowTests.swift` · `50d3ac23e`, `08b38f414` |
| `QuestifyCoreTests/ClubPlayerFlowTests/testApplyStillNeedsNamePhoneAndExperienceOnTheFirstTwoSteps` | Added (new file) | `Tests/CoreTests/ClubPlayerFlowTests.swift` · `50d3ac23e`, `08b38f414` |
| `QuestifyCoreTests/ClubPlayerFlowTests/testChinaNameCheckIsNotAdmittedAndDoesNotSend` | Added (new file) | `Tests/CoreTests/ClubPlayerFlowTests.swift` · `50d3ac23e`, `08b38f414` |
| `QuestifyCoreTests/ClubPlayerFlowTests/testCreateStepsMatchTheFourMiniProgramGates` | Added (new file) | `Tests/CoreTests/ClubPlayerFlowTests.swift` · `50d3ac23e`, `08b38f414` |
| `QuestifyCoreTests/ClubPlayerFlowTests/testJoinMessageIsRequiredOnlyWhenPolicyIsOne` | Added (new file) | `Tests/CoreTests/ClubPlayerFlowTests.swift` · `50d3ac23e`, `08b38f414` |
| `QuestifyCoreTests/ClubPlayerFlowTests/testNameCheckDecode` | Added (new file) | `Tests/CoreTests/ClubPlayerFlowTests.swift` · `50d3ac23e`, `08b38f414` |
| `QuestifyCoreTests/ClubPlayerFlowTests/testNameCheckFailureStaysUnchecked` | Added (new file) | `Tests/CoreTests/ClubPlayerFlowTests.swift` · `50d3ac23e`, `08b38f414` |
| `QuestifyCoreTests/ClubPlayerFlowTests/testOfferedHostPostsTheTrimmedNameAndStopsWhenTaken` | Added (new file) | `Tests/CoreTests/ClubPlayerFlowTests.swift` · `50d3ac23e`, `08b38f414` |
| `QuestifyCoreTests/ClubPlayerFlowTests/testTakenMessageRecognizesChineseAndEnglishServerText` | Added (new file) | `Tests/CoreTests/ClubPlayerFlowTests.swift` · `50d3ac23e`, `08b38f414` |
| `QuestifyCoreTests/ClubPlayerFlowTests/testWizardCopyHasBothLanguages` | Added (new file) | `Tests/CoreTests/ClubPlayerFlowTests.swift` · `50d3ac23e`, `08b38f414` |
| `QuestifyCoreTests/ClubTabPageModelTests/testEmptyListKeepsLiteralZeroAndHidesCreate` | Added (existing file) | `Tests/CoreTests/ClubTabPresentationTests.swift` · `c5150bf32` |
| `QuestifyCoreTests/ClubTabPageModelTests/testMissingCountsStayEmDashAndDoNotDropTheRow` | Added (existing file) | `Tests/CoreTests/ClubTabPresentationTests.swift` · `c5150bf32` |
| `QuestifyCoreTests/ClubTabPageModelTests/testNonObjectLeaderStatusDoesNotUnlockCreate` | Added (existing file) | `Tests/CoreTests/ClubTabPresentationTests.swift` · `c5150bf32` |
| `QuestifyCoreTests/ClubTabPageModelTests/testReadyHomeKeepsLiteralCountsAndExplicitCreate` | Added (existing file) | `Tests/CoreTests/ClubTabPresentationTests.swift` · `c5150bf32` |
| `QuestifyCoreTests/ClubTabPageModelTests/testUnknownMarkIsAnEmDash` | Added (existing file) | `Tests/CoreTests/ClubTabPresentationTests.swift` · `c5150bf32` |
| `QuestifyCoreTests/ClubTabPageModelTests/testUnreadBadgeAndFeedDoNotGuessZero` | Added (existing file) | `Tests/CoreTests/ClubTabPresentationTests.swift` · `c5150bf32` |
| `QuestifyCoreTests/ClubTabPageModelTests/testWithheldFailedAndLoadingStayDistinct` | Added (existing file) | `Tests/CoreTests/ClubTabPresentationTests.swift` · `c5150bf32` |
| `QuestifyCoreTests/ConditionPackageClosureTests/testOWN_D_09_nativeScopeIsMiniProgramMinusWeChatOnlyAndNoFlutter` | Added (new file) | `Tests/CoreTests/ConditionPackageClosureTests.swift` · `e5b3abb4c` |
| `QuestifyCoreTests/ConditionPackageClosureTests/testOWN_EXT_01_noRoleRoomOrHostTransfer` | Added (new file) | `Tests/CoreTests/ConditionPackageClosureTests.swift` · `e5b3abb4c` |
| `QuestifyCoreTests/ConditionPackageClosureTests/testOWN_EXT_02_noOfflineMapTileStore` | Added (new file) | `Tests/CoreTests/ConditionPackageClosureTests.swift` · `e5b3abb4c` |
| `QuestifyCoreTests/ConditionPackageClosureTests/testOWN_EXT_03_noStoredValueOrMemberCard` | Added (new file) | `Tests/CoreTests/ConditionPackageClosureTests.swift` · `e5b3abb4c` |
| `QuestifyCoreTests/ConditionPackageClosureTests/testOWN_EXT_04_singleBuyerGiftKeptAndCrowdfundingAbsent` | Added (new file) | `Tests/CoreTests/ConditionPackageClosureTests.swift` · `e5b3abb4c` |
| `QuestifyCoreTests/ConditionPackageClosureTests/testOWN_EXT_05_signedReferralTokenKeptAndQueryAttributionRefused` | Added (new file) | `Tests/CoreTests/ConditionPackageClosureTests.swift` · `e5b3abb4c` |
| `QuestifyCoreTests/ConditionPackageClosureTests/testOWN_EXT_06_passLibraryPricingAndRevenueKeptAndDerivativeLicensingAbsent` | Added (new file) | `Tests/CoreTests/ConditionPackageClosureTests.swift` · `e5b3abb4c` |
| `QuestifyCoreTests/ConditionPackageClosureTests/testOWN_EXT_08_noEmbeddedScriptEngine` | Added (new file) | `Tests/CoreTests/ConditionPackageClosureTests.swift` · `e5b3abb4c` |
| `QuestifyCoreTests/ConditionPackageClosureTests/testOWN_EXT_09_noPointExpiry` | Added (new file) | `Tests/CoreTests/ConditionPackageClosureTests.swift` · `e5b3abb4c` |
| `QuestifyCoreTests/ConditionPackageClosureTests/testOWN_EXT_11_noExternalAPIClientOrCRDT` | Added (new file) | `Tests/CoreTests/ConditionPackageClosureTests.swift` · `e5b3abb4c` |
| `QuestifyCoreTests/ContentContractV1Tests/testAccusationVectors` | Added (new file) | `Tests/CoreTests/ContentContractV1Tests.swift` · `1e48434aa`, `4ecbb385e` |
| `QuestifyCoreTests/ContentContractV1Tests/testCapabilityVectorsUseTheDeclarationDecoder` | Added (new file) | `Tests/CoreTests/ContentContractV1Tests.swift` · `1e48434aa`, `4ecbb385e` |
| `QuestifyCoreTests/ContentContractV1Tests/testHangmanVectors` | Added (new file) | `Tests/CoreTests/ContentContractV1Tests.swift` · `1e48434aa`, `4ecbb385e` |
| `QuestifyCoreTests/ContentContractV1Tests/testHintPolicyAndSkipVectors` | Added (new file) | `Tests/CoreTests/ContentContractV1Tests.swift` · `1e48434aa`, `4ecbb385e` |
| `QuestifyCoreTests/ContentContractV1Tests/testOfficialVectorFileMatchesTheSchemaIdentity` | Added (new file) | `Tests/CoreTests/ContentContractV1Tests.swift` · `1e48434aa`, `4ecbb385e` |
| `QuestifyCoreTests/ContentContractV1Tests/testOutcomeRulesPassFailFeedbackRoundTrips` | Added (new file) | `Tests/CoreTests/ContentContractV1Tests.swift` · `1e48434aa`, `4ecbb385e` |
| `QuestifyCoreTests/ContentContractV1Tests/testPublicProjectionVectors` | Added (new file) | `Tests/CoreTests/ContentContractV1Tests.swift` · `1e48434aa`, `4ecbb385e` |
| `QuestifyCoreTests/ContentContractV1Tests/testRequestIdempotencyVectorSeparatesFactKeyFromFingerprint` | Added (new file) | `Tests/CoreTests/ContentContractV1Tests.swift` · `1e48434aa`, `4ecbb385e` |
| `QuestifyCoreTests/ContentContractV1Tests/testRunQuotaAndFreezeUseTheExistingReader` | Added (new file) | `Tests/CoreTests/ContentContractV1Tests.swift` · `1e48434aa`, `4ecbb385e` |
| `QuestifyCoreTests/ContentContractV1Tests/testSaveVectors` | Added (new file) | `Tests/CoreTests/ContentContractV1Tests.swift` · `1e48434aa`, `4ecbb385e` |
| `QuestifyCoreTests/ContentContractV1Tests/testSectionVectors` | Added (new file) | `Tests/CoreTests/ContentContractV1Tests.swift` · `1e48434aa`, `4ecbb385e` |
| `QuestifyCoreTests/CoopInviteIndexReadinessTests/testClosedAndUnknownWindowsCannotInviteAndSendStaysHidden` | Added (new file) | `Tests/CoreTests/CoopInviteIndexReadinessTests.swift` · `f67e8ab15` |
| `QuestifyCoreTests/CoopInviteIndexReadinessTests/testClubMemberCountZeroStaysZeroAndUnknownStaysEmDash` | Added (new file) | `Tests/CoreTests/CoopInviteIndexReadinessTests.swift` · `f67e8ab15` |
| `QuestifyCoreTests/CoopInviteIndexReadinessTests/testDirectoryPhasesAreLoadingEmptyErrorUnknownAndReady` | Added (new file) | `Tests/CoreTests/CoopInviteIndexReadinessTests.swift` · `f67e8ab15` |
| `QuestifyCoreTests/CoopInviteIndexReadinessTests/testMerchantMemberCountStaysHidden` | Added (new file) | `Tests/CoreTests/CoopInviteIndexReadinessTests.swift` · `f67e8ab15` |
| `QuestifyCoreTests/CoopInviteIndexReadinessTests/testSupportingReadsAreLiveAndInviteRouteIsNotMarkedLive` | Added (new file) | `Tests/CoreTests/CoopInviteIndexReadinessTests.swift` · `f67e8ab15` |
| `QuestifyCoreTests/CoopInviteIndexReadinessTests/testUnknownCountIsEmDashAndLiteralZeroStaysZero` | Added (new file) | `Tests/CoreTests/CoopInviteIndexReadinessTests.swift` · `f67e8ab15` |
| `QuestifyCoreTests/CoopListPageReadyTests/testHiddenCapabilityDoesNotBindOrInventZero` | Added (new file) | `Tests/CoreTests/CoopListPageReadyTests.swift` · `9e73a7d67` |
| `QuestifyCoreTests/CoopListPageReadyTests/testKnownEmptyIsZeroAndSentRegistrationsStayHidden` | Added (new file) | `Tests/CoreTests/CoopListPageReadyTests.swift` · `9e73a7d67` |
| `QuestifyCoreTests/CoopListPageReadyTests/testLoadingCancellationAndWholeReadFailuresStayOffZero` | Added (new file) | `Tests/CoreTests/CoopListPageReadyTests.swift` · `9e73a7d67` |
| `QuestifyCoreTests/CoopListPageReadyTests/testMalformedInvitePayloadIsUnknownAndNumericStringsAreNotZero` | Added (new file) | `Tests/CoreTests/CoopListPageReadyTests.swift` · `9e73a7d67` |
| `QuestifyCoreTests/CoopListPageReadyTests/testMismatchedDirectionDoesNotBorrowTheOtherListAsZero` | Added (new file) | `Tests/CoreTests/CoopListPageReadyTests.swift` · `9e73a7d67` |
| `QuestifyCoreTests/CoopListPageReadyTests/testPartialFailureKeepsKnownZeroAndUnknownCountsApart` | Added (new file) | `Tests/CoreTests/CoopListPageReadyTests.swift` · `9e73a7d67` |
| `QuestifyCoreTests/CoopListPageReadyTests/testReadyRowsKeepLiteralZeroAndDoNotFallThroughSlots` | Added (new file) | `Tests/CoreTests/CoopListPageReadyTests.swift` · `9e73a7d67` |
| `QuestifyCoreTests/CooperationInviteDetailPageTests/testDetailReadKeepsListRouteAndSlotFacts` | Added (new file) | `Tests/CoreTests/CooperationInviteDetailPageTests.swift` · `79dc714c2` |
| `QuestifyCoreTests/CooperationInviteDetailPageTests/testIncompleteGameSlotDoesNotUseTopicCounts` | Added (new file) | `Tests/CoreTests/CooperationInviteDetailPageTests.swift` · `79dc714c2` |
| `QuestifyCoreTests/CooperationInviteDetailPageTests/testLiteralZeroSlotStaysZeroAndMissingSlotIsWithheld` | Added (new file) | `Tests/CoreTests/CooperationInviteDetailPageTests.swift` · `79dc714c2` |
| `QuestifyCoreTests/CooperationInviteDetailPageTests/testLoadUsesExistingDetailAndSkipsAnUnconfirmedId` | Added (new file) | `Tests/CoreTests/CooperationInviteDetailPageTests.swift` · `79dc714c2` |
| `QuestifyCoreTests/CooperationInviteDetailPageTests/testPagePhasesKeepUnknownCountsAsEmDash` | Added (new file) | `Tests/CoreTests/CooperationInviteDetailPageTests.swift` · `79dc714c2` |
| `QuestifyCoreTests/CooperationInviteDetailPageTests/testReadyUnknownStatusStillShowsTheRow` | Added (new file) | `Tests/CoreTests/CooperationInviteDetailPageTests.swift` · `79dc714c2` |
| `QuestifyCoreTests/CooperationInviteDetailPageTests/testUnknownSlotCountsAreEmDashNeverZero` | Added (new file) | `Tests/CoreTests/CooperationInviteDetailPageTests.swift` · `79dc714c2` |
| `QuestifyCoreTests/CooperationTests/testInviteListReadsOnlyCoopList` | Added (existing file) | `Tests/CoreTests/CooperationTests.swift` · `a1bcb311c` |
| `QuestifyCoreTests/CoreGapReaderBodyTests/testAPageBuiltWithoutABodyHasNoRawPayloadAndStaysUnknown` | Added (new file) | `Tests/CoreTests/CoreGapReaderBodyTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/CoreGapReaderBodyTests/testClubDetailBodyIsTheUnmodifiedResponseAndRejectsABadID` | Added (new file) | `Tests/CoreTests/CoreGapReaderBodyTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/CoreGapReaderBodyTests/testClubEditPageReadsTheFullRawBodyAndKeepsAMissingCountApartFromZero` | Added (new file) | `Tests/CoreTests/CoreGapReaderBodyTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/CoreGapReaderBodyTests/testClubEditPageWithoutABodyIsEmptyOrUnknownNeverACount` | Added (new file) | `Tests/CoreTests/CoreGapReaderBodyTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/CoreGapReaderBodyTests/testClubHomeBodyIsTheUnmodifiedResponseOfTheExistingRead` | Added (new file) | `Tests/CoreTests/CoreGapReaderBodyTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/CoreGapReaderBodyTests/testClubHomeBodyStillRejectsAServerRefusalBeforeAnyPageModel` | Added (new file) | `Tests/CoreTests/CoreGapReaderBodyTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/CoreGapReaderBodyTests/testClubTabProjectsFromTheRawBodyAndKeepsUnknownCountsAsEmDashes` | Added (new file) | `Tests/CoreTests/CoreGapReaderBodyTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/CoreGapReaderBodyTests/testClubTabRawBodyNilIsUnknownAndAMalformedBodyIsAnErrorNeverEmpty` | Added (new file) | `Tests/CoreTests/CoreGapReaderBodyTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/CoreGapReaderBodyTests/testClubTabRawBodyStaysCapabilityGated` | Added (new file) | `Tests/CoreTests/CoreGapReaderBodyTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/CoreGapReaderBodyTests/testFavoritePostsPageKeepsTheRawBodyForTheFavoritesProjection` | Added (new file) | `Tests/CoreTests/CoreGapReaderBodyTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/CouponCodePageReadyTests/testIssueErrorShowsNoCodeAndNoZeroCountdown` | Added (new file) | `Tests/CoreTests/CouponCodePageReadyTests.swift` · `9b83e8c7f` |
| `QuestifyCoreTests/CouponCodePageReadyTests/testLoadingEmptyCountdownAndReadyLiteralZero` | Added (new file) | `Tests/CoreTests/CouponCodePageReadyTests.swift` · `9b83e8c7f` |
| `QuestifyCoreTests/CouponCodePageReadyTests/testMissingHistoryIsEmptyAndSendsNothing` | Added (new file) | `Tests/CoreTests/CouponCodePageReadyTests.swift` · `9b83e8c7f` |
| `QuestifyCoreTests/CouponCodePageReadyTests/testUnknownStatusIsNotStoredAsAvailable` | Added (new file) | `Tests/CoreTests/CouponCodePageReadyTests.swift` · `9b83e8c7f` |
| `QuestifyCoreTests/CouponCodePageReadyTests/testUnknownTTLIsEmDashAndLiteralZeroStaysZero` | Added (new file) | `Tests/CoreTests/CouponCodePageReadyTests.swift` · `9b83e8c7f` |
| `QuestifyCoreTests/CouponInfoSettingsPageTests/testEditLoadUsesThePublishedListAndKeepsFailuresOffZero` | Added (new file) | `Tests/CoreTests/CouponInfoSettingsPageTests.swift` · `81b1419c8` |
| `QuestifyCoreTests/CouponInfoSettingsPageTests/testLoadingEmptyReadyAndLiteralZero` | Added (new file) | `Tests/CoreTests/CouponInfoSettingsPageTests.swift` · `81b1419c8` |
| `QuestifyCoreTests/CouponInfoSettingsPageTests/testSettingsPageStaysHiddenWithoutAReadAndDoesNotCallTheAdapter` | Added (new file) | `Tests/CoreTests/CouponInfoSettingsPageTests.swift` · `81b1419c8` |
| `QuestifyCoreTests/CouponInfoSettingsPageTests/testUnknownAmountsAreEmDashAndALiteralZeroStaysZero` | Added (new file) | `Tests/CoreTests/CouponInfoSettingsPageTests.swift` · `81b1419c8` |
| `QuestifyCoreTests/CreatorStudioTransportTests/testCloseSendsVersionCASAndMapsFixNotPublished` | Added (new file) | `Tests/CoreTests/CreatorStudioTransportTests.swift` · `04b244ff9`, `259c79d15` |
| `QuestifyCoreTests/CreatorStudioTransportTests/testCreatorWithoutTopicsIsABusinessNotFoundAndKeepsTheEntry` | Added (new file) | `Tests/CoreTests/CreatorStudioTransportTests.swift` · `04b244ff9`, `259c79d15` |
| `QuestifyCoreTests/CreatorStudioTransportTests/testFeedbackReadIsScopedToOneTopicAndHidesTheReporter` | Added (new file) | `Tests/CoreTests/CreatorStudioTransportTests.swift` · `04b244ff9`, `259c79d15` |
| `QuestifyCoreTests/CreatorStudioTransportTests/testFinishedAndInconsistentTurnBlocks` | Added (new file) | `Tests/CoreTests/CreatorStudioTransportTests.swift` · `04b244ff9`, `259c79d15` |
| `QuestifyCoreTests/CreatorStudioTransportTests/testLeaderSeesTheFullOrderWithCurrentAndNextRole` | Added (new file) | `Tests/CoreTests/CreatorStudioTransportTests.swift` · `04b244ff9`, `259c79d15` |
| `QuestifyCoreTests/CreatorStudioTransportTests/testMemberTurnBlockShowsCurrentAndNextWithoutOtherRoles` | Added (new file) | `Tests/CoreTests/CreatorStudioTransportTests.swift` · `04b244ff9`, `259c79d15` |
| `QuestifyCoreTests/CreatorStudioTransportTests/testNonLeaderDropsALeakedOrder` | Added (new file) | `Tests/CoreTests/CreatorStudioTransportTests.swift` · `04b244ff9`, `259c79d15` |
| `QuestifyCoreTests/CreatorStudioTransportTests/testOpenTicketSendsTheContractBodyAndDecodesTheReportedTicket` | Added (new file) | `Tests/CoreTests/CreatorStudioTransportTests.swift` · `04b244ff9`, `259c79d15` |
| `QuestifyCoreTests/CreatorStudioTransportTests/testOpenWithLostResponseIsUnknownAndTheRequestReadRecoversIt` | Added (new file) | `Tests/CoreTests/CreatorStudioTransportTests.swift` · `04b244ff9`, `259c79d15` |
| `QuestifyCoreTests/CreatorStudioTransportTests/testPostGameOutcomeSendsQueryAndKeepsNotMatureApartFromZero` | Added (new file) | `Tests/CoreTests/CreatorStudioTransportTests.swift` · `04b244ff9`, `259c79d15` |
| `QuestifyCoreTests/CreatorStudioTransportTests/testRefusedCompositionAndSignedOutHideTheEntry` | Added (new file) | `Tests/CoreTests/CreatorStudioTransportTests.swift` · `04b244ff9`, `259c79d15` |
| `QuestifyCoreTests/CreatorStudioTransportTests/testRouteMissingOnTheBackendHidesBothEntries` | Added (new file) | `Tests/CoreTests/CreatorStudioTransportTests.swift` · `04b244ff9`, `259c79d15` |
| `QuestifyCoreTests/CreatorStudioTransportTests/testSystemBusyBodyIsUnavailableNotEmpty` | Added (new file) | `Tests/CoreTests/CreatorStudioTransportTests.swift` · `04b244ff9`, `259c79d15` |
| `QuestifyCoreTests/CreatorStudioTransportTests/testTicketDetailReadsOneTicketAndMapsMissingTicket` | Added (new file) | `Tests/CoreTests/CreatorStudioTransportTests.swift` · `04b244ff9`, `259c79d15` |
| `QuestifyCoreTests/CreatorStudioTransportTests/testTicketListDecodesServerDerivedStageAndEvidence` | Added (new file) | `Tests/CoreTests/CreatorStudioTransportTests.swift` · `04b244ff9`, `259c79d15` |
| `QuestifyCoreTests/DeregistrationStatusRulesTests/testDeregisterIndexPagePhasesDoNotInventNumbers` | Added (existing file) | `Tests/CoreTests/DeregistrationStatusRulesTests.swift` · `c5150bf32` |
| `QuestifyCoreTests/DeregistrationStatusRulesTests/testUnknownQuantityIsEmDashNeverZero` | Added (existing file) | `Tests/CoreTests/DeregistrationStatusRulesTests.swift` · `c5150bf32` |
| `QuestifyCoreTests/DiscoveryPlayTemplateExtrasTests/testMissingCountsAreEmDashAndLiteralZeroStaysZero` | Added (existing file) | `Tests/CoreTests/DiscoveryPlayTemplateExtrasTests.swift` · `cd343f437` |
| `QuestifyCoreTests/DiscoveryPlayTemplateExtrasTests/testReadPhaseKeepsLoadingEmptyErrorAndUnknownApart` | Added (existing file) | `Tests/CoreTests/DiscoveryPlayTemplateExtrasTests.swift` · `cd343f437` |
| `QuestifyCoreTests/ExternalGameImportTests/testAgeGateIsPerGameAndKillSwitchRemovesUnpublished` | Added (existing file) | `Tests/CoreTests/ExternalGameImportTests.swift` · `b36aa479b`, `899db4cd2` |
| `QuestifyCoreTests/ExternalGameImportTests/testEd25519RoundTripAndEmptyKeyFailsClosed` | Added (existing file) | `Tests/CoreTests/ExternalGameImportTests.swift` · `b36aa479b`, `899db4cd2` |
| `QuestifyCoreTests/ExternalGameImportTests/testExternalGameReviewStatusLeavesPendingOnlyWhenTheServerConfirms` | Added (existing file) | `Tests/CoreTests/ExternalGameImportTests.swift` · `b36aa479b`, `899db4cd2` |
| `QuestifyCoreTests/ExternalGameReviewClientTests/testCancelResubmitAndReportPinPostPaths` | Added (new file) | `Tests/CoreTests/ExternalGameReviewClientTests.swift` · `e76842486`, `4ce602883`, `899db4cd2` |
| `QuestifyCoreTests/ExternalGameReviewClientTests/testCapturedRouteAbsentBodyDoesNotDecodeAGame` | Added (new file) | `Tests/CoreTests/ExternalGameReviewClientTests.swift` · `e76842486`, `4ce602883`, `899db4cd2` |
| `QuestifyCoreTests/ExternalGameReviewClientTests/testCatalogDownloadAndUnknownSubmitKeepsTheRequestID` | Added (new file) | `Tests/CoreTests/ExternalGameReviewClientTests.swift` · `e76842486`, `4ce602883`, `899db4cd2` |
| `QuestifyCoreTests/ExternalGameReviewClientTests/testConfirmedRejectIsNotSuccessAndZipIsNotSubmitted` | Added (new file) | `Tests/CoreTests/ExternalGameReviewClientTests.swift` · `e76842486`, `4ce602883`, `899db4cd2` |
| `QuestifyCoreTests/ExternalGameReviewClientTests/testGrantKeyFoldsTheCatalogGameID` | Added (new file) | `Tests/CoreTests/ExternalGameReviewClientTests.swift` · `e76842486`, `4ce602883`, `899db4cd2` |
| `QuestifyCoreTests/ExternalGameReviewClientTests/testUncoveredReadsPinGetPaths` | Added (new file) | `Tests/CoreTests/ExternalGameReviewClientTests.swift` · `e76842486`, `4ce602883`, `899db4cd2` |
| `QuestifyCoreTests/FogCellBitmapTests/testBoundsContainTheirOwnPoint` | Added (new file) | `Tests/CoreTests/FogCellBitmapTests.swift` · `cf4ead856` |
| `QuestifyCoreTests/FogCellBitmapTests/testCoverageCountsChildrenPerGeohash6` | Added (new file) | `Tests/CoreTests/FogCellBitmapTests.swift` · `cf4ead856` |
| `QuestifyCoreTests/FogCellBitmapTests/testEnvelopeRoundTripOwnerAndVersionChecks` | Added (new file) | `Tests/CoreTests/FogCellBitmapTests.swift` · `cf4ead856` |
| `QuestifyCoreTests/FogCellBitmapTests/testEveryChildIndexRoundTripsOverTheAlphabet` | Added (new file) | `Tests/CoreTests/FogCellBitmapTests.swift` · `cf4ead856` |
| `QuestifyCoreTests/FogCellBitmapTests/testFixStreamStaysGatedOff` | Added (new file) | `Tests/CoreTests/FogCellBitmapTests.swift` · `cf4ead856` |
| `QuestifyCoreTests/FogCellBitmapTests/testRejectsNonPrecisionSevenAndBadCharacters` | Added (new file) | `Tests/CoreTests/FogCellBitmapTests.swift` · `cf4ead856` |
| `QuestifyCoreTests/FogCellBitmapTests/testShanghaiFixtureWalkYieldsTheLiteralCellSet` | Added (new file) | `Tests/CoreTests/FogCellBitmapTests.swift` · `cf4ead856` |
| `QuestifyCoreTests/FogCellBitmapTests/testTileKeysFromRoamMathRoundTrip` | Added (new file) | `Tests/CoreTests/FogCellBitmapTests.swift` · `cf4ead856` |
| `QuestifyCoreTests/FogCellBitmapTests/testUnionIgnoresOtherGrid` | Added (new file) | `Tests/CoreTests/FogCellBitmapTests.swift` · `cf4ead856` |
| `QuestifyCoreTests/FogCellBitmapTests/testUnionPopcountAndSubtract` | Added (new file) | `Tests/CoreTests/FogCellBitmapTests.swift` · `cf4ead856` |
| `QuestifyCoreTests/FogCoverageReadingTests/testEveryUnknownReasonPrintsAnEmDashNeverZero` | Added (new file) | `Tests/CoreTests/FogCellBitmapTests.swift` · `cf4ead856` |
| `QuestifyCoreTests/FogCoverageReadingTests/testKnownReadings` | Added (new file) | `Tests/CoreTests/FogCellBitmapTests.swift` · `cf4ead856` |
| `QuestifyCoreTests/FogCoverageReadingTests/testReaderMapsMissingInputsToUnknown` | Added (new file) | `Tests/CoreTests/FogCellBitmapTests.swift` · `cf4ead856` |
| `QuestifyCoreTests/RoamLocationPrimerStepTests/testDeniedAlwaysShowsSettingsCardAndAuthorizedShowsNothing` | Added (new file) | `Tests/CoreTests/FogCellBitmapTests.swift` · `cf4ead856` |
| `QuestifyCoreTests/RoamLocationPrimerStepTests/testPrimingShowsOnceBeforeTheSystemPrompt` | Added (new file) | `Tests/CoreTests/FogCellBitmapTests.swift` · `cf4ead856` |
| `QuestifyCoreTests/FogMaskRasterizerTests/testCell6CoverageScalesAlphaAndSummaryHasNoMask` | Added (new file) | `Tests/CoreTests/FogMaskRasterizerTests.swift` · `cf4ead856` |
| `QuestifyCoreTests/FogMaskRasterizerTests/testCellCentresAreExactlyConfirmedPendingOrHidden` | Added (new file) | `Tests/CoreTests/FogMaskRasterizerTests.swift` · `cf4ead856` |
| `QuestifyCoreTests/FogMaskRasterizerTests/testCellsInWindowFiltersByIntersection` | Added (new file) | `Tests/CoreTests/FogMaskRasterizerTests.swift` · `cf4ead856` |
| `QuestifyCoreTests/FogMaskRasterizerTests/testEmptyBitmapsGiveAnAllHiddenMask` | Added (new file) | `Tests/CoreTests/FogMaskRasterizerTests.swift` · `cf4ead856` |
| `QuestifyCoreTests/FogMaskRasterizerTests/testFixtureWalkMasksEveryRevealedCentreAndNoneOfTheRejectedFixes` | Added (new file) | `Tests/CoreTests/FogMaskRasterizerTests.swift` · `cf4ead856` |
| `QuestifyCoreTests/FogMaskRasterizerTests/testLargeWindowIsCappedAtMaxSide` | Added (new file) | `Tests/CoreTests/FogMaskRasterizerTests.swift` · `cf4ead856` |
| `QuestifyCoreTests/FogMaskRasterizerTests/testLevelOfDetailThresholdsAndHysteresis` | Added (new file) | `Tests/CoreTests/FogMaskRasterizerTests.swift` · `cf4ead856` |
| `QuestifyCoreTests/FogMaskRasterizerTests/testNeedsRebuildOnRevisionWindowExitAndLodOnly` | Added (new file) | `Tests/CoreTests/FogMaskRasterizerTests.swift` · `cf4ead856` |
| `QuestifyCoreTests/FogMaskRasterizerTests/testSoftenOnlyBlursAndStaysInRange` | Added (new file) | `Tests/CoreTests/FogMaskRasterizerTests.swift` · `cf4ead856` |
| `QuestifyCoreTests/FreeExploreBundlePageReadyTests/testLegacyOrderIsNotAnEmptyShelfAndNotAZeroPrice` | Added (new file) | `Tests/CoreTests/FreeExploreBundlePageReadyTests.swift` · `a8c59d0bd` |
| `QuestifyCoreTests/FreeExploreBundlePageReadyTests/testLiteralZeroPriceAndPaidAmountStayZero` | Added (new file) | `Tests/CoreTests/FreeExploreBundlePageReadyTests.swift` · `a8c59d0bd` |
| `QuestifyCoreTests/FreeExploreBundlePageReadyTests/testLoadingEmptyErrorAndUnknownStayDistinct` | Added (new file) | `Tests/CoreTests/FreeExploreBundlePageReadyTests.swift` · `a8c59d0bd` |
| `QuestifyCoreTests/FreeExploreBundlePageReadyTests/testRefreshKeepsThePreviousAmount` | Added (new file) | `Tests/CoreTests/FreeExploreBundlePageReadyTests.swift` · `a8c59d0bd` |
| `QuestifyCoreTests/FreeExploreBundlePageReadyTests/testSaleFlagDoesNotOpenPurchaseAndPlayerFirstStaysClosed` | Added (new file) | `Tests/CoreTests/FreeExploreBundlePageReadyTests.swift` · `a8c59d0bd` |
| `QuestifyCoreTests/FreeExploreBundlePageReadyTests/testUnknownMoneyIsADashAndLiteralZeroStaysZero` | Added (new file) | `Tests/CoreTests/FreeExploreBundlePageReadyTests.swift` · `a8c59d0bd` |
| `QuestifyCoreTests/FreeExploreBundlePageReadyTests/testWelcomeHomeAndAccountStayOffThisPage` | Added (new file) | `Tests/CoreTests/FreeExploreBundlePageReadyTests.swift` · `a8c59d0bd` |
| `QuestifyCoreTests/FreeExploreBundlePageReadyTests/testZeroQuoteStaysZeroAndMissingSaleIsNotFalse` | Added (new file) | `Tests/CoreTests/FreeExploreBundlePageReadyTests.swift` · `a8c59d0bd` |
| `QuestifyCoreTests/G6CapabilitySourceTests/testAIDraftFlowPreparesExecutesAndReturnsTheResult` | Added (new file) | `Tests/CoreTests/G6CapabilitySourceTests.swift` · `04b244ff9`, `83796dab6` |
| `QuestifyCoreTests/G6CapabilitySourceTests/testAIDraftNetworkFailureKeepsTheIdentity` | Added (new file) | `Tests/CoreTests/G6CapabilitySourceTests.swift` · `04b244ff9`, `83796dab6` |
| `QuestifyCoreTests/G6CapabilitySourceTests/testAIDraftRequestShapes` | Added (new file) | `Tests/CoreTests/G6CapabilitySourceTests.swift` · `04b244ff9`, `83796dab6` |
| `QuestifyCoreTests/G6CapabilitySourceTests/testAIDraftUnknownIsReadBackNotRepreparedUntilConfirmed` | Added (new file) | `Tests/CoreTests/G6CapabilitySourceTests.swift` · `04b244ff9`, `83796dab6` |
| `QuestifyCoreTests/G6CapabilitySourceTests/testAIDraftViewRejectsAnyExtraOrMissingKey` | Added (new file) | `Tests/CoreTests/G6CapabilitySourceTests.swift` · `04b244ff9`, `83796dab6` |
| `QuestifyCoreTests/G6CapabilitySourceTests/testAuthorWriteReceiptReadAndDecision` | Added (new file) | `Tests/CoreTests/G6CapabilitySourceTests.swift` · `04b244ff9`, `83796dab6` |
| `QuestifyCoreTests/G6CapabilitySourceTests/testChinaProductionAdmitsTheG6GrantAndRefusesHiddenAndMoneyRoutes` | Added (new file) | `Tests/CoreTests/G6CapabilitySourceTests.swift` · `04b244ff9`, `83796dab6` |
| `QuestifyCoreTests/G6CapabilitySourceTests/testCoordinatorQueuesUntilTheProfileArrivesAndShowsOnlyReviewedLines` | Added (new file) | `Tests/CoreTests/G6CapabilitySourceTests.swift` · `04b244ff9`, `83796dab6` |
| `QuestifyCoreTests/G6CapabilitySourceTests/testCoordinatorStaysSilentWhenTheFlagIsOffAndGivesUpAfterTwoProfileMisses` | Added (new file) | `Tests/CoreTests/G6CapabilitySourceTests.swift` · `04b244ff9`, `83796dab6` |
| `QuestifyCoreTests/G6CapabilitySourceTests/testJournalRefusesIllegalUpdates` | Added (new file) | `Tests/CoreTests/G6CapabilitySourceTests.swift` · `04b244ff9`, `83796dab6` |
| `QuestifyCoreTests/G6CapabilitySourceTests/testMarketingProductDetailReadsOneProduct` | Added (new file) | `Tests/CoreTests/G6CapabilitySourceTests.swift` · `04b244ff9`, `83796dab6` |
| `QuestifyCoreTests/G6CapabilitySourceTests/testNPCChatShellBuildsTheRoamTrackAndReadsBackWithoutResending` | Added (new file) | `Tests/CoreTests/G6CapabilitySourceTests.swift` · `04b244ff9`, `83796dab6` |
| `QuestifyCoreTests/G6CapabilitySourceTests/testNPCEventAlwaysSendsCacheOnlyAndDropsAnEmptyLine` | Added (new file) | `Tests/CoreTests/G6CapabilitySourceTests.swift` · `04b244ff9`, `83796dab6` |
| `QuestifyCoreTests/G6CapabilitySourceTests/testNPCProfileReadsGlobalAndNodeScopes` | Added (new file) | `Tests/CoreTests/G6CapabilitySourceTests.swift` · `04b244ff9`, `83796dab6` |
| `QuestifyCoreTests/G6CapabilitySourceTests/testPromotionCatalogShapeAndView` | Added (new file) | `Tests/CoreTests/G6CapabilitySourceTests.swift` · `04b244ff9`, `83796dab6` |
| `QuestifyCoreTests/G6CapabilitySourceTests/testRecoveryPageOrderingAndPagingRules` | Added (new file) | `Tests/CoreTests/G6CapabilitySourceTests.swift` · `04b244ff9`, `83796dab6` |
| `QuestifyCoreTests/G6CapabilitySourceTests/testRevenueAllocationsNeverShowUnknownAsZero` | Added (new file) | `Tests/CoreTests/G6CapabilitySourceTests.swift` · `04b244ff9`, `83796dab6` |
| `QuestifyCoreTests/G6CapabilitySourceTests/testRoamGateQuotasAndGaps` | Added (new file) | `Tests/CoreTests/G6CapabilitySourceTests.swift` · `04b244ff9`, `83796dab6` |
| `QuestifyCoreTests/G6CapabilitySourceTests/testStoryCharactersAskFourMerchantStopsAndKeepEightUniqueNames` | Added (new file) | `Tests/CoreTests/G6CapabilitySourceTests.swift` · `04b244ff9`, `83796dab6` |
| `QuestifyCoreTests/G7ClientRulesTests/testBoundaryDoesNotCallNetworkOrEnableMoney` | Added (new file) | `Tests/CoreTests/G7ClientRulesTests.swift` · `68d254edc` |
| `QuestifyCoreTests/G7ClientRulesTests/testCT04dDecliningShareKeepsPlayAndRoam` | Added (new file) | `Tests/CoreTests/G7ClientRulesTests.swift` · `68d254edc` |
| `QuestifyCoreTests/G7ClientRulesTests/testCT04eCopiesDoNotExtendRetentionOrGainUses` | Added (new file) | `Tests/CoreTests/G7ClientRulesTests.swift` · `68d254edc` |
| `QuestifyCoreTests/G7ClientRulesTests/testCT05cPlaceIDsStayDistinctKinds` | Added (new file) | `Tests/CoreTests/G7ClientRulesTests.swift` · `68d254edc` |
| `QuestifyCoreTests/G7ClientRulesTests/testCT07ePendingPhotoAwardsNothingAndReplayReturnsOriginal` | Added (new file) | `Tests/CoreTests/G7ClientRulesTests.swift` · `68d254edc` |
| `QuestifyCoreTests/G7ClientRulesTests/testCT09bHalfUnitBalanceAndCapacityNeverSpendMoney` | Added (new file) | `Tests/CoreTests/G7ClientRulesTests.swift` · `68d254edc` |
| `QuestifyCoreTests/G7ClientRulesTests/testCT09cNoShowTouchesOnlyThatUnit` | Added (new file) | `Tests/CoreTests/G7ClientRulesTests.swift` · `68d254edc` |
| `QuestifyCoreTests/G7ClientRulesTests/testCT14bExpiredReferenceDoesNotBecomeLocationlessPublicPost` | Added (new file) | `Tests/CoreTests/G7ClientRulesTests.swift` · `68d254edc` |
| `QuestifyCoreTests/GlobalSearchEntryReadinessTests/testFirstReadLoadingErrorAndIdleEntry` | Added (new file) | `Tests/CoreTests/GlobalSearchEntryReadinessTests.swift` · `693ae89fc` |
| `QuestifyCoreTests/GlobalSearchEntryReadinessTests/testKnownZeroStaysZeroAndUnresolvedLaneIsEmDash` | Added (new file) | `Tests/CoreTests/GlobalSearchEntryReadinessTests.swift` · `693ae89fc` |
| `QuestifyCoreTests/GlobalSearchEntryReadinessTests/testMerchantFailureDoesNotChangeASuccessfulPlayerTotal` | Added (new file) | `Tests/CoreTests/GlobalSearchEntryReadinessTests.swift` · `693ae89fc` |
| `QuestifyCoreTests/GlobalSearchEntryReadinessTests/testPlayerDenialsUseExistingKeysAndDoNotBecomeEmpty` | Added (new file) | `Tests/CoreTests/GlobalSearchEntryReadinessTests.swift` · `693ae89fc` |
| `QuestifyCoreTests/GlobalSearchEntryReadinessTests/testPlayerScopeIsTopicActivityAndClub` | Added (new file) | `Tests/CoreTests/GlobalSearchEntryReadinessTests.swift` · `693ae89fc` |
| `QuestifyCoreTests/GlobalSearchEntryReadinessTests/testRetainedRowsDoNotTurnAFailedLaneIntoAConfirmedCount` | Added (new file) | `Tests/CoreTests/GlobalSearchEntryReadinessTests.swift` · `693ae89fc` |
| `QuestifyCoreTests/GlobalSearchEntryReadinessTests/testSuccessfulCountsSumOnlyPlayerLanes` | Added (new file) | `Tests/CoreTests/GlobalSearchEntryReadinessTests.swift` · `693ae89fc` |
| `QuestifyCoreTests/GlobalSearchEntryReadinessTests/testUnreadCategoryDirectoryIsUnknownNotZero` | Added (new file) | `Tests/CoreTests/GlobalSearchEntryReadinessTests.swift` · `693ae89fc` |
| `QuestifyCoreTests/GrowthLeaderboardPageReadyTests/testCoordinatorLoadsTheExistingReaderAndKeepsHiddenCapabilitiesUncalled` | Added (new file) | `Tests/CoreTests/GrowthLeaderboardPageReadyTests.swift` · `cdfc87b7b` |
| `QuestifyCoreTests/GrowthLeaderboardPageReadyTests/testEmptyBoardCanStillShowAPositiveViewerRankWithoutInventingZero` | Added (new file) | `Tests/CoreTests/GrowthLeaderboardPageReadyTests.swift` · `cdfc87b7b` |
| `QuestifyCoreTests/GrowthLeaderboardPageReadyTests/testHiddenBoardsStayHiddenAndDoNotBecomeLiveRoutes` | Added (new file) | `Tests/CoreTests/GrowthLeaderboardPageReadyTests.swift` · `cdfc87b7b` |
| `QuestifyCoreTests/GrowthLeaderboardPageReadyTests/testLoadingEmptyErrorAndUnknownAreDistinctPageStates` | Added (new file) | `Tests/CoreTests/GrowthLeaderboardPageReadyTests.swift` · `cdfc87b7b` |
| `QuestifyCoreTests/GrowthLeaderboardPageReadyTests/testReadyBoardKeepsALiteralZeroScoreAndAnUnknownScoreAsAnEmDash` | Added (new file) | `Tests/CoreTests/GrowthLeaderboardPageReadyTests.swift` · `cdfc87b7b` |
| `QuestifyCoreTests/GrowthLeaderboardPageReadyTests/testSignedOutAndUnconfiguredReadsStayErrorsWithoutCallingTheBoard` | Added (new file) | `Tests/CoreTests/GrowthLeaderboardPageReadyTests.swift` · `cdfc87b7b` |
| `QuestifyCoreTests/GrowthLeaderboardPageReadyTests/testUnknownNumbersUseAnEmDashAndNeverBecomeZero` | Added (new file) | `Tests/CoreTests/GrowthLeaderboardPageReadyTests.swift` · `cdfc87b7b` |
| `QuestifyCoreTests/HomeFeedTests/testSurfaceStatesUseEmDashForUnknownAndDoNotInventZero` | Added (existing file) | `Tests/CoreTests/HomeFeedTests.swift` · `c5150bf32` |
| `QuestifyCoreTests/IMChatSessionPageTests/testConversationKindsStayOnTheExistingContract` | Added (new file) | `Tests/CoreTests/IMChatSessionPageTests.swift` · `50d3ac23e`, `165fdff50` |
| `QuestifyCoreTests/IMChatSessionPageTests/testCoordinatorMapsClosedAndMalformedWithoutAZeroCount` | Added (new file) | `Tests/CoreTests/IMChatSessionPageTests.swift` · `50d3ac23e`, `165fdff50` |
| `QuestifyCoreTests/IMChatSessionPageTests/testCoordinatorReadsMessagesOnlyAndHidesAMissingCapability` | Added (new file) | `Tests/CoreTests/IMChatSessionPageTests.swift` · `50d3ac23e`, `165fdff50` |
| `QuestifyCoreTests/IMChatSessionPageTests/testDebugFixtureDataProjectsReadyEmptyUnknownAndClosed` | Added (new file) | `Tests/CoreTests/IMChatSessionPageTests.swift` · `50d3ac23e`, `165fdff50` |
| `QuestifyCoreTests/IMChatSessionPageTests/testDecodedReaderPageKeepsLiteralZeroAndDoesNotTreatMalformedAsEmpty` | Added (new file) | `Tests/CoreTests/IMChatSessionPageTests.swift` · `50d3ac23e`, `165fdff50` |
| `QuestifyCoreTests/IMChatSessionPageTests/testReadyEmptyErrorAndUnknownDoNotGuessACount` | Added (new file) | `Tests/CoreTests/IMChatSessionPageTests.swift` · `50d3ac23e`, `165fdff50` |
| `QuestifyCoreTests/IMChatSessionPageTests/testSendReadReceiptAndPollStayHiddenUnlessAnExistingSendGrantApplies` | Added (new file) | `Tests/CoreTests/IMChatSessionPageTests.swift` · `50d3ac23e`, `165fdff50` |
| `QuestifyCoreTests/IMChatSessionPageTests/testStaleLoadDoesNotPublishThePreviousAccount` | Added (new file) | `Tests/CoreTests/IMChatSessionPageTests.swift` · `50d3ac23e`, `165fdff50` |
| `QuestifyCoreTests/IMChatSessionPageTests/testUnknownCountsStayAnEmDashAndLiteralZeroStaysZero` | Added (new file) | `Tests/CoreTests/IMChatSessionPageTests.swift` · `50d3ac23e`, `165fdff50` |
| `QuestifyCoreTests/IMListPageReadyLoadTests/testFailureAndCancellationDoNotBecomeAnEmptyList` | Added (existing file) | `Tests/CoreTests/IMInboxTests.swift` · `a2fbf51f6` |
| `QuestifyCoreTests/IMListPageReadyLoadTests/testReloadUsesTheConversationsReadAndHidesAMissingReader` | Added (existing file) | `Tests/CoreTests/IMInboxTests.swift` · `a2fbf51f6` |
| `QuestifyCoreTests/IMListPageReadyTests/testConversationKindsStayTheExistingContract` | Added (existing file) | `Tests/CoreTests/IMInboxTests.swift` · `a2fbf51f6` |
| `QuestifyCoreTests/IMListPageReadyTests/testFixtureDataKeepsExistingKindsAndUnknownUnread` | Added (existing file) | `Tests/CoreTests/IMInboxTests.swift` · `a2fbf51f6` |
| `QuestifyCoreTests/IMListPageReadyTests/testLoadingErrorAndUnknownDoNotGuessZero` | Added (existing file) | `Tests/CoreTests/IMInboxTests.swift` · `a2fbf51f6` |
| `QuestifyCoreTests/IMListPageReadyTests/testMutedUnknownUnreadDoesNotPoisonAKnownTotal` | Added (existing file) | `Tests/CoreTests/IMInboxTests.swift` · `a2fbf51f6` |
| `QuestifyCoreTests/IMListPageReadyTests/testUnknownUnreadIsAnEmDashAndLiteralZeroStaysZero` | Added (existing file) | `Tests/CoreTests/IMInboxTests.swift` · `a2fbf51f6` |
| `QuestifyCoreTests/IMPreviewTemplateLeaseTests/testBoundViewerAndConversationIssuesTheConcreteGet` | Added (new file) | `Tests/CoreTests/IMPreviewTemplateLeaseTests.swift` · `8f061385e`, `f4d67c77e` |
| `QuestifyCoreTests/IMPreviewTemplateLeaseTests/testCatalogStaysOnTheMissingOwnerGrant` | Added (new file) | `Tests/CoreTests/IMPreviewTemplateLeaseTests.swift` · `8f061385e`, `f4d67c77e` |
| `QuestifyCoreTests/IMPreviewTemplateLeaseTests/testEncodedSlashAndBackslashRefusesAndIssuesNothing` | Added (new file) | `Tests/CoreTests/IMPreviewTemplateLeaseTests.swift` · `8f061385e`, `f4d67c77e` |
| `QuestifyCoreTests/IMPreviewTemplateLeaseTests/testExpiredLeaseRefusesAndIssuesNothing` | Added (new file) | `Tests/CoreTests/IMPreviewTemplateLeaseTests.swift` · `8f061385e`, `f4d67c77e` |
| `QuestifyCoreTests/IMPreviewTemplateLeaseTests/testPathTraversalRefusesAndIssuesNothing` | Added (new file) | `Tests/CoreTests/IMPreviewTemplateLeaseTests.swift` · `8f061385e`, `f4d67c77e` |
| `QuestifyCoreTests/IMPreviewTemplateLeaseTests/testWrongConversationRefusesAndIssuesNothing` | Added (new file) | `Tests/CoreTests/IMPreviewTemplateLeaseTests.swift` · `8f061385e`, `f4d67c77e` |
| `QuestifyCoreTests/IMPreviewTemplateLeaseTests/testWrongVerbRefusesAndIssuesNothing` | Added (new file) | `Tests/CoreTests/IMPreviewTemplateLeaseTests.swift` · `8f061385e`, `f4d67c77e` |
| `QuestifyCoreTests/InformationDetailPageModelTests/testCommerceFlagsStayOffAndURLMessagesAreDropped` | Added (new file) | `Tests/CoreTests/InformationDetailPageModelTests.swift` · `b2565e4dc` |
| `QuestifyCoreTests/InformationDetailPageModelTests/testDebugFixtureDataProjectsReadyRemovedAndCounts` | Added (new file) | `Tests/CoreTests/InformationDetailPageModelTests.swift` · `b2565e4dc` |
| `QuestifyCoreTests/InformationDetailPageModelTests/testIncompleteLinkDoesNotReadAndDoesNotShowZero` | Added (new file) | `Tests/CoreTests/InformationDetailPageModelTests.swift` · `b2565e4dc` |
| `QuestifyCoreTests/InformationDetailPageModelTests/testLoadingEmptyErrorAndUnknownStayDistinct` | Added (new file) | `Tests/CoreTests/InformationDetailPageModelTests.swift` · `b2565e4dc` |
| `QuestifyCoreTests/InformationDetailPageModelTests/testMissingCapabilityOrOtherPathStaysHidden` | Added (new file) | `Tests/CoreTests/InformationDetailPageModelTests.swift` · `b2565e4dc` |
| `QuestifyCoreTests/InformationDetailPageModelTests/testReadyDocumentKeepsCreateTimeAndBlankBody` | Added (new file) | `Tests/CoreTests/InformationDetailPageModelTests.swift` · `b2565e4dc` |
| `QuestifyCoreTests/InformationDetailPageModelTests/testUnknownCountIsAnEmDashAndLiteralZeroStaysZero` | Added (new file) | `Tests/CoreTests/InformationDetailPageModelTests.swift` · `b2565e4dc` |
| `QuestifyCoreTests/InformationDetailPageModelTests/testWrongArticleAndBlankDocumentAreUnknownNotAGuessedRow` | Added (new file) | `Tests/CoreTests/InformationDetailPageModelTests.swift` · `b2565e4dc` |
| `QuestifyCoreTests/InvoiceLaunchApplyPageTests/testApplyPageLoadingEmptyReadyAndLiteralZero` | Added (new file) | `Tests/CoreTests/InvoiceLaunchApplyPageTests.swift` · `4716aafdc` |
| `QuestifyCoreTests/InvoiceLaunchApplyPageTests/testApplyPageStaysHiddenWithoutAReadAndDoesNotCallTheCoordinator` | Added (new file) | `Tests/CoreTests/InvoiceLaunchApplyPageTests.swift` · `4716aafdc` |
| `QuestifyCoreTests/InvoiceLaunchApplyPageTests/testLoadUsesTheExistingOverviewAndKeepsFailuresOffZero` | Added (new file) | `Tests/CoreTests/InvoiceLaunchApplyPageTests.swift` · `4716aafdc` |
| `QuestifyCoreTests/InvoiceLaunchApplyPageTests/testUnknownAmountsAreEmDashAndALiteralZeroStaysZero` | Added (new file) | `Tests/CoreTests/InvoiceLaunchApplyPageTests.swift` · `4716aafdc` |
| `QuestifyCoreTests/InvoiceLaunchStatusTests/testLiteralZeroAmountStaysZeroAndUnknownDoesNotDecodeAsZero` | Added (existing file) | `Tests/CoreTests/InvoiceLaunchStatusTests.swift` · `06dd7542d` |
| `QuestifyCoreTests/InvoiceLaunchTitleEditorReadTests/testCreateIsReadyImmediatelyAndDoesNotInventIdentity` | Added (new file) | `Tests/CoreTests/InvoiceLaunchTitleEditorReadTests.swift` · `e3c7a0072` |
| `QuestifyCoreTests/InvoiceLaunchTitleEditorReadTests/testEditStaysLoadingUntilTitlesArriveEvenWhenASaveIsUnknown` | Added (new file) | `Tests/CoreTests/InvoiceLaunchTitleEditorReadTests.swift` · `e3c7a0072` |
| `QuestifyCoreTests/InvoiceLaunchTitleEditorReadTests/testFoundTitleShowsTheMaskAndDropsRawTaxPhoneAndEmail` | Added (new file) | `Tests/CoreTests/InvoiceLaunchTitleEditorReadTests.swift` · `e3c7a0072` |
| `QuestifyCoreTests/InvoiceLaunchTitleEditorReadTests/testLoginAndUnavailableStayEmptyAndDoNotExposeTheTitle` | Added (new file) | `Tests/CoreTests/InvoiceLaunchTitleEditorReadTests.swift` · `e3c7a0072` |
| `QuestifyCoreTests/InvoiceLaunchTitleEditorReadTests/testMissingDefaultAndNumericDefaultDoNotBecomeFalseOrZero` | Added (new file) | `Tests/CoreTests/InvoiceLaunchTitleEditorReadTests.swift` · `e3c7a0072` |
| `QuestifyCoreTests/InvoiceLaunchTitleEditorReadTests/testMissingOrUnmaskedTaxIsAnEmDashNeverZero` | Added (new file) | `Tests/CoreTests/InvoiceLaunchTitleEditorReadTests.swift` · `e3c7a0072` |
| `QuestifyCoreTests/InvoiceLaunchTitleEditorReadTests/testUnknownSaveKeepsTheBlankFormAndTheOriginalRequestKey` | Added (new file) | `Tests/CoreTests/InvoiceLaunchTitleEditorReadTests.swift` · `e3c7a0072` |
| `QuestifyCoreTests/InvoiceLaunchTitlesPageTests/testConfirmedEmptyListIsZeroAndAReadyListKeepsItsCount` | Added (new file) | `Tests/CoreTests/InvoiceLaunchTitlesPageTests.swift` · `b0165a252` |
| `QuestifyCoreTests/InvoiceLaunchTitlesPageTests/testDeleteInFlightBlocksOnlyThatRowAndABadTaxEchoIsAnEmDash` | Added (new file) | `Tests/CoreTests/InvoiceLaunchTitlesPageTests.swift` · `b0165a252` |
| `QuestifyCoreTests/InvoiceLaunchTitlesPageTests/testLoadingWinsAndAFailedReadStaysUnknownRatherThanZero` | Added (new file) | `Tests/CoreTests/InvoiceLaunchTitlesPageTests.swift` · `b0165a252` |
| `QuestifyCoreTests/InvoiceLaunchTitlesPageTests/testRefreshKeepsAKnownListInsteadOfReplacingItWithZero` | Added (new file) | `Tests/CoreTests/InvoiceLaunchTitlesPageTests.swift` · `b0165a252` |
| `QuestifyCoreTests/InvoiceLaunchTitlesPageTests/testSignedOutAndUnavailableDoNotInventAZeroCount` | Added (new file) | `Tests/CoreTests/InvoiceLaunchTitlesPageTests.swift` · `b0165a252` |
| `QuestifyCoreTests/InvoiceLaunchTitlesPageTests/testUnknownCountIsAnEmDashAndALiteralZeroStaysZero` | Added (new file) | `Tests/CoreTests/InvoiceLaunchTitlesPageTests.swift` · `b0165a252` |
| `QuestifyCoreTests/InvoiceLaunchTitlesPageTests/testUnknownSaveKeepsAKnownCountAndBlocksEditsButNotAConfirmedDelete` | Added (new file) | `Tests/CoreTests/InvoiceLaunchTitlesPageTests.swift` · `b0165a252` |
| `QuestifyCoreTests/JourneyLoopSourceTests/testIdQueryDropsEmptyZeroAndNullAndKeepsOrder` | Added (new file) | `Tests/CoreTests/JourneyLoopSourceTests.swift` · `ba7cb6e0c` |
| `QuestifyCoreTests/JourneyLoopSourceTests/testJourneyCasesMatchTheMiniProgramExportsAndMoneyStaysOff` | Added (new file) | `Tests/CoreTests/JourneyLoopSourceTests.swift` · `ba7cb6e0c` |
| `QuestifyCoreTests/JourneyLoopSourceTests/testMoneyWritesAndBadIdsSendNothing` | Added (new file) | `Tests/CoreTests/JourneyLoopSourceTests.swift` · `ba7cb6e0c` |
| `QuestifyCoreTests/JourneyLoopSourceTests/testProductionHostsAndTheProductionClassAreRefused` | Added (new file) | `Tests/CoreTests/JourneyLoopSourceTests.swift` · `ba7cb6e0c` |
| `QuestifyCoreTests/JourneyLoopSourceTests/testReadsUseTheJourneyPathsAndDoNotSendDroppedIds` | Added (new file) | `Tests/CoreTests/JourneyLoopSourceTests.swift` · `ba7cb6e0c` |
| `QuestifyCoreTests/JourneyLoopSourceTests/testStringAndNumericSuccessAreOkAndServerErrorsStayUnconfirmed` | Added (new file) | `Tests/CoreTests/JourneyLoopSourceTests.swift` · `ba7cb6e0c` |
| `QuestifyCoreTests/JourneySeatRecoveryTests/testABadRegistrationDoesNotSaveOrSend` | Added (new file) | `Tests/CoreTests/JourneySeatRecoveryTests.swift` · `d85088b19`, `ba7cb6e0c` |
| `QuestifyCoreTests/JourneySeatRecoveryTests/testCancelUsesTheSavedIdInThePathAndBody` | Added (new file) | `Tests/CoreTests/JourneySeatRecoveryTests.swift` · `d85088b19`, `ba7cb6e0c` |
| `QuestifyCoreTests/JourneySeatRecoveryTests/testClaimKeyUsesTheLastTwentyFourCharacters` | Added (new file) | `Tests/CoreTests/JourneySeatRecoveryTests.swift` · `d85088b19`, `ba7cb6e0c` |
| `QuestifyCoreTests/JourneySeatRecoveryTests/testInviteSavesTheRequestIdBeforeSendAndClearsItWhenTheServerAnswers` | Added (new file) | `Tests/CoreTests/JourneySeatRecoveryTests.swift` · `d85088b19`, `ba7cb6e0c` |
| `QuestifyCoreTests/JourneySeatRecoveryTests/testRereadWithoutASavedIdSendsNothing` | Added (new file) | `Tests/CoreTests/JourneySeatRecoveryTests.swift` · `d85088b19`, `ba7cb6e0c` |
| `QuestifyCoreTests/JourneySeatRecoveryTests/testTransportFailureKeepsTheIdAndAConflictClearsIt` | Added (new file) | `Tests/CoreTests/JourneySeatRecoveryTests.swift` · `d85088b19`, `ba7cb6e0c` |
| `QuestifyCoreTests/JourneySeatRecoveryTests/testUnconfirmedInviteKeepsTheIdAndTheRereadPostsThatSameId` | Added (new file) | `Tests/CoreTests/JourneySeatRecoveryTests.swift` · `d85088b19`, `ba7cb6e0c` |
| `QuestifyCoreTests/MarketingOriginalSettingsJourneyTests/testShezhiMarketingIndexPageReadsLoadedStateWithoutAnotherRequest` | Added (existing file) | `Tests/CoreTests/MarketingOriginalSettingsJourneyTests.swift` · `2aee69a86` |
| `QuestifyCoreTests/ShezhiMarketingIndexPageTests/testListRouteStaysTheExistingLiveContractAndResultStaysUnmarked` | Added (existing file) | `Tests/CoreTests/MarketingOriginalSettingsJourneyTests.swift` · `2aee69a86` |
| `QuestifyCoreTests/ShezhiMarketingIndexPageTests/testPhasesKeepUnknownCountsAsEmDashAndLoadedEmptyAsZero` | Added (existing file) | `Tests/CoreTests/MarketingOriginalSettingsJourneyTests.swift` · `2aee69a86` |
| `QuestifyCoreTests/ShezhiMarketingIndexPageTests/testReceiptUnknownIdentifiersStayEmDashAndLiteralZeroRequestIdStays` | Added (existing file) | `Tests/CoreTests/MarketingOriginalSettingsJourneyTests.swift` · `2aee69a86` |
| `QuestifyCoreTests/ShezhiMarketingIndexPageTests/testUnknownQuantityIsEmDashNeverZero` | Added (existing file) | `Tests/CoreTests/MarketingOriginalSettingsJourneyTests.swift` · `2aee69a86` |
| `QuestifyCoreTests/MemberHomePageReadyTests/testCapturedUserInfoKeepsLiteralZeros` | Added (new file) | `Tests/CoreTests/MemberHomePageReadyTests.swift` · `4ce602883`, `dd579e03d`, `1f0f33b4f`, `d85088b19`, `89f841a26` (+1 more) |
| `QuestifyCoreTests/MemberHomePageReadyTests/testCountersComeFromUserInfoWhenTheSessionReadHasNone` | Added (new file) | `Tests/CoreTests/MemberHomePageReadyTests.swift` · `4ce602883`, `dd579e03d`, `1f0f33b4f`, `d85088b19`, `89f841a26` (+1 more) |
| `QuestifyCoreTests/MemberHomePageReadyTests/testIdentityEnvelopeStatesDoNotInventNumbers` | Added (new file) | `Tests/CoreTests/MemberHomePageReadyTests.swift` · `4ce602883`, `dd579e03d`, `1f0f33b4f`, `d85088b19`, `89f841a26` (+1 more) |
| `QuestifyCoreTests/MemberHomePageReadyTests/testPageReadsUseTheExistingRoutesOnly` | Added (new file) | `Tests/CoreTests/MemberHomePageReadyTests.swift` · `4ce602883`, `dd579e03d`, `1f0f33b4f`, `d85088b19`, `89f841a26` (+1 more) |
| `QuestifyCoreTests/MemberHomePageReadyTests/testReaderKeepsBenefitsHiddenUntilApprovalAndExpiresUnauthorized` | Added (new file) | `Tests/CoreTests/MemberHomePageReadyTests.swift` · `4ce602883`, `dd579e03d`, `1f0f33b4f`, `d85088b19`, `89f841a26` (+1 more) |
| `QuestifyCoreTests/MemberHomePageReadyTests/testRoleInfoEmptyUnknownAndMoneyWritesStayOff` | Added (new file) | `Tests/CoreTests/MemberHomePageReadyTests.swift` · `4ce602883`, `dd579e03d`, `1f0f33b4f`, `d85088b19`, `89f841a26` (+1 more) |
| `QuestifyCoreTests/MemberHomePageReadyTests/testUnknownCountIsAnEmDashAndSourceIntegerStaysZero` | Added (new file) | `Tests/CoreTests/MemberHomePageReadyTests.swift` · `4ce602883`, `dd579e03d`, `1f0f33b4f`, `d85088b19`, `89f841a26` (+1 more) |
| `QuestifyCoreTests/MemberHomePageReadyTests/testUserInfoUnderAppUserLoadsTheIdentityCard` | Added (new file) | `Tests/CoreTests/MemberHomePageReadyTests.swift` · `4ce602883`, `dd579e03d`, `1f0f33b4f`, `d85088b19`, `89f841a26` (+1 more) |
| `QuestifyCoreTests/MerchantGameNodeCoordinatorTests/testUnconfiguredOriginalReceiptFailsBeforeAnyRequest` | Added (existing file) | `Tests/CoreTests/MerchantGameNodeTests.swift` · `51c876d43` |
| `QuestifyCoreTests/MerchantGameNodeCoordinatorTests/testUnknownWriteStaysLockedWhenOriginalReceiptIsNotConfigured` | Added (existing file) | `Tests/CoreTests/MerchantGameNodeTests.swift` · `51c876d43` |
| `QuestifyCoreTests/MerchantOpsWp03ClientTests/testCatalogNamesEveryRoute` | Added (new file) | `Tests/CoreTests/MerchantOpsWp03ClientTests.swift` · `0b309ba6e` |
| `QuestifyCoreTests/MerchantOpsWp03ClientTests/testCommerceOrderStaysUnsentWhenMoneyIsClosed` | Added (new file) | `Tests/CoreTests/MerchantOpsWp03ClientTests.swift` · `0b309ba6e` |
| `QuestifyCoreTests/MerchantOpsWp03ClientTests/testMerchantWriteIsWithheldUntilTheSwitchOpens` | Added (new file) | `Tests/CoreTests/MerchantOpsWp03ClientTests.swift` · `0b309ba6e` |
| `QuestifyCoreTests/MerchantOpsWp03ClientTests/testReadsAreAdmittedAndUnknownStaysAnEmDash` | Added (new file) | `Tests/CoreTests/MerchantOpsWp03ClientTests.swift` · `0b309ba6e` |
| `QuestifyCoreTests/MessagingContractTests/testBroadcastClickUsesTheInAppCardId` | Added (existing file) | `Tests/CoreTests/MessagingContractTests.swift` · `ecd49f611`, `d6c0c362f` |
| `QuestifyCoreTests/MessagingSessionTests/testBroadcastClickUsesTheLiveSessionAndIgnoresFailure` | Added (existing file) | `Tests/CoreTests/MessagingSessionTests.swift` · `ecd49f611` |
| `QuestifyCoreTests/MiniCropSessionTests/testCropPageReadyConfirmsLocallyAndDoesNotMarkARouteOrUpload` | Added (existing file) | `Tests/CoreTests/MiniCropSessionTests.swift` · `e60225394` |
| `QuestifyCoreTests/MiniCropSessionTests/testCropPageSessionUnsetFrameIsLoadingAndAMeasuredZeroFrameIsError` | Added (existing file) | `Tests/CoreTests/MiniCropSessionTests.swift` · `e60225394` |
| `QuestifyCoreTests/MiniCropSessionTests/testCropPageUnknownStaysAnEmDashAndALiteralZeroStaysZero` | Added (existing file) | `Tests/CoreTests/MiniCropSessionTests.swift` · `e60225394` |
| `QuestifyCoreTests/MiniCropSessionTests/testCropPageWaitingAndEmptyDoNotInventAZeroCount` | Added (existing file) | `Tests/CoreTests/MiniCropSessionTests.swift` · `e60225394` |
| `QuestifyCoreTests/MiniProgramPageLinkTests/testCheinMiniProgramURLOpensEveryPage` | Added (new file) | `Tests/CoreTests/MiniProgramPageLinkTests.swift` · `10d2596e8` |
| `QuestifyCoreTests/MiniProgramPageLinkTests/testEmptyValuesAreAbsent` | Added (new file) | `Tests/CoreTests/MiniProgramPageLinkTests.swift` · `10d2596e8` |
| `QuestifyCoreTests/MiniProgramPageLinkTests/testInternalPathAndPushTapOpenEveryPage` | Added (new file) | `Tests/CoreTests/MiniProgramPageLinkTests.swift` · `10d2596e8` |
| `QuestifyCoreTests/MiniProgramPageLinkTests/testJourneyIntakeOpensTheLandingPage` | Added (new file) | `Tests/CoreTests/MiniProgramPageLinkTests.swift` · `10d2596e8` |
| `QuestifyCoreTests/MiniProgramPageLinkTests/testRejectsUnknownPagesKeysAndValues` | Added (new file) | `Tests/CoreTests/MiniProgramPageLinkTests.swift` · `10d2596e8` |
| `QuestifyCoreTests/MiniProgramPageLinkTests/testTableCoversEveryReviewedPage` | Added (new file) | `Tests/CoreTests/MiniProgramPageLinkTests.swift` · `10d2596e8` |
| `QuestifyCoreTests/MiniProgramPageLinkTests/testVerifiedUniversalLinkOpensEveryPage` | Added (new file) | `Tests/CoreTests/MiniProgramPageLinkTests.swift` · `10d2596e8` |
| `QuestifyCoreTests/MiniProgramPagesTests/testBadIdOrUnknownPageIsUnsupportedNeverTyped` | Added (new file) | `Tests/CoreTests/MiniProgramPagesTests.swift` · `f50793db0` |
| `QuestifyCoreTests/MiniProgramPagesTests/testEveryPageRoundTripsThroughItsPath` | Added (new file) | `Tests/CoreTests/MiniProgramPagesTests.swift` · `f50793db0` |
| `QuestifyCoreTests/MiniProgramPagesTests/testHomeFeedBridgeRoundTripsAndRouteIsCodable` | Added (new file) | `Tests/CoreTests/MiniProgramPagesTests.swift` · `f50793db0` |
| `QuestifyCoreTests/MiniProgramPagesTests/testNativeContentSourcePathsAreInTheTableAndTyped` | Added (new file) | `Tests/CoreTests/MiniProgramPagesTests.swift` · `f50793db0` |
| `QuestifyCoreTests/MiniProgramPagesTests/testUntypedKnownPageIsUnsupportedWithBarePath` | Added (new file) | `Tests/CoreTests/MiniProgramPagesTests.swift` · `f50793db0` |
| `QuestifyCoreTests/MyProjectPageReadyTests/testFailureClearsRowsAndCancellationStaysLoading` | Added (new file) | `Tests/CoreTests/MyProjectPageReadyTests.swift` · `714e8566b` |
| `QuestifyCoreTests/MyProjectPageReadyTests/testFixtureReadyEmptyAndUnknownCounts` | Added (new file) | `Tests/CoreTests/MyProjectPageReadyTests.swift` · `714e8566b` |
| `QuestifyCoreTests/MyProjectPageReadyTests/testLiteralZeroStaysZeroAndNegativeStaysLiteral` | Added (new file) | `Tests/CoreTests/MyProjectPageReadyTests.swift` · `714e8566b` |
| `QuestifyCoreTests/MyProjectPageReadyTests/testLoadingIsVisibleAndInvalidQueryDoesNotRead` | Added (new file) | `Tests/CoreTests/MyProjectPageReadyTests.swift` · `714e8566b` |
| `QuestifyCoreTests/MyProjectPageReadyTests/testMissingAndNullCountsAreUnknownEmDashNotZero` | Added (new file) | `Tests/CoreTests/MyProjectPageReadyTests.swift` · `714e8566b` |
| `QuestifyCoreTests/MyProjectPageReadyTests/testPageAccessibilityIdentifiers` | Added (new file) | `Tests/CoreTests/MyProjectPageReadyTests.swift` · `714e8566b` |
| `QuestifyCoreTests/MyProjectPageReadyTests/testSignedOutAndUnconfiguredDoNotRead` | Added (new file) | `Tests/CoreTests/MyProjectPageReadyTests.swift` · `714e8566b` |
| `QuestifyCoreTests/MyProjectPageReadyTests/testTemplateTabStaysUnknownAndDoesNotReadProjects` | Added (new file) | `Tests/CoreTests/MyProjectPageReadyTests.swift` · `714e8566b` |
| `QuestifyCoreTests/MyProjectPageReadyTests/testWrongCountTypeStillFailsTheRow` | Added (new file) | `Tests/CoreTests/MyProjectPageReadyTests.swift` · `714e8566b` |
| `QuestifyCoreTests/NearbyMerchantPageTests/testDistanceKeepsMeterSuffixAndALiteralZeroStaysZero` | Added (new file) | `Tests/CoreTests/NearbyMerchantPageTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/NearbyMerchantPageTests/testPhaseMappingKeepsRecoverableLocationStatesApart` | Added (new file) | `Tests/CoreTests/NearbyMerchantPageTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/NearbyMerchantPageTests/testPublicHomeOnlyForRegisteredAndPhoneOnlyForCallableLeads` | Added (new file) | `Tests/CoreTests/NearbyMerchantPageTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/NearbyMerchantPageTests/testStaleRowsAreNotShownOutsideAReadyRead` | Added (new file) | `Tests/CoreTests/NearbyMerchantPageTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/NearbyMerchantPageTests/testTotalIsAnEmDashUntilALoadedReadAndZeroOnlyForALoadedEmptyRead` | Added (new file) | `Tests/CoreTests/NearbyMerchantPageTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/OPTTriageClosureTests/testAISafetyCitesOWNOPT080` | Added (new file) | `Tests/CoreTests/OPTTriageClosureTests.swift` · `63d7ce252`, `06c33805b`, `dc546dba1` |
| `QuestifyCoreTests/OPTTriageClosureTests/testAuthorDraftCitesOWNOPT030` | Added (new file) | `Tests/CoreTests/OPTTriageClosureTests.swift` · `63d7ce252`, `06c33805b`, `dc546dba1` |
| `QuestifyCoreTests/OPTTriageClosureTests/testAuthorModerationCitesOWNOPT021` | Added (new file) | `Tests/CoreTests/OPTTriageClosureTests.swift` · `63d7ce252`, `06c33805b`, `dc546dba1` |
| `QuestifyCoreTests/OPTTriageClosureTests/testBroadcastTodosCitesOWNOPT053` | Added (new file) | `Tests/CoreTests/OPTTriageClosureTests.swift` · `63d7ce252`, `06c33805b`, `dc546dba1` |
| `QuestifyCoreTests/OPTTriageClosureTests/testBusinessDashboardCitesOWNOPT061` | Added (new file) | `Tests/CoreTests/OPTTriageClosureTests.swift` · `63d7ce252`, `06c33805b`, `dc546dba1` |
| `QuestifyCoreTests/OPTTriageClosureTests/testCartCallSiteAbsenceCitesOWNOPT011` | Added (new file) | `Tests/CoreTests/OPTTriageClosureTests.swift` · `63d7ce252`, `06c33805b`, `dc546dba1` |
| `QuestifyCoreTests/OPTTriageClosureTests/testCommunityChainCitesOWNOPT020` | Added (new file) | `Tests/CoreTests/OPTTriageClosureTests.swift` · `63d7ce252`, `06c33805b`, `dc546dba1` |
| `QuestifyCoreTests/OPTTriageClosureTests/testContentChainSwitchAbsenceCitesOWNOPT023` | Added (new file) | `Tests/CoreTests/OPTTriageClosureTests.swift` · `63d7ce252`, `06c33805b`, `dc546dba1` |
| `QuestifyCoreTests/OPTTriageClosureTests/testCreatorRevenueCitesOWNOPT033` | Added (new file) | `Tests/CoreTests/OPTTriageClosureTests.swift` · `63d7ce252`, `06c33805b`, `dc546dba1` |
| `QuestifyCoreTests/OPTTriageClosureTests/testDecisionListCitesOWNOPT003` | Added (new file) | `Tests/CoreTests/OPTTriageClosureTests.swift` · `63d7ce252`, `06c33805b`, `dc546dba1` |
| `QuestifyCoreTests/OPTTriageClosureTests/testDuesAbsenceCitesOWNOPT050` | Added (new file) | `Tests/CoreTests/OPTTriageClosureTests.swift` · `63d7ce252`, `06c33805b`, `dc546dba1` |
| `QuestifyCoreTests/OPTTriageClosureTests/testEndingConfigCitesOWNOPT031` | Added (new file) | `Tests/CoreTests/OPTTriageClosureTests.swift` · `63d7ce252`, `06c33805b`, `dc546dba1` |
| `QuestifyCoreTests/OPTTriageClosureTests/testEnvironmentGatesCitesOWNOPT071` | Added (new file) | `Tests/CoreTests/OPTTriageClosureTests.swift` · `63d7ce252`, `06c33805b`, `dc546dba1` |
| `QuestifyCoreTests/OPTTriageClosureTests/testGPSAccuracyCitesOWNOPT041` | Added (new file) | `Tests/CoreTests/OPTTriageClosureTests.swift` · `63d7ce252`, `06c33805b`, `dc546dba1` |
| `QuestifyCoreTests/OPTTriageClosureTests/testLegacyLeadReviewAbsenceCitesOWNOPT002` | Added (new file) | `Tests/CoreTests/OPTTriageClosureTests.swift` · `63d7ce252`, `06c33805b`, `dc546dba1` |
| `QuestifyCoreTests/OPTTriageClosureTests/testMerchantPayableCitesOWNOPT013` | Added (new file) | `Tests/CoreTests/OPTTriageClosureTests.swift` · `63d7ce252`, `06c33805b`, `dc546dba1` |
| `QuestifyCoreTests/OPTTriageClosureTests/testNPCDataCitesOWNOPT081` | Added (new file) | `Tests/CoreTests/OPTTriageClosureTests.swift` · `63d7ce252`, `06c33805b`, `dc546dba1` |
| `QuestifyCoreTests/OPTTriageClosureTests/testOfficialActivityCitesOWNOPT051` | Added (new file) | `Tests/CoreTests/OPTTriageClosureTests.swift` · `63d7ce252`, `06c33805b`, `dc546dba1` |
| `QuestifyCoreTests/OPTTriageClosureTests/testPlayerRefundCitesOWNOPT012` | Added (new file) | `Tests/CoreTests/OPTTriageClosureTests.swift` · `63d7ce252`, `06c33805b`, `dc546dba1` |
| `QuestifyCoreTests/OPTTriageClosureTests/testRequestReceiptCitesOWNOPT070` | Added (new file) | `Tests/CoreTests/OPTTriageClosureTests.swift` · `63d7ce252`, `06c33805b`, `dc546dba1` |
| `QuestifyCoreTests/OPTTriageClosureTests/testSourceBaselineCitesOWNOPT001` | Added (new file) | `Tests/CoreTests/OPTTriageClosureTests.swift` · `63d7ce252`, `06c33805b`, `dc546dba1` |
| `QuestifyCoreTests/OPTTriageClosureTests/testUnknownResultCitesOWNOPT040` | Added (new file) | `Tests/CoreTests/OPTTriageClosureTests.swift` · `63d7ce252`, `06c33805b`, `dc546dba1` |
| `QuestifyCoreTests/ObjectBadge3DPreviewTests/testAnotherIntentStaysHidden` | Added (new file) | `Tests/CoreTests/ObjectBadge3DPreviewTests.swift` · `d63e66aed` |
| `QuestifyCoreTests/ObjectBadge3DPreviewTests/testEmptyRoutePublishesNoNumber` | Added (new file) | `Tests/CoreTests/ObjectBadge3DPreviewTests.swift` · `d63e66aed` |
| `QuestifyCoreTests/ObjectBadge3DPreviewTests/testExplicitZeroStaysZeroAndMissingRarityIsTheEmDash` | Added (new file) | `Tests/CoreTests/ObjectBadge3DPreviewTests.swift` · `d63e66aed` |
| `QuestifyCoreTests/ObjectBadge3DPreviewTests/testFallbackClockUsesRecordedDurationsAndUnknownElapsedIsTheEmDash` | Added (new file) | `Tests/CoreTests/ObjectBadge3DPreviewTests.swift` · `d63e66aed` |
| `QuestifyCoreTests/ObjectBadge3DPreviewTests/testGlyphQueryStaysOffTheLiveRouteAndInAppParametersStillCarryIt` | Added (new file) | `Tests/CoreTests/ObjectBadge3DPreviewTests.swift` · `d63e66aed` |
| `QuestifyCoreTests/ObjectBadge3DPreviewTests/testLoadingDoesNotReadALaterRarity` | Added (new file) | `Tests/CoreTests/ObjectBadge3DPreviewTests.swift` · `d63e66aed` |
| `QuestifyCoreTests/ObjectBadge3DPreviewTests/testNoncanonicalRarityDoesNotBecomeZeroOrAClampedGuess` | Added (new file) | `Tests/CoreTests/ObjectBadge3DPreviewTests.swift` · `d63e66aed` |
| `QuestifyCoreTests/ObjectBadge3DPreviewTests/testReadyRouteKeepsTheExistingQueryContractAndHidesAMesh` | Added (new file) | `Tests/CoreTests/ObjectBadge3DPreviewTests.swift` · `d63e66aed` |
| `QuestifyCoreTests/ObjectBadge3DPreviewTests/testSessionMismatchAndMalformedLinksAreErrorsWithoutANumber` | Added (new file) | `Tests/CoreTests/ObjectBadge3DPreviewTests.swift` · `d63e66aed` |
| `QuestifyCoreTests/ObjectBadge3DPreviewTests/testSubtitleOnlyIsUnknownAndUsesTheDetailTitle` | Added (new file) | `Tests/CoreTests/ObjectBadge3DPreviewTests.swift` · `d63e66aed` |
| `QuestifyCoreTests/ObjectBadge3DPreviewTests/testUnsafeImageIsDroppedAndReducedMotionUsesTheStaticHint` | Added (new file) | `Tests/CoreTests/ObjectBadge3DPreviewTests.swift` · `d63e66aed` |
| `QuestifyCoreTests/ObjectBadgeWallPageStateTests/testAccountChangeDropsTheLateWall` | Added (new file) | `Tests/CoreTests/ObjectBadgeWallPageStateTests.swift` · `107ad8663` |
| `QuestifyCoreTests/ObjectBadgeWallPageStateTests/testCancellationDoesNotBecomeErrorOrZero` | Added (new file) | `Tests/CoreTests/ObjectBadgeWallPageStateTests.swift` · `107ad8663` |
| `QuestifyCoreTests/ObjectBadgeWallPageStateTests/testConfiguredEmptyReadIsEmptyAndAFailedReadIsNot` | Added (new file) | `Tests/CoreTests/ObjectBadgeWallPageStateTests.swift` · `107ad8663` |
| `QuestifyCoreTests/ObjectBadgeWallPageStateTests/testEmptyWallIsKnownZero` | Added (new file) | `Tests/CoreTests/ObjectBadgeWallPageStateTests.swift` · `107ad8663` |
| `QuestifyCoreTests/ObjectBadgeWallPageStateTests/testFailureKindsStayDistinctFromEmpty` | Added (new file) | `Tests/CoreTests/ObjectBadgeWallPageStateTests.swift` · `107ad8663` |
| `QuestifyCoreTests/ObjectBadgeWallPageStateTests/testFixtureDataProjectsReadyEmptyAndUnknown` | Added (new file) | `Tests/CoreTests/ObjectBadgeWallPageStateTests.swift` · `107ad8663` |
| `QuestifyCoreTests/ObjectBadgeWallPageStateTests/testLoadingHiddenAndErrorDoNotShowZero` | Added (new file) | `Tests/CoreTests/ObjectBadgeWallPageStateTests.swift` · `107ad8663` |
| `QuestifyCoreTests/ObjectBadgeWallPageStateTests/testMissingMedalCollectionIsUnknownEvenWithoutIdentityCards` | Added (new file) | `Tests/CoreTests/ObjectBadgeWallPageStateTests.swift` · `107ad8663` |
| `QuestifyCoreTests/ObjectBadgeWallPageStateTests/testNotConfiguredResultStaysHidden` | Added (new file) | `Tests/CoreTests/ObjectBadgeWallPageStateTests.swift` · `107ad8663` |
| `QuestifyCoreTests/ObjectBadgeWallPageStateTests/testOlderReadCannotReplaceANewerLoad` | Added (new file) | `Tests/CoreTests/ObjectBadgeWallPageStateTests.swift` · `107ad8663` |
| `QuestifyCoreTests/ObjectBadgeWallPageStateTests/testReadyWallKeepsLitOrderAndLiteralZeroWaiting` | Added (new file) | `Tests/CoreTests/ObjectBadgeWallPageStateTests.swift` · `107ad8663` |
| `QuestifyCoreTests/ObjectBadgeWallPageStateTests/testSignedOutAndUnconfiguredStayHiddenWithoutReading` | Added (new file) | `Tests/CoreTests/ObjectBadgeWallPageStateTests.swift` · `107ad8663` |
| `QuestifyCoreTests/ObjectCardTests/testAlbumPhasesCoverLoadingEmptyErrorAndUnknown` | Added (existing file) | `Tests/CoreTests/ObjectCardTests.swift` · `d85088b19`, `486e247ee` |
| `QuestifyCoreTests/ObjectCardTests/testListContractKeepsKnownZeroAndRejectsAWithheldTotal` | Added (existing file) | `Tests/CoreTests/ObjectCardTests.swift` · `d85088b19`, `486e247ee` |
| `QuestifyCoreTests/ObjectCardTests/testListedTotalFactIsEmDashOrLiteralZero` | Added (existing file) | `Tests/CoreTests/ObjectCardTests.swift` · `d85088b19`, `486e247ee` |
| `QuestifyCoreTests/ObjectCardTests/testSessionListWiringKeepsUnknownOffTheCountedCollection` | Added (existing file) | `Tests/CoreTests/ObjectCardTests.swift` · `d85088b19`, `486e247ee` |
| `QuestifyCoreTests/OfficialEventDetailPresentationTests/testDetailPageStateKeepsLoadingEmptyErrorAndUnknownOffZero` | Added (existing file) | `Tests/CoreTests/OfficialEventDetailPresentationTests.swift` · `773af19aa`, `e581fdcee` |
| `QuestifyCoreTests/OfficialEventDetailPresentationTests/testMissingCountsStayDashAndLiteralZeroStaysZero` | Added (existing file) | `Tests/CoreTests/OfficialEventDetailPresentationTests.swift` · `773af19aa`, `e581fdcee` |
| `QuestifyCoreTests/OfficialEventTests/testActivityListPageStatesKeepUnknownCountsAsEmDash` | Added (existing file) | `Tests/CoreTests/OfficialEventTests.swift` · `773af19aa` |
| `QuestifyCoreTests/OfficialInboxPageReadyTests/testCapacityUnknownIsAnEmDashAndLiteralZeroStaysZero` | Added (new file) | `Tests/CoreTests/OfficialInboxPageReadyTests.swift` · `2ea1db2c8`, `773af19aa` |
| `QuestifyCoreTests/OfficialInboxPageReadyTests/testDebugFixtureDataDecodesWithoutInventingACount` | Added (new file) | `Tests/CoreTests/OfficialInboxPageReadyTests.swift` · `2ea1db2c8`, `773af19aa` |
| `QuestifyCoreTests/OfficialInboxPageReadyTests/testExistingPartyInboxRouteStaysVisibleAndMissingRoutesStayHidden` | Added (new file) | `Tests/CoreTests/OfficialInboxPageReadyTests.swift` · `2ea1db2c8`, `773af19aa` |
| `QuestifyCoreTests/OfficialInboxPageReadyTests/testLoadingEmptyErrorAndUnknownNeverGuessACount` | Added (new file) | `Tests/CoreTests/OfficialInboxPageReadyTests.swift` · `2ea1db2c8`, `773af19aa` |
| `QuestifyCoreTests/OfficialMinePageModelTests/testANewerReloadDropsTheOlderPayload` | Added (new file) | `Tests/CoreTests/OfficialMinePageModelTests.swift` · `773af19aa` |
| `QuestifyCoreTests/OfficialMinePageModelTests/testCoordinatorHidesPublishUntilCanPublishAndSkipsOtherReads` | Added (new file) | `Tests/CoreTests/OfficialMinePageModelTests.swift` · `773af19aa` |
| `QuestifyCoreTests/OfficialMinePageModelTests/testDebugFixtureDataKeepsUnknownReachAsAnEmDash` | Added (new file) | `Tests/CoreTests/OfficialMinePageModelTests.swift` · `773af19aa` |
| `QuestifyCoreTests/OfficialMinePageModelTests/testKnownEmptyIsZeroAndMalformedPayloadStaysUnknown` | Added (new file) | `Tests/CoreTests/OfficialMinePageModelTests.swift` · `773af19aa` |
| `QuestifyCoreTests/OfficialMinePageModelTests/testMissingSessionDoesNotReadAndUnreadableBodyIsNotZero` | Added (new file) | `Tests/CoreTests/OfficialMinePageModelTests.swift` · `773af19aa` |
| `QuestifyCoreTests/OfficialMinePageModelTests/testUnknownCountIsAnEmDashAndNeverAGuessedZero` | Added (new file) | `Tests/CoreTests/OfficialMinePageModelTests.swift` · `773af19aa` |
| `QuestifyCoreTests/OfficialMinePageModelTests/testVisibleRowsKeepServerNumbersAndDropIncompleteOnes` | Added (new file) | `Tests/CoreTests/OfficialMinePageModelTests.swift` · `773af19aa` |
| `QuestifyCoreTests/OfficialOrganizerConsoleFixtureTests/testFixtureBytesUseTheExistingPublishCheckAndDoNotOpenAPlayerEntry` | Added (existing file) | `Tests/CoreTests/OfficialOrganizerTests.swift` · `773af19aa` |
| `QuestifyCoreTests/OfficialOrganizerConsoleStateTests/testDisabledCapabilityStaysHiddenOffThePlayerEntry` | Added (existing file) | `Tests/CoreTests/OfficialOrganizerTests.swift` · `773af19aa` |
| `QuestifyCoreTests/OfficialOrganizerConsoleStateTests/testLoadingEmptyErrorDeniedUnknownAndReady` | Added (existing file) | `Tests/CoreTests/OfficialOrganizerTests.swift` · `773af19aa` |
| `QuestifyCoreTests/OfficialOrganizerConsoleStateTests/testUnknownCountsStayAnEmDashAndZeroStaysZero` | Added (existing file) | `Tests/CoreTests/OfficialOrganizerTests.swift` · `773af19aa` |
| `QuestifyCoreTests/OfflinePackOperationTests/testExpiredOrForeignUpdateDoesNotCoverVerifiedPack` | Added (existing file) | `Tests/CoreTests/OfflinePackOperationTests.swift` · `f9c5e19c0` |
| `QuestifyCoreTests/OfflinePackOperationTests/testExpiredStartDoesNotOccupyThenLaterManifestCanStart` | Added (existing file) | `Tests/CoreTests/OfflinePackOperationTests.swift` · `f9c5e19c0` |
| `QuestifyCoreTests/OfflinePackOperationTests/testFinishUpdateWithoutBytesDoesNotInstall` | Added (existing file) | `Tests/CoreTests/OfflinePackOperationTests.swift` · `f9c5e19c0` |
| `QuestifyCoreTests/OfflinePackOperationTests/testMismatchedContractAndMissingBytesDoNotFinish` | Added (existing file) | `Tests/CoreTests/OfflinePackOperationTests.swift` · `f9c5e19c0` |
| `QuestifyCoreTests/OfflinePackOperationTests/testMissingChecksumStaysUnverified` | Added (existing file) | `Tests/CoreTests/OfflinePackOperationTests.swift` · `f9c5e19c0` |
| `QuestifyCoreTests/OfflinePackOperationTests/testReadyPackRecordDoesNotCarryServerOutcomes` | Added (existing file) | `Tests/CoreTests/OfflinePackOperationTests.swift` · `f9c5e19c0` |
| `QuestifyCoreTests/OfflinePackOperationTests/testRevisionOrOnlineNotRequiredDoesNotProveFullOfflinePlay` | Added (existing file) | `Tests/CoreTests/OfflinePackOperationTests.swift` · `f9c5e19c0` |
| `QuestifyCoreTests/OrderInfoPageModelTests/testMissingAmountAndTimeAreEmDashesAndALiteralZeroStaysZero` | Added (new file) | `Tests/CoreTests/OrderInfoPageModelTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/OrderInfoPageModelTests/testMoneyWritesStayOff` | Added (new file) | `Tests/CoreTests/OrderInfoPageModelTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/OrderInfoPageModelTests/testNoDetailIsLoadingOrUnknownAndAnotherOrdersDetailIsNotShown` | Added (new file) | `Tests/CoreTests/OrderInfoPageModelTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/OrderInfoPageModelTests/testRefundAmountKeepsMissingApartFromZero` | Added (new file) | `Tests/CoreTests/OrderInfoPageModelTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/OrderInfoPageModelTests/testSignedOutUnconfiguredAndIssueAreErrorsNeverAnEmptyOrder` | Added (new file) | `Tests/CoreTests/OrderInfoPageModelTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/OrderInfoPageModelTests/testUnrecognizedStatusStaysUnknownAndTimelineTimesOnlyShowOnDoneSteps` | Added (new file) | `Tests/CoreTests/OrderInfoPageModelTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/OrientScorePageReadyTests/testLiteralIntegerScoreMatchesTheExistingSummaryIncludingZero` | Added (new file) | `Tests/CoreTests/OrientScorePageReadyTests.swift` · `b46d8ba5f` |
| `QuestifyCoreTests/OrientScorePageReadyTests/testLoadingEmptyErrorAndUnknownStayDistinct` | Added (new file) | `Tests/CoreTests/OrientScorePageReadyTests.swift` · `b46d8ba5f` |
| `QuestifyCoreTests/OrientScorePageReadyTests/testMissingCapabilityStaysHiddenAndDoesNotInventARoute` | Added (new file) | `Tests/CoreTests/OrientScorePageReadyTests.swift` · `b46d8ba5f` |
| `QuestifyCoreTests/OrientScorePageReadyTests/testUnknownScoresAreAnEmDashAndAreNotStoredAsZero` | Added (new file) | `Tests/CoreTests/OrientScorePageReadyTests.swift` · `b46d8ba5f` |
| `QuestifyCoreTests/OrientScoreReviewModelTests/testConfirmedRejectionReleasesTheKeyAndUnknownKeepsIt` | Added (existing file) | `Tests/CoreTests/OrientScoreReviewModelTests.swift` · `268c4c3c8` |
| `QuestifyCoreTests/OrientScoreReviewWriterTests/testAppealSuccessDoesNotRereadOrCallSyncSettlePurchaseOrPayout` | Added (new file) | `Tests/CoreTests/OrientScoreReviewWriterTests.swift` · `268c4c3c8` |
| `QuestifyCoreTests/OrientScoreReviewWriterTests/testClientErrorReleasesTheIdWithoutAReceiptRead` | Added (new file) | `Tests/CoreTests/OrientScoreReviewWriterTests.swift` · `268c4c3c8` |
| `QuestifyCoreTests/OrientScoreReviewWriterTests/testDisputeUsesItsOwnPathAndRefusesAnOpenRound` | Added (new file) | `Tests/CoreTests/OrientScoreReviewWriterTests.swift` · `268c4c3c8` |
| `QuestifyCoreTests/OrientScoreReviewWriterTests/testGrantWithoutTheTwoWritesCannotBeConstructed` | Added (new file) | `Tests/CoreTests/OrientScoreReviewWriterTests.swift` · `268c4c3c8` |
| `QuestifyCoreTests/OrientScoreReviewWriterTests/testMissingEntryDoesNotBuildARequest` | Added (new file) | `Tests/CoreTests/OrientScoreReviewWriterTests.swift` · `268c4c3c8` |
| `QuestifyCoreTests/OrientScoreReviewWriterTests/testServerErrorThenMatchingReceiptIsSuccess` | Added (new file) | `Tests/CoreTests/OrientScoreReviewWriterTests.swift` · `268c4c3c8` |
| `QuestifyCoreTests/OrientScoreReviewWriterTests/testTransportFailureStaysLockedUntilTheReceiptMatches` | Added (new file) | `Tests/CoreTests/OrientScoreReviewWriterTests.swift` · `268c4c3c8` |
| `QuestifyCoreTests/OwnerDecisionGuardTests/testOWND01aListsSpendRulesAndDropsDeleted` | Added (new file) | `Tests/CoreTests/OwnerDecisionGuardTests.swift` · `af74412be`, `9b342c305`, `63d7ce252`, `766f17db2`, `bcdb4d00e` |
| `QuestifyCoreTests/OwnerDecisionGuardTests/testOWND01bTurnsTheToggleOffWithTheRealReason` | Added (new file) | `Tests/CoreTests/OwnerDecisionGuardTests.swift` · `af74412be`, `9b342c305`, `63d7ce252`, `766f17db2`, `bcdb4d00e` |
| `QuestifyCoreTests/OwnerDecisionGuardTests/testOWND01cShowsTheSnapshotAndHasNoClientRateLiteral` | Added (new file) | `Tests/CoreTests/OwnerDecisionGuardTests.swift` · `af74412be`, `9b342c305`, `63d7ce252`, `766f17db2`, `bcdb4d00e` |
| `QuestifyCoreTests/OwnerDecisionGuardTests/testOWND02HasNoDuesRouteOrScreen` | Added (new file) | `Tests/CoreTests/OwnerDecisionGuardTests.swift` · `af74412be`, `9b342c305`, `63d7ce252`, `766f17db2`, `bcdb4d00e` |
| `QuestifyCoreTests/OwnerDecisionGuardTests/testOWND03aMapsEachSurfaceToItsChain` | Added (new file) | `Tests/CoreTests/OwnerDecisionGuardTests.swift` · `af74412be`, `9b342c305`, `63d7ce252`, `766f17db2`, `bcdb4d00e` |
| `QuestifyCoreTests/OwnerDecisionGuardTests/testOWND03bDoesNotFlipASurfaceBetweenChains` | Added (new file) | `Tests/CoreTests/OwnerDecisionGuardTests.swift` · `af74412be`, `9b342c305`, `63d7ce252`, `766f17db2`, `bcdb4d00e` |
| `QuestifyCoreTests/OwnerDecisionGuardTests/testOWND04RendersServerFragmentsInOrder` | Added (new file) | `Tests/CoreTests/OwnerDecisionGuardTests.swift` · `af74412be`, `9b342c305`, `63d7ce252`, `766f17db2`, `bcdb4d00e` |
| `QuestifyCoreTests/OwnerDecisionGuardTests/testOWND05aStatusAndUnbindWithoutANativeBind` | Added (new file) | `Tests/CoreTests/OwnerDecisionGuardTests.swift` · `af74412be`, `9b342c305`, `63d7ce252`, `766f17db2`, `bcdb4d00e` |
| `QuestifyCoreTests/OwnerDecisionGuardTests/testOWND05bMerchantAccountIsReadOnlyBehindFinanceRead` | Added (new file) | `Tests/CoreTests/OwnerDecisionGuardTests.swift` · `af74412be`, `9b342c305`, `63d7ce252`, `766f17db2`, `bcdb4d00e` |
| `QuestifyCoreTests/OwnerDecisionGuardTests/testOWND05cPayoutWritesSendNothingWhileClosedAndProductionRefusesThem` | Added (new file) | `Tests/CoreTests/OwnerDecisionGuardTests.swift` · `af74412be`, `9b342c305`, `63d7ce252`, `766f17db2`, `bcdb4d00e` |
| `QuestifyCoreTests/OwnerDecisionGuardTests/testOWND06PassPurchaseStaysBehindTheCommerceGate` | Added (new file) | `Tests/CoreTests/OwnerDecisionGuardTests.swift` · `af74412be`, `9b342c305`, `63d7ce252`, `766f17db2`, `bcdb4d00e` |
| `QuestifyCoreTests/OwnerDecisionGuardTests/testOWND08aFailedOrIncompleteQuotaShowsUnavailableAndSpendsNothing` | Added (new file) | `Tests/CoreTests/OwnerDecisionGuardTests.swift` · `af74412be`, `9b342c305`, `63d7ce252`, `766f17db2`, `bcdb4d00e` |
| `QuestifyCoreTests/OwnerDecisionGuardTests/testOWND08bLabelsGeneratedStoriesDraftsAndAdoptedAuthors` | Added (new file) | `Tests/CoreTests/OwnerDecisionGuardTests.swift` · `af74412be`, `9b342c305`, `63d7ce252`, `766f17db2`, `bcdb4d00e` |
| `QuestifyCoreTests/OwnerDecisionGuardTests/testOWND08cHasNoLongTermMemoryPaidSlotOrDefaultAI` | Added (new file) | `Tests/CoreTests/OwnerDecisionGuardTests.swift` · `af74412be`, `9b342c305`, `63d7ce252`, `766f17db2`, `bcdb4d00e` |
| `QuestifyCoreTests/OwnerDecisionGuardTests/testOWND10HidesAnEmptyRevenueTabAndDoesNotShowZeroOnFailure` | Added (new file) | `Tests/CoreTests/OwnerDecisionGuardTests.swift` · `af74412be`, `9b342c305`, `63d7ce252`, `766f17db2`, `bcdb4d00e` |
| `QuestifyCoreTests/OwnerDecisionGuardTests/testOWNOPT010CitesThePointsRows` | Added (new file) | `Tests/CoreTests/OwnerDecisionGuardTests.swift` · `af74412be`, `9b342c305`, `63d7ce252`, `766f17db2`, `bcdb4d00e` |
| `QuestifyCoreTests/PWaveCoreTests/testAnotherConfigAndANonColumnTeamSourceStayUnfrozen` | Added (existing file) | `Tests/CoreTests/PWaveCoreTests.swift` · `776df1ac7`, `c1232ba82` |
| `QuestifyCoreTests/PWaveCoreTests/testExpiredGiftDoesNotOfferReclaim` | Added (existing file) | `Tests/CoreTests/PWaveCoreTests.swift` · `776df1ac7`, `c1232ba82` |
| `QuestifyCoreTests/PWaveCoreTests/testFractionalAndBooleanNumbersStayUnknown` | Added (existing file) | `Tests/CoreTests/PWaveCoreTests.swift` · `776df1ac7`, `c1232ba82` |
| `QuestifyCoreTests/PWaveCoreTests/testReferralKeepsAvatarNextActionAndAMissingFreeFlagIsNotFalse` | Added (existing file) | `Tests/CoreTests/PWaveCoreTests.swift` · `776df1ac7`, `c1232ba82` |
| `QuestifyCoreTests/PWaveCoreTests/testReportKeepsPlayInstanceProgressAndDoesNotTreatAnotherElapsedAsKnown` | Added (existing file) | `Tests/CoreTests/PWaveCoreTests.swift` · `776df1ac7`, `c1232ba82` |
| `QuestifyCoreTests/PWaveCoreTests/testSeatDraftsStayUnsentAndASlashIsRejected` | Added (existing file) | `Tests/CoreTests/PWaveCoreTests.swift` · `776df1ac7`, `c1232ba82` |
| `QuestifyCoreTests/PWaveCoreTests/testSeatInvitationRejectsAPathBeforeSending` | Added (existing file) | `Tests/CoreTests/PWaveCoreTests.swift` · `776df1ac7`, `c1232ba82` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testAStaleAccountDropsTheLaterReadAndAFailedReadIsNotZero` | Added (new file) | `Tests/CoreTests/PWaveSecondWaveTests.swift` · `776df1ac7`, `c1232ba82` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testAffiliateCountTextAndUnknownCurrencyDoNotInventATotal` | Added (new file) | `Tests/CoreTests/PWaveSecondWaveTests.swift` · `776df1ac7`, `c1232ba82` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testAffiliateNullHeldAndFalsePayoutAreNotAWithdrawableBalance` | Added (new file) | `Tests/CoreTests/PWaveSecondWaveTests.swift` · `776df1ac7`, `c1232ba82` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testAffiliateStaysHiddenWithoutACapabilityAndDoesNotBecomeAnEmptyZero` | Added (new file) | `Tests/CoreTests/PWaveSecondWaveTests.swift` · `776df1ac7`, `c1232ba82` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testCatalogCardKeepsNamedFieldsAndDropsANonStringSample` | Added (new file) | `Tests/CoreTests/PWaveSecondWaveTests.swift` · `776df1ac7`, `c1232ba82` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testCatalogPathsAndThemeHistoryUseNamedReads` | Added (new file) | `Tests/CoreTests/PWaveSecondWaveTests.swift` · `776df1ac7`, `c1232ba82` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testCatalogRejectsAnUnknownFieldBeforeSending` | Added (new file) | `Tests/CoreTests/PWaveSecondWaveTests.swift` · `776df1ac7`, `c1232ba82` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testCityPassKeepsTheTermAndABadProductIdSendsNothing` | Added (new file) | `Tests/CoreTests/PWaveSecondWaveTests.swift` · `776df1ac7`, `c1232ba82` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testCityPassKeepsUnknownPriceAsAnEmDashAndDoesNotSell` | Added (new file) | `Tests/CoreTests/PWaveSecondWaveTests.swift` · `776df1ac7`, `c1232ba82` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testHistoryEmptyIsEmptyAndAnIntegerSessionIdIsKept` | Added (new file) | `Tests/CoreTests/PWaveSecondWaveTests.swift` · `776df1ac7`, `c1232ba82` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testHistoryKeepsSessionIdsAndDoesNotFillCurrentContent` | Added (new file) | `Tests/CoreTests/PWaveSecondWaveTests.swift` · `776df1ac7`, `c1232ba82` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testLaterOrderAndUnknownNumbersUseAnEmDash` | Added (new file) | `Tests/CoreTests/PWaveSecondWaveTests.swift` · `776df1ac7`, `c1232ba82` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testMemberRankStaysHiddenUntilTheServerSendsIt` | Added (new file) | `Tests/CoreTests/PWaveSecondWaveTests.swift` · `776df1ac7`, `c1232ba82` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testMemoryHidesOtherPhotosAndDoesNotTurnUnknownIntoZero` | Added (new file) | `Tests/CoreTests/PWaveSecondWaveTests.swift` · `776df1ac7`, `c1232ba82` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testMemoryZeroAndPrivateShareStayClosed` | Added (new file) | `Tests/CoreTests/PWaveSecondWaveTests.swift` · `776df1ac7`, `c1232ba82` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testMultipleCurrenciesStayUnsummedAndALiteralAmountCanWithdraw` | Added (new file) | `Tests/CoreTests/PWaveSecondWaveTests.swift` · `776df1ac7`, `c1232ba82` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testQuestRankStaysHiddenUntilTheCompletedNodeBasisAndUnknownIsAnEmDash` | Added (new file) | `Tests/CoreTests/PWaveSecondWaveTests.swift` · `776df1ac7`, `c1232ba82` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testReaderHidesTheLaterWaveUntilTheGrantAndSendsNothing` | Added (new file) | `Tests/CoreTests/PWaveSecondWaveTests.swift` · `776df1ac7`, `c1232ba82` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testReaderUsesTheNamedReadsAndRefusesWrites` | Added (new file) | `Tests/CoreTests/PWaveSecondWaveTests.swift` · `776df1ac7`, `c1232ba82` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testTeamBoardIsNotMemberRankAndStaysHiddenWhenTheSwitchIsOff` | Added (new file) | `Tests/CoreTests/PWaveSecondWaveTests.swift` · `776df1ac7`, `c1232ba82` |
| `QuestifyCoreTests/PWaveSecondWaveTests/testThemeCollectionHidesWithoutCapabilityAndDoesNotPadOrInventProof` | Added (new file) | `Tests/CoreTests/PWaveSecondWaveTests.swift` · `776df1ac7`, `c1232ba82` |
| `QuestifyCoreTests/ParticipantAddressListPageTests/testCardsKeepTheContractPhoneAndDoNotAddContactFields` | Added (new file) | `Tests/CoreTests/ParticipantAddressListPageTests.swift` · `a3cba9cbd` |
| `QuestifyCoreTests/ParticipantAddressListPageTests/testExistingParticipantsReadStillIgnoresAStringTotal` | Added (new file) | `Tests/CoreTests/ParticipantAddressListPageTests.swift` · `a3cba9cbd` |
| `QuestifyCoreTests/ParticipantAddressListPageTests/testLoadingErrorAndUnknownDoNotInventZero` | Added (new file) | `Tests/CoreTests/ParticipantAddressListPageTests.swift` · `a3cba9cbd` |
| `QuestifyCoreTests/ParticipantAddressListPageTests/testMissingAndNullTotalsStayEmDashWhileLiteralZeroStaysZero` | Added (new file) | `Tests/CoreTests/ParticipantAddressListPageTests.swift` · `a3cba9cbd` |
| `QuestifyCoreTests/ParticipantAddressListPageTests/testNumericStringAndNegativeTotalAreRejected` | Added (new file) | `Tests/CoreTests/ParticipantAddressListPageTests.swift` · `a3cba9cbd` |
| `QuestifyCoreTests/ParticipantAddressListPageTests/testOutcomeUnknownClearsTheCountToAnEmDash` | Added (new file) | `Tests/CoreTests/ParticipantAddressListPageTests.swift` · `a3cba9cbd` |
| `QuestifyCoreTests/ParticipantAddressListPageTests/testParticipantListFactsUsesTheExistingListRoute` | Added (new file) | `Tests/CoreTests/ParticipantAddressListPageTests.swift` · `a3cba9cbd` |
| `QuestifyCoreTests/ParticipantAddressListPageTests/testRefreshKeepsAKnownZeroAndAFirstFailureDoesNot` | Added (new file) | `Tests/CoreTests/ParticipantAddressListPageTests.swift` · `a3cba9cbd` |
| `QuestifyCoreTests/ParticipationOrientScoreEntryTests/testActivityIdThatDoesNotMatchOwnerIsDropped` | Added (new file) | `Tests/CoreTests/ParticipationOrientScoreEntryTests.swift` · `d716b2728` |
| `QuestifyCoreTests/ParticipationOrientScoreEntryTests/testActivityRegistrationUsesActivityTopicIdNotZero` | Added (new file) | `Tests/CoreTests/ParticipationOrientScoreEntryTests.swift` · `d716b2728` |
| `QuestifyCoreTests/ParticipationOrientScoreEntryTests/testActivityWithoutTopicIdDoesNotInventOne` | Added (new file) | `Tests/CoreTests/ParticipationOrientScoreEntryTests.swift` · `d716b2728` |
| `QuestifyCoreTests/ParticipationOrientScoreEntryTests/testConflictingTopLevelTopicIdClearsTheTopic` | Added (new file) | `Tests/CoreTests/ParticipationOrientScoreEntryTests.swift` · `d716b2728` |
| `QuestifyCoreTests/ParticipationOrientScoreEntryTests/testMismatchedTopicIdsAreNotRepaired` | Added (new file) | `Tests/CoreTests/ParticipationOrientScoreEntryTests.swift` · `d716b2728` |
| `QuestifyCoreTests/ParticipationOrientScoreEntryTests/testMissingMemberKeepsTheEntryHidden` | Added (new file) | `Tests/CoreTests/ParticipationOrientScoreEntryTests.swift` · `d716b2728` |
| `QuestifyCoreTests/ParticipationOrientScoreEntryTests/testPayloadWithoutIdsLeavesTheLoaderNil` | Added (new file) | `Tests/CoreTests/ParticipationOrientScoreEntryTests.swift` · `d716b2728` |
| `QuestifyCoreTests/ParticipationOrientScoreEntryTests/testProductTypeTwoAndNonIntegersStayOffTheScoreRead` | Added (new file) | `Tests/CoreTests/ParticipationOrientScoreEntryTests.swift` · `d716b2728` |
| `QuestifyCoreTests/ParticipationOrientScoreEntryTests/testRegistrationIdIsNotATopicId` | Added (new file) | `Tests/CoreTests/ParticipationOrientScoreEntryTests.swift` · `d716b2728` |
| `QuestifyCoreTests/ParticipationOrientScoreEntryTests/testStringTopicIdMatchesIntegerOwnerAndStringProductType` | Added (new file) | `Tests/CoreTests/ParticipationOrientScoreEntryTests.swift` · `d716b2728` |
| `QuestifyCoreTests/ParticipationOrientScoreEntryTests/testTopicRegistrationKeepsMatchingTopicAndSelfPlayActivity` | Added (new file) | `Tests/CoreTests/ParticipationOrientScoreEntryTests.swift` · `d716b2728` |
| `QuestifyCoreTests/PassMarketPointsReadsTests/testChinaProductionRefusesWritesAndStillAllowsTheThreeReads` | Added (new file) | `Tests/CoreTests/PassMarketPointsReadsTests.swift` · `a04efe0a4` |
| `QuestifyCoreTests/PassMarketPointsReadsTests/testMissingStatisticsDoNotDecodeAsZero` | Added (new file) | `Tests/CoreTests/PassMarketPointsReadsTests.swift` · `a04efe0a4` |
| `QuestifyCoreTests/PassMarketPointsReadsTests/testTransportForwardsOnlyTheThreePosts` | Added (new file) | `Tests/CoreTests/PassMarketPointsReadsTests.swift` · `a04efe0a4` |
| `QuestifyCoreTests/PassMarketPointsReadsTests/testUnknownAmountIsAnEmDashAndZeroStaysZero` | Added (new file) | `Tests/CoreTests/PassMarketPointsReadsTests.swift` · `a04efe0a4` |
| `QuestifyCoreTests/PassMarketPointsReadsTests/testUserPointsListIsNotTheHistoryPath` | Added (new file) | `Tests/CoreTests/PassMarketPointsReadsTests.swift` · `a04efe0a4` |
| `QuestifyCoreTests/PayoutReceiverClientTests/testChinaProductionRefusesEveryPayoutRouteUntilTheSwitchOpens` | Added (new file) | `Tests/CoreTests/PayoutReceiverClientTests.swift` · `af74412be`, `051e5cde7` |
| `QuestifyCoreTests/PayoutReceiverClientTests/testDirectLedgerTotalsAndFailClosed` | Added (new file) | `Tests/CoreTests/PayoutReceiverClientTests.swift` · `af74412be`, `051e5cde7` |
| `QuestifyCoreTests/PayoutReceiverClientTests/testEveryMoneyWriteIsRefusedOnChinaProductionAndOpensOnlyOffIt` | Added (new file) | `Tests/CoreTests/PayoutReceiverClientTests.swift` · `af74412be`, `051e5cde7` |
| `QuestifyCoreTests/PayoutReceiverClientTests/testEveryRequestMatchesTheMiniProgramShape` | Added (new file) | `Tests/CoreTests/PayoutReceiverClientTests.swift` · `af74412be`, `051e5cde7` |
| `QuestifyCoreTests/PayoutReceiverClientTests/testIssueCopyNeverShowsAMachineCode` | Added (new file) | `Tests/CoreTests/PayoutReceiverClientTests.swift` · `af74412be`, `051e5cde7` |
| `QuestifyCoreTests/PayoutReceiverClientTests/testPaymentReadinessRequestAndDecode` | Added (new file) | `Tests/CoreTests/PayoutReceiverClientTests.swift` · `af74412be`, `051e5cde7` |
| `QuestifyCoreTests/PayoutReceiverClientTests/testPayoutAccountShape` | Added (new file) | `Tests/CoreTests/PayoutReceiverClientTests.swift` · `af74412be`, `051e5cde7` |
| `QuestifyCoreTests/PayoutReceiverClientTests/testPayoutWritesSendNothingWhilePayoutSwitchIsOff` | Added (new file) | `Tests/CoreTests/PayoutReceiverClientTests.swift` · `af74412be`, `051e5cde7` |
| `QuestifyCoreTests/PayoutReceiverClientTests/testSettlementSummaryIsFailClosed` | Added (new file) | `Tests/CoreTests/PayoutReceiverClientTests.swift` · `af74412be`, `051e5cde7` |
| `QuestifyCoreTests/PayoutReceiverClientTests/testStatusShapeFollowsServerFactsOnly` | Added (new file) | `Tests/CoreTests/PayoutReceiverClientTests.swift` · `af74412be`, `051e5cde7` |
| `QuestifyCoreTests/PayoutReceiverClientTests/testTransportRefusesOtherRoutesMethodsAndQueries` | Added (new file) | `Tests/CoreTests/PayoutReceiverClientTests.swift` · `af74412be`, `051e5cde7` |
| `QuestifyCoreTests/PayoutReceiverClientTests/testWorkshopStoreKitEnvironmentAdmitsSandboxOnlyInDebugOrTest` | Added (new file) | `Tests/CoreTests/PayoutReceiverClientTests.swift` · `af74412be`, `051e5cde7` |
| `QuestifyCoreTests/PlatformPassPurchaseUnreachableTests/testPurchaseAndClaimStayUnreachableWhileMoneyIsOff` | Added (new file) | `Tests/CoreTests/PlatformPassPurchaseUnreachableTests.swift` · `ae8a67be3`, `639292585` |
| `QuestifyCoreTests/PlatformPassReadTests/testChinaClockPassUntilRollsMidnightBackOneMillisecond` | Added (new file) | `Tests/CoreTests/PlatformPassReadTests.swift` · `ae8a67be3`, `639292585` |
| `QuestifyCoreTests/PlatformPassReadTests/testMerchantSkipsOverviewAndLibraryAndABadTokenSendsNothing` | Added (new file) | `Tests/CoreTests/PlatformPassReadTests.swift` · `ae8a67be3`, `639292585` |
| `QuestifyCoreTests/PlatformPassReadTests/testReadsOverviewLibraryProductsOrdersGiftsAndPoints` | Added (new file) | `Tests/CoreTests/PlatformPassReadTests.swift` · `ae8a67be3`, `639292585` |
| `QuestifyCoreTests/PlatformPassReadTests/testStringCodeUnknownCountAndZeroPointsStayLiteral` | Added (new file) | `Tests/CoreTests/PlatformPassReadTests.swift` · `ae8a67be3`, `639292585` |
| `QuestifyCoreTests/PlayActionReceiptTests/testConfirmedOriginalReceiptAcknowledgesTheSameNode` | Added (new file) | `Tests/CoreTests/PlayActionReceiptTests.swift` · `b82cbcc40` |
| `QuestifyCoreTests/PlayActionReceiptTests/testIdentityKeepsTheOriginalIdAndRefusesAReplacement` | Added (new file) | `Tests/CoreTests/PlayActionReceiptTests.swift` · `b82cbcc40` |
| `QuestifyCoreTests/PlayActionReceiptTests/testPendingReceiptIsNotARejectionAndAForeignIdIsMalformed` | Added (new file) | `Tests/CoreTests/PlayActionReceiptTests.swift` · `b82cbcc40` |
| `QuestifyCoreTests/PlayActionReceiptTests/testReceiptReadUsesTheOriginalIdAndLeavesCode520Pending` | Added (new file) | `Tests/CoreTests/PlayActionReceiptTests.swift` · `b82cbcc40` |
| `QuestifyCoreTests/PlayActionReceiptTests/testRejectedWriteDoesNotQueryAReceipt` | Added (new file) | `Tests/CoreTests/PlayActionReceiptTests.swift` · `b82cbcc40` |
| `QuestifyCoreTests/PlayActionReceiptTests/testUnknownRetryResubmitsTheSameActionId` | Added (new file) | `Tests/CoreTests/PlayActionReceiptTests.swift` · `b82cbcc40` |
| `QuestifyCoreTests/PlayActionReceiptTests/testUnknownWriteQueriesTheOriginalReceiptAndDoesNotFail` | Added (new file) | `Tests/CoreTests/PlayActionReceiptTests.swift` · `b82cbcc40` |
| `QuestifyCoreTests/PlayAdvancedDurableRecoveryTests/testPreviousProcessDispatchIsSettledByItsOwnReceiptWithoutReplay` | Added (existing file) | `Tests/CoreTests/PlayAdvancedDurableRecoveryTests.swift` · `6adbae522` |
| `QuestifyCoreTests/PlayContractTests/testNullChoiceOptionsAreDroppedNotFatal` | Added (existing file) | `Tests/CoreTests/PlayContractTests.swift` · `c812949c3` |
| `QuestifyCoreTests/PlayCreatorTailRoutesTests/testAppealImagesUploadInOrderAndAFailureDoesNotSubmitEmpty` | Added (new file) | `Tests/CoreTests/PlayCreatorTailRoutesTests.swift` · `ad108e43e`, `c943799a6` |
| `QuestifyCoreTests/PlayCreatorTailRoutesTests/testArrivalRefusalCarriesTheGuardReference` | Added (new file) | `Tests/CoreTests/PlayCreatorTailRoutesTests.swift` · `ad108e43e`, `c943799a6` |
| `QuestifyCoreTests/PlayCreatorTailRoutesTests/testAuditTimelineIsAGetWithBizTypeAndBizId` | Added (new file) | `Tests/CoreTests/PlayCreatorTailRoutesTests.swift` · `ad108e43e`, `c943799a6` |
| `QuestifyCoreTests/PlayCreatorTailRoutesTests/testContentAppealFreezesTheCommandThenConfirmsByItsReceipt` | Added (new file) | `Tests/CoreTests/PlayCreatorTailRoutesTests.swift` · `ad108e43e`, `c943799a6` |
| `QuestifyCoreTests/PlayCreatorTailRoutesTests/testContentAppealReceiptForAnotherOwnerDoesNotConfirm` | Added (new file) | `Tests/CoreTests/PlayCreatorTailRoutesTests.swift` · `ad108e43e`, `c943799a6` |
| `QuestifyCoreTests/PlayCreatorTailRoutesTests/testCreatorTailPathsAreGrantedAndTheDeadReceiptIsGone` | Added (new file) | `Tests/CoreTests/PlayCreatorTailRoutesTests.swift` · `ad108e43e`, `c943799a6` |
| `QuestifyCoreTests/PlayCreatorTailRoutesTests/testEditionEmptyReasonPostsClubIdAndReadsOnlyThisClubsCode` | Added (new file) | `Tests/CoreTests/PlayCreatorTailRoutesTests.swift` · `ad108e43e`, `c943799a6` |
| `QuestifyCoreTests/PlayCreatorTailRoutesTests/testGuardAppealRoundTripReadsEligibilitySubmitsOnceAndReadsByRequestID` | Added (new file) | `Tests/CoreTests/PlayCreatorTailRoutesTests.swift` · `ad108e43e`, `c943799a6` |
| `QuestifyCoreTests/PlayCreatorTailRoutesTests/testGuardAppealTransportFailureKeepsTheCommandAndNeverResubmits` | Added (new file) | `Tests/CoreTests/PlayCreatorTailRoutesTests.swift` · `ad108e43e`, `c943799a6` |
| `QuestifyCoreTests/PlayLeadTailServiceTests/testReleaseStationPostsActivityMemberAndNode` | Added (new file) | `Tests/CoreTests/PlayCreatorTailRoutesTests.swift` · `ad108e43e`, `c943799a6` |
| `QuestifyCoreTests/PlayLeadTailServiceTests/testTeamProgressCarriesChaptersAndSkipRequests` | Added (new file) | `Tests/CoreTests/PlayCreatorTailRoutesTests.swift` · `ad108e43e`, `c943799a6` |
| `QuestifyCoreTests/PlayLeadTailServiceTests/testUnlockChapterSendsTheFrozenCommandAndReadsItsReceipt` | Added (new file) | `Tests/CoreTests/PlayCreatorTailRoutesTests.swift` · `ad108e43e`, `c943799a6` |
| `QuestifyCoreTests/PlayExperienceTests/testLateReplyAfterSessionSwitchDoesNotOverwriteNewSession` | Added (existing file) | `Tests/CoreTests/PlayExperienceTests.swift` · `1e48434aa` |
| `QuestifyCoreTests/PlayExperienceTests/testUnsupportedCompatibilityRefusesRunStart` | Added (existing file) | `Tests/CoreTests/PlayExperienceTests.swift` · `1e48434aa` |
| `QuestifyCoreTests/PlayFullStoryH3Tests/testAddedBlocksKeepAuthorOrderAltTextAndPlaceholderForUnrendered` | Added (new file) | `Tests/CoreTests/PlayFullStoryH3Tests.swift` · `46a79c458` |
| `QuestifyCoreTests/PlayFullStoryH3Tests/testDeclarationIsServerFormatAndOmitsUnrenderedBranch` | Added (new file) | `Tests/CoreTests/PlayFullStoryH3Tests.swift` · `46a79c458` |
| `QuestifyCoreTests/PlayFullStoryH3Tests/testDeclaredMissingKeepsNullDeclaredVersion` | Added (new file) | `Tests/CoreTests/PlayFullStoryH3Tests.swift` · `46a79c458` |
| `QuestifyCoreTests/PlayFullStoryH3Tests/testDocumentCarriesCompatibilityAndContentIdentity` | Added (new file) | `Tests/CoreTests/PlayFullStoryH3Tests.swift` · `46a79c458` |
| `QuestifyCoreTests/PlayFullStoryH3Tests/testLockedStopOnlyWhenTheFlowEndsAtALockedNode` | Added (new file) | `Tests/CoreTests/PlayFullStoryH3Tests.swift` · `46a79c458` |
| `QuestifyCoreTests/PlayFullStoryH3Tests/testReadingPositionNeedsIdentityAndOnlyResumesARenderedLaterSegment` | Added (new file) | `Tests/CoreTests/PlayFullStoryH3Tests.swift` · `46a79c458` |
| `QuestifyCoreTests/PlayFullStoryH3Tests/testUndeclaredAndMalformedAreUnconfirmedNeverSupportedOrUnsupported` | Added (new file) | `Tests/CoreTests/PlayFullStoryH3Tests.swift` · `46a79c458` |
| `QuestifyCoreTests/PlayFullStoryH3Tests/testUnsupportedRejectionIsRecognisedOnlyFromServerText` | Added (new file) | `Tests/CoreTests/PlayFullStoryH3Tests.swift` · `46a79c458` |
| `QuestifyCoreTests/PlayGameSessionCompositionTests/testEmptyAPIURLFailsBeforeAnyRequest` | Added (existing file) | `Tests/CoreTests/PlayGameSessionCompositionTests.swift` · `f9c5e19c0` |
| `QuestifyCoreTests/PlayGapPartialsTests/testAdvancedReceiptForAnotherKeyOrMissingLeavesOnlyTheExactReplay` | Added (new file) | `Tests/CoreTests/PlayGapPartialsTests.swift` · `6adbae522` |
| `QuestifyCoreTests/PlayGapPartialsTests/testAdvancedUnknownIsSettledByItsOwnReceipt` | Added (new file) | `Tests/CoreTests/PlayGapPartialsTests.swift` · `6adbae522` |
| `QuestifyCoreTests/PlayGapPartialsTests/testCoopHelpRejectionShowsTheServerTextAndAStaleQuestSendsNothing` | Added (new file) | `Tests/CoreTests/PlayGapPartialsTests.swift` · `6adbae522` |
| `QuestifyCoreTests/PlayGapPartialsTests/testCoopHelpViewUseAndRetryKeepsTheRequestID` | Added (new file) | `Tests/CoreTests/PlayGapPartialsTests.swift` · `6adbae522` |
| `QuestifyCoreTests/PlayGapPartialsTests/testPersonalRunAbsentSessionAndForeignActivityAreNotATeamBackpack` | Added (new file) | `Tests/CoreTests/PlayGapPartialsTests.swift` · `6adbae522` |
| `QuestifyCoreTests/PlayGapPartialsTests/testTeamBackpackReadsThePlayerProjectionAndMergesTeamScope` | Added (new file) | `Tests/CoreTests/PlayGapPartialsTests.swift` · `6adbae522` |
| `QuestifyCoreTests/PlayGapPartialsTests/testTeamSyncUploadsWalkedPointsOnlyOnce` | Added (new file) | `Tests/CoreTests/PlayGapPartialsTests.swift` · `6adbae522` |
| `QuestifyCoreTests/PlayGapPartialsTests/testTradePreviewIsAPreviewOnlyCallMatchedToThePayload` | Added (new file) | `Tests/CoreTests/PlayGapPartialsTests.swift` · `6adbae522` |
| `QuestifyCoreTests/PlayGapPartialsTests/testWalkedTrailDropsCoarseFixesAndJitter` | Added (new file) | `Tests/CoreTests/PlayGapPartialsTests.swift` · `6adbae522` |
| `QuestifyCoreTests/PlayGapPartialsTests/testWalkedTrailSimplifiesPastFourThousandPoints` | Added (new file) | `Tests/CoreTests/PlayGapPartialsTests.swift` · `6adbae522` |
| `QuestifyCoreTests/PlayGuideInformationListModelTests/testCoordinatorIgnoresOtherRoutesAndAClosedGrant` | Added (new file) | `Tests/CoreTests/PlayGuideInformationListModelTests.swift` · `d1fef1b00` |
| `QuestifyCoreTests/PlayGuideInformationListModelTests/testDebugFixtureProjectsUsableRowsWithoutInventingACount` | Added (new file) | `Tests/CoreTests/PlayGuideInformationListModelTests.swift` · `d1fef1b00` |
| `QuestifyCoreTests/PlayGuideInformationListModelTests/testEmptyListDoesNotInventZeroWhenTotalIsAbsent` | Added (new file) | `Tests/CoreTests/PlayGuideInformationListModelTests.swift` · `d1fef1b00` |
| `QuestifyCoreTests/PlayGuideInformationListModelTests/testExplicitUnknownListIsNotEmptyOrZero` | Added (new file) | `Tests/CoreTests/PlayGuideInformationListModelTests.swift` · `d1fef1b00` |
| `QuestifyCoreTests/PlayGuideInformationListModelTests/testLoadingHasNoDocumentCount` | Added (new file) | `Tests/CoreTests/PlayGuideInformationListModelTests.swift` · `d1fef1b00` |
| `QuestifyCoreTests/PlayGuideInformationListModelTests/testMissingCapabilityStaysHiddenAndDoesNotMarkTheListRouteLive` | Added (new file) | `Tests/CoreTests/PlayGuideInformationListModelTests.swift` · `d1fef1b00` |
| `QuestifyCoreTests/PlayGuideInformationListModelTests/testReadyRowsKeepTheServerTotalInsteadOfTheRowCount` | Added (new file) | `Tests/CoreTests/PlayGuideInformationListModelTests.swift` · `d1fef1b00` |
| `QuestifyCoreTests/PlayGuideInformationListModelTests/testServerZeroStaysZeroAndUnknownTotalsStayAnEmDash` | Added (new file) | `Tests/CoreTests/PlayGuideInformationListModelTests.swift` · `d1fef1b00` |
| `QuestifyCoreTests/PlayGuideInformationListModelTests/testTransportAndMalformedListsAreErrors` | Added (new file) | `Tests/CoreTests/PlayGuideInformationListModelTests.swift` · `d1fef1b00` |
| `QuestifyCoreTests/PlayHelpLadderTests/testAuthorLadderBlocksEmptyTextAndOffClearsQuota` | Added (new file) | `Tests/CoreTests/PlayHelpLadderTests.swift` · `9ecf48c1a` |
| `QuestifyCoreTests/PlayHelpLadderTests/testAuthorLadderSavesRootKeysOnly` | Added (new file) | `Tests/CoreTests/PlayHelpLadderTests.swift` · `9ecf48c1a` |
| `QuestifyCoreTests/PlayHelpLadderTests/testDisabledOrForeignViewKeepsLegacyEntries` | Added (new file) | `Tests/CoreTests/PlayHelpLadderTests.swift` · `9ecf48c1a` |
| `QuestifyCoreTests/PlayHelpLadderTests/testInsufficientPointsRendersNoContent` | Added (new file) | `Tests/CoreTests/PlayHelpLadderTests.swift` · `9ecf48c1a` |
| `QuestifyCoreTests/PlayHelpLadderTests/testLetterContentMustBeOneCharacter` | Added (new file) | `Tests/CoreTests/PlayHelpLadderTests.swift` · `9ecf48c1a` |
| `QuestifyCoreTests/PlayHelpLadderTests/testMissingCounterIsNotZeroAndPriceZeroIsFree` | Added (new file) | `Tests/CoreTests/PlayHelpLadderTests.swift` · `9ecf48c1a` |
| `QuestifyCoreTests/PlayHelpLadderTests/testNotScoredReceiptNeverShowsZero` | Added (new file) | `Tests/CoreTests/PlayHelpLadderTests.swift` · `9ecf48c1a` |
| `QuestifyCoreTests/PlayHelpLadderTests/testOnlyFourHundredsAreRefusals` | Added (new file) | `Tests/CoreTests/PlayHelpLadderTests.swift` · `9ecf48c1a` |
| `QuestifyCoreTests/PlayHelpLadderTests/testPictureOptionsFallBackToText` | Added (new file) | `Tests/CoreTests/PlayHelpLadderTests.swift` · `9ecf48c1a` |
| `QuestifyCoreTests/PlayHelpLadderTests/testProjectionFollowsServerLayers` | Added (new file) | `Tests/CoreTests/PlayHelpLadderTests.swift` · `9ecf48c1a` |
| `QuestifyCoreTests/PlayHelpLadderTests/testSkipSettlesOnlyOnServerFact` | Added (new file) | `Tests/CoreTests/PlayHelpLadderTests.swift` · `9ecf48c1a` |
| `QuestifyCoreTests/PlayHelpLadderTests/testUnknownUseKeepsRequestIDAndResendsIt` | Added (new file) | `Tests/CoreTests/PlayHelpLadderTests.swift` · `9ecf48c1a` |
| `QuestifyCoreTests/PlayHelpLadderTests/testWholeWordPayloadPassesInputContract` | Added (new file) | `Tests/CoreTests/PlayHelpLadderTests.swift` · `9ecf48c1a` |
| `QuestifyCoreTests/PlayIndexPageReadinessTests/testCompletedCountStaysTheServerTotal` | Added (new file) | `Tests/CoreTests/PlayIndexPageReadinessTests.swift` · `773af19aa` |
| `QuestifyCoreTests/PlayIndexPageReadinessTests/testDisabledReadsStayHiddenEmpty` | Added (new file) | `Tests/CoreTests/PlayIndexPageReadinessTests.swift` · `773af19aa` |
| `QuestifyCoreTests/PlayIndexPageReadinessTests/testEmptyRouteIsNotAZero` | Added (new file) | `Tests/CoreTests/PlayIndexPageReadinessTests.swift` · `773af19aa` |
| `QuestifyCoreTests/PlayIndexPageReadinessTests/testFailedReadbackDoesNotKeepACount` | Added (new file) | `Tests/CoreTests/PlayIndexPageReadinessTests.swift` · `773af19aa` |
| `QuestifyCoreTests/PlayIndexPageReadinessTests/testKnownZeroOfOneStaysNumeric` | Added (new file) | `Tests/CoreTests/PlayIndexPageReadinessTests.swift` · `773af19aa` |
| `QuestifyCoreTests/PlayIndexPageReadinessTests/testLoadingHidesAnyCount` | Added (new file) | `Tests/CoreTests/PlayIndexPageReadinessTests.swift` · `773af19aa` |
| `QuestifyCoreTests/PlayIndexPageReadinessTests/testMissingOrInconsistentTotalsStayAnEmDash` | Added (new file) | `Tests/CoreTests/PlayIndexPageReadinessTests.swift` · `773af19aa` |
| `QuestifyCoreTests/PlayIndexPageReadinessTests/testMissingSnapshotIsAnErrorWhenReadsAreOn` | Added (new file) | `Tests/CoreTests/PlayIndexPageReadinessTests.swift` · `773af19aa` |
| `QuestifyCoreTests/PlayIndexPageReadinessTests/testNumericStringZeroRemainsARealZero` | Added (new file) | `Tests/CoreTests/PlayIndexPageReadinessTests.swift` · `773af19aa` |
| `QuestifyCoreTests/PlayIndexPageReadinessTests/testUnknownAvailabilityDoesNotGuessZero` | Added (new file) | `Tests/CoreTests/PlayIndexPageReadinessTests.swift` · `773af19aa` |
| `QuestifyCoreTests/PlayIndexPageReadinessTests/testUnknownMarkIsAnEmDash` | Added (new file) | `Tests/CoreTests/PlayIndexPageReadinessTests.swift` · `773af19aa` |
| `QuestifyCoreTests/PlayIndexPageReadinessTests/testUnknownPhaseWithoutSnapshotStaysUnknown` | Added (new file) | `Tests/CoreTests/PlayIndexPageReadinessTests.swift` · `773af19aa` |
| `QuestifyCoreTests/PlayIndexPageReadinessTests/testUnknownWordDoesNotDecodeAsZero` | Added (new file) | `Tests/CoreTests/PlayIndexPageReadinessTests.swift` · `773af19aa` |
| `QuestifyCoreTests/PlayIndexPageReadinessTests/testUnresolvedOutcomeDoesNotShowTheLastCount` | Added (new file) | `Tests/CoreTests/PlayIndexPageReadinessTests.swift` · `773af19aa` |
| `QuestifyCoreTests/PlayKitQuestoContractsTests/testAccusationOnlyForPickQaWithAccusationEnabledAndReadsServerVerdict` | Added (new file) | `Tests/CoreTests/PlayKitQuestoContractsTests.swift` · `a086ae037`, `1004ebdc7` |
| `QuestifyCoreTests/PlayKitQuestoContractsTests/testAlbumShowsAuthorPhotosBeforeR5AndOnlyReceiptsAfter` | Added (new file) | `Tests/CoreTests/PlayKitQuestoContractsTests.swift` · `a086ae037`, `1004ebdc7` |
| `QuestifyCoreTests/PlayKitQuestoContractsTests/testClosingThePlayKitSheetKeepsTheAdvancedPanel` | Added (new file) | `Tests/CoreTests/PlayKitQuestoContractsTests.swift` · `a086ae037`, `1004ebdc7` |
| `QuestifyCoreTests/PlayKitQuestoContractsTests/testHangmanAndAlbumActionsValidateAndRefuseMoneyFields` | Added (new file) | `Tests/CoreTests/PlayKitQuestoContractsTests.swift` · `a086ae037`, `1004ebdc7` |
| `QuestifyCoreTests/PlayKitQuestoContractsTests/testHangmanFillsEditableCellsInOrderAndBuildsSlotsPayload` | Added (new file) | `Tests/CoreTests/PlayKitQuestoContractsTests.swift` · `a086ae037`, `1004ebdc7` |
| `QuestifyCoreTests/PlayKitStubWriteTests/testUnknownAlbumActionKeepsTheSavedRequestID` | Added (new file) | `Tests/CoreTests/PlayKitStubWriteTests.swift` · `a086ae037` |
| `QuestifyCoreTests/PlayKitStubWriteTests/testUploadFailureDoesNotPostAlbum` | Added (new file) | `Tests/CoreTests/PlayKitStubWriteTests.swift` · `a086ae037` |
| `QuestifyCoreTests/PlayKitTimedChallengePageTests/testChinaHostUsesExistingRoutesAndDoesNotRevealAClosedGrant` | Added (new file) | `Tests/CoreTests/PlayKitTimedChallengePageTests.swift` · `773af19aa` |
| `QuestifyCoreTests/PlayKitTimedChallengePageTests/testDebugFixtureLoadsCountdownWithoutInventingARoute` | Added (new file) | `Tests/CoreTests/PlayKitTimedChallengePageTests.swift` · `773af19aa` |
| `QuestifyCoreTests/PlayKitTimedChallengePageTests/testDisabledAdvancedGrantDoesNotSend` | Added (new file) | `Tests/CoreTests/PlayKitTimedChallengePageTests.swift` · `773af19aa` |
| `QuestifyCoreTests/PlayKitTimedChallengePageTests/testLoadingEmptyErrorAndUnknownPhases` | Added (new file) | `Tests/CoreTests/PlayKitTimedChallengePageTests.swift` · `773af19aa` |
| `QuestifyCoreTests/PlayKitTimedChallengePageTests/testMissingCapabilityOrRouteStaysHidden` | Added (new file) | `Tests/CoreTests/PlayKitTimedChallengePageTests.swift` · `773af19aa` |
| `QuestifyCoreTests/PlayKitTimedChallengePageTests/testMissingSecondsAreNotTreatedAsZero` | Added (new file) | `Tests/CoreTests/PlayKitTimedChallengePageTests.swift` · `773af19aa` |
| `QuestifyCoreTests/PlayKitTimedChallengePageTests/testReactionDoesNotGuessThreeRoundsAndTypeInKeepsLiteralZero` | Added (new file) | `Tests/CoreTests/PlayKitTimedChallengePageTests.swift` · `773af19aa` |
| `QuestifyCoreTests/PlayKitTimedChallengePageTests/testUnknownNumbersStayAnEmDashAndLiteralZeroStaysZero` | Added (new file) | `Tests/CoreTests/PlayKitTimedChallengePageTests.swift` · `773af19aa` |
| `QuestifyCoreTests/PlayRecoveryH4Tests/testActionContextRequiresBothSharedRuntimeFieldsOrNeither` | Added (new file) | `Tests/CoreTests/PlayRecoveryH4Tests.swift` · `662f75c9d`, `50d3ac23e`, `223ddb817` |
| `QuestifyCoreTests/PlayRecoveryH4Tests/testAnswerArriveFirstUsesItsSubReason` | Added (new file) | `Tests/CoreTests/PlayRecoveryH4Tests.swift` · `662f75c9d`, `50d3ac23e`, `223ddb817` |
| `QuestifyCoreTests/PlayRecoveryH4Tests/testArrivalReadingNeedsARealLog` | Added (new file) | `Tests/CoreTests/PlayRecoveryH4Tests.swift` · `662f75c9d`, `50d3ac23e`, `223ddb817` |
| `QuestifyCoreTests/PlayRecoveryH4Tests/testArriveRefusalIsThrownWithItsFieldsAndRequestCarriesTheContext` | Added (new file) | `Tests/CoreTests/PlayRecoveryH4Tests.swift` · `662f75c9d`, `50d3ac23e`, `223ddb817` |
| `QuestifyCoreTests/PlayRecoveryH4Tests/testArriveRefusalKeepsMachineFieldsAndReplacements` | Added (new file) | `Tests/CoreTests/PlayRecoveryH4Tests.swift` · `662f75c9d`, `50d3ac23e`, `223ddb817` |
| `QuestifyCoreTests/PlayRecoveryH4Tests/testBoundSubmitReadsContextThenSettlesATerminalRefusal` | Added (new file) | `Tests/CoreTests/PlayRecoveryH4Tests.swift` · `662f75c9d`, `50d3ac23e`, `223ddb817` |
| `QuestifyCoreTests/PlayRecoveryH4Tests/testEveryArrivalReasonHasItsOwnNextStepAndNoneWidensTheFence` | Added (new file) | `Tests/CoreTests/PlayRecoveryH4Tests.swift` · `662f75c9d`, `50d3ac23e`, `223ddb817` |
| `QuestifyCoreTests/PlayRecoveryH4Tests/testManifestKeepsUnknownsAndRejectsContradictions` | Added (new file) | `Tests/CoreTests/PlayRecoveryH4Tests.swift` · `662f75c9d`, `50d3ac23e`, `223ddb817` |
| `QuestifyCoreTests/PlayRecoveryH4Tests/testOfflineScopeIsNotDeclaredForUnverifiedFiles` | Added (new file) | `Tests/CoreTests/PlayRecoveryH4Tests.swift` · `662f75c9d`, `50d3ac23e`, `223ddb817` |
| `QuestifyCoreTests/PlayRecoveryH4Tests/testPendingAndReusedIdsAreNeverSettledAsFailures` | Added (new file) | `Tests/CoreTests/PlayRecoveryH4Tests.swift` · `662f75c9d`, `50d3ac23e`, `223ddb817` |
| `QuestifyCoreTests/PlayRecoveryH4Tests/testPrefetchStoreIsAccountPrivateAndAHalfPackNeverReplacesTheCompleteOne` | Added (new file) | `Tests/CoreTests/PlayRecoveryH4Tests.swift` · `662f75c9d`, `50d3ac23e`, `223ddb817` |
| `QuestifyCoreTests/PlayRecoveryH4Tests/testRestartReReadsTheOriginalReceiptAndNeverResubmits` | Added (new file) | `Tests/CoreTests/PlayRecoveryH4Tests.swift` · `662f75c9d`, `50d3ac23e`, `223ddb817` |
| `QuestifyCoreTests/PlayRecoveryH4Tests/testRouteNoticeAndStationPauseShowOnlyServerFacts` | Added (new file) | `Tests/CoreTests/PlayRecoveryH4Tests.swift` · `662f75c9d`, `50d3ac23e`, `223ddb817` |
| `QuestifyCoreTests/PlayRecoveryH4Tests/testTerminalFailedReceiptIsADefiniteFailureNotUnknown` | Added (new file) | `Tests/CoreTests/PlayRecoveryH4Tests.swift` · `662f75c9d`, `50d3ac23e`, `223ddb817` |
| `QuestifyCoreTests/PlayRecoveryH4Tests/testUnboundJournalKeepsItsOriginalRequestShape` | Added (new file) | `Tests/CoreTests/PlayRecoveryH4Tests.swift` · `662f75c9d`, `50d3ac23e`, `223ddb817` |
| `QuestifyCoreTests/PlayRuntimeGapTests/testAdvancedReceiptProvesOnlyTheSameSessionAndKey` | Added (new file) | `Tests/CoreTests/PlayRuntimeGapTests.swift` · `bea7690f5` |
| `QuestifyCoreTests/PlayRuntimeGapTests/testCheckRollIsAFormWriteAndTheServerReceiptIsShown` | Added (new file) | `Tests/CoreTests/PlayRuntimeGapTests.swift` · `bea7690f5` |
| `QuestifyCoreTests/PlayRuntimeGapTests/testChinaGateAdmitsThePlayRuntimeAndKeepsMoneyClosed` | Added (new file) | `Tests/CoreTests/PlayRuntimeGapTests.swift` · `bea7690f5` |
| `QuestifyCoreTests/PlayRuntimeGapTests/testContactUsesActivityOrTopicAndNodeAndNeedsADialablePhone` | Added (new file) | `Tests/CoreTests/PlayRuntimeGapTests.swift` · `bea7690f5` |
| `QuestifyCoreTests/PlayRuntimeGapTests/testExplicitRejectionClearsThePendingWrite` | Added (new file) | `Tests/CoreTests/PlayRuntimeGapTests.swift` · `bea7690f5` |
| `QuestifyCoreTests/PlayRuntimeGapTests/testGameplayActionPreviewAndSharedPreview` | Added (new file) | `Tests/CoreTests/PlayRuntimeGapTests.swift` · `bea7690f5` |
| `QuestifyCoreTests/PlayRuntimeGapTests/testHistoryReadIsScopedAndAllOrNothing` | Added (new file) | `Tests/CoreTests/PlayRuntimeGapTests.swift` · `bea7690f5` |
| `QuestifyCoreTests/PlayRuntimeGapTests/testLostResponseIsUnknownAndOnlyTheReceiptReadClearsIt` | Added (new file) | `Tests/CoreTests/PlayRuntimeGapTests.swift` · `bea7690f5` |
| `QuestifyCoreTests/PlayRuntimeGapTests/testMismatchedReceiptStaysUnknown` | Added (new file) | `Tests/CoreTests/PlayRuntimeGapTests.swift` · `bea7690f5` |
| `QuestifyCoreTests/PlayRuntimeGapTests/testOriginalRequiresRouteSessionAndSafeCheckID` | Added (new file) | `Tests/CoreTests/PlayRuntimeGapTests.swift` · `bea7690f5` |
| `QuestifyCoreTests/PlayRuntimeGapTests/testRerollAndSettleCarryTheirOwnActionIDs` | Added (new file) | `Tests/CoreTests/PlayRuntimeGapTests.swift` · `bea7690f5` |
| `QuestifyCoreTests/PlayRuntimeGapTests/testRunSessionClearIsTheEndTombstone` | Added (new file) | `Tests/CoreTests/PlayRuntimeGapTests.swift` · `bea7690f5` |
| `QuestifyCoreTests/PlayRuntimeGapTests/testSetupRowFollowsTheServerWindowAndPrepItems` | Added (new file) | `Tests/CoreTests/PlayRuntimeGapTests.swift` · `bea7690f5` |
| `QuestifyCoreTests/PlayRuntimeGapTests/testSharedHelpBodyRowsAndOutcomes` | Added (new file) | `Tests/CoreTests/PlayRuntimeGapTests.swift` · `bea7690f5` |
| `QuestifyCoreTests/PlayRuntimeGapTests/testUnauthorizedIsNotUnknown` | Added (new file) | `Tests/CoreTests/PlayRuntimeGapTests.swift` · `bea7690f5` |
| `QuestifyCoreTests/PlayRuntimeGapTests/testUnreadableStoreNeverSends` | Added (new file) | `Tests/CoreTests/PlayRuntimeGapTests.swift` · `bea7690f5` |
| `QuestifyCoreTests/PlayTeamBackpackStateTests/testEmptyAndPersonalScope` | Added (new file) | `Tests/CoreTests/PlayTeamItemCommandTests.swift` · `b22d14a69`, `6367e0916` |
| `QuestifyCoreTests/PlayTeamBackpackStateTests/testReadyAndUnknownReceipt` | Added (new file) | `Tests/CoreTests/PlayTeamItemCommandTests.swift` · `b22d14a69`, `6367e0916` |
| `QuestifyCoreTests/PlayTeamItemCommandTests/testAppliedReceiptIsSuccessAndUnknownIsNot` | Added (new file) | `Tests/CoreTests/PlayTeamItemCommandTests.swift` · `b22d14a69`, `6367e0916` |
| `QuestifyCoreTests/PlayTeamItemCommandTests/testClosedCommandCapabilityDoesNotSend` | Added (new file) | `Tests/CoreTests/PlayTeamItemCommandTests.swift` · `b22d14a69`, `6367e0916` |
| `QuestifyCoreTests/PlayTeamItemCommandTests/testCommandClientKeepsUnknownOffTheSuccessPath` | Added (new file) | `Tests/CoreTests/PlayTeamItemCommandTests.swift` · `b22d14a69`, `6367e0916` |
| `QuestifyCoreTests/PlayTeamItemCommandTests/testOnlyTeamItemActionsMatchTheCommandBody` | Added (new file) | `Tests/CoreTests/PlayTeamItemCommandTests.swift` · `b22d14a69`, `6367e0916` |
| `QuestifyCoreTests/PlayThemeReplayTests/testBusinessRejectionDoesNotClaimSuccess` | Added (new file) | `Tests/CoreTests/PlayThemeReplayTests.swift` · `50d3ac23e`, `a7c8877b9` |
| `QuestifyCoreTests/PlayThemeReplayTests/testPostsOnlySessionIdThenAcceptsReplayInstance` | Added (new file) | `Tests/CoreTests/PlayThemeReplayTests.swift` · `50d3ac23e`, `a7c8877b9` |
| `QuestifyCoreTests/PlayThemeReplayTests/testReadBackMissKeepsTheSameRequest` | Added (new file) | `Tests/CoreTests/PlayThemeReplayTests.swift` · `50d3ac23e`, `a7c8877b9` |
| `QuestifyCoreTests/PlayThemeReplayTests/testRefusesUnlessAllowedAndSessionMatches` | Added (new file) | `Tests/CoreTests/PlayThemeReplayTests.swift` · `50d3ac23e`, `a7c8877b9` |
| `QuestifyCoreTests/PlayThemeReplayTests/testReplayAllowedIsStrictJSONTrue` | Added (new file) | `Tests/CoreTests/PlayThemeReplayTests.swift` · `50d3ac23e`, `a7c8877b9` |
| `QuestifyCoreTests/PlayThemeReplayTests/testTransportErrorStaysUnknown` | Added (new file) | `Tests/CoreTests/PlayThemeReplayTests.swift` · `50d3ac23e`, `a7c8877b9` |
| `QuestifyCoreTests/PlayThemeReplayTests/testUnknownKeepsTheRequestIDAndDoesNotPostAgain` | Added (new file) | `Tests/CoreTests/PlayThemeReplayTests.swift` · `50d3ac23e`, `a7c8877b9` |
| `QuestifyCoreTests/PlayerCapabilityRoutesTests/testAdoptionResumeReadsTheReceiptBeforeAnyResubmit` | Added (new file) | `Tests/CoreTests/PlayerCapabilityRoutesTests.swift` · `76d2b1089` |
| `QuestifyCoreTests/PlayerCapabilityRoutesTests/testAdoptionRunsSourceAdoptDetailAndClearsTheJournal` | Added (new file) | `Tests/CoreTests/PlayerCapabilityRoutesTests.swift` · `76d2b1089` |
| `QuestifyCoreTests/PlayerCapabilityRoutesTests/testAuthorDetailUsesMyInfoOnlyForMyScope` | Added (new file) | `Tests/CoreTests/PlayerCapabilityRoutesTests.swift` · `76d2b1089` |
| `QuestifyCoreTests/PlayerCapabilityRoutesTests/testBindingStatusBindSaveAsAndMarketSubmit` | Added (new file) | `Tests/CoreTests/PlayerCapabilityRoutesTests.swift` · `76d2b1089` |
| `QuestifyCoreTests/PlayerCapabilityRoutesTests/testChinaGateAdmitsTheNewRoutesAndKeepsMoneyClosed` | Added (new file) | `Tests/CoreTests/PlayerCapabilityRoutesTests.swift` · `76d2b1089` |
| `QuestifyCoreTests/PlayerCapabilityRoutesTests/testCommunityMineListsReadPostsAndBookmarks` | Added (new file) | `Tests/CoreTests/PlayerCapabilityRoutesTests.swift` · `76d2b1089` |
| `QuestifyCoreTests/PlayerCapabilityRoutesTests/testContributionSubmitSendsIssueReportAndReadsReceipt` | Added (new file) | `Tests/CoreTests/PlayerCapabilityRoutesTests.swift` · `76d2b1089` |
| `QuestifyCoreTests/PlayerCapabilityRoutesTests/testContributionTaxonomyKeepsOnlyKnownIssueCodes` | Added (new file) | `Tests/CoreTests/PlayerCapabilityRoutesTests.swift` · `76d2b1089` |
| `QuestifyCoreTests/PlayerCapabilityRoutesTests/testGeocodePlaceSearchWeatherAndUnifiedSearch` | Added (new file) | `Tests/CoreTests/PlayerCapabilityRoutesTests.swift` · `76d2b1089` |
| `QuestifyCoreTests/PlayerCapabilityRoutesTests/testReportAppealSendsTextOnlyAndReadsReceipt` | Added (new file) | `Tests/CoreTests/PlayerCapabilityRoutesTests.swift` · `76d2b1089` |
| `QuestifyCoreTests/PlayerCapabilityRoutesTests/testRoamSessionRecordsArchiveIsAFormPostWithJSONRecords` | Added (new file) | `Tests/CoreTests/PlayerCapabilityRoutesTests.swift` · `76d2b1089` |
| `QuestifyCoreTests/PlayerCapabilityRoutesTests/testRoamShareRevokeAndShopVisitors` | Added (new file) | `Tests/CoreTests/PlayerCapabilityRoutesTests.swift` · `76d2b1089` |
| `QuestifyCoreTests/PlayerCapabilityRoutesTests/testSafetyTaxonomyRatingAndSummary` | Added (new file) | `Tests/CoreTests/PlayerCapabilityRoutesTests.swift` · `76d2b1089` |
| `QuestifyCoreTests/PlayerGapRoutesTests/testActiveForRoamCard` | Added (new file) | `Tests/CoreTests/PlayerGapRoutesTests.swift` · `af74412be`, `9b342c305`, `bcdb4d00e`, `b883292dd` |
| `QuestifyCoreTests/PlayerGapRoutesTests/testCityNodesMediaCardAndPlayerCode` | Added (new file) | `Tests/CoreTests/PlayerGapRoutesTests.swift` · `af74412be`, `9b342c305`, `bcdb4d00e`, `b883292dd` |
| `QuestifyCoreTests/PlayerGapRoutesTests/testClassifyOnlyFourHundredsRefuse` | Added (new file) | `Tests/CoreTests/PlayerGapRoutesTests.swift` · `af74412be`, `9b342c305`, `bcdb4d00e`, `b883292dd` |
| `QuestifyCoreTests/PlayerGapRoutesTests/testEveryServicePathIsGrantedInChinaGate` | Added (new file) | `Tests/CoreTests/PlayerGapRoutesTests.swift` · `af74412be`, `9b342c305`, `bcdb4d00e`, `b883292dd` |
| `QuestifyCoreTests/PlayerGapRoutesTests/testJoinInfoHostRequestAndPrecheck` | Added (new file) | `Tests/CoreTests/PlayerGapRoutesTests.swift` · `af74412be`, `9b342c305`, `bcdb4d00e`, `b883292dd` |
| `QuestifyCoreTests/PlayerGapRoutesTests/testLeadMemberArriveAndBroadcast` | Added (new file) | `Tests/CoreTests/PlayerGapRoutesTests.swift` · `af74412be`, `9b342c305`, `bcdb4d00e`, `b883292dd` |
| `QuestifyCoreTests/PlayerGapRoutesTests/testLikeStateReadback` | Added (new file) | `Tests/CoreTests/PlayerGapRoutesTests.swift` · `af74412be`, `9b342c305`, `bcdb4d00e`, `b883292dd` |
| `QuestifyCoreTests/PlayerGapRoutesTests/testNoTokenSendsNothing` | Added (new file) | `Tests/CoreTests/PlayerGapRoutesTests.swift` · `af74412be`, `9b342c305`, `bcdb4d00e`, `b883292dd` |
| `QuestifyCoreTests/PlayerGapRoutesTests/testSignupCommandKeepsRequestIDUntilTerminalReceipt` | Added (new file) | `Tests/CoreTests/PlayerGapRoutesTests.swift` · `af74412be`, `9b342c305`, `bcdb4d00e`, `b883292dd` |
| `QuestifyCoreTests/PlayerGapRoutesTests/testSignupRejectedSafetyBlocked` | Added (new file) | `Tests/CoreTests/PlayerGapRoutesTests.swift` · `af74412be`, `9b342c305`, `bcdb4d00e`, `b883292dd` |
| `QuestifyCoreTests/PlayerGapRoutesTests/testTeamInviteQRCode` | Added (new file) | `Tests/CoreTests/PlayerGapRoutesTests.swift` · `af74412be`, `9b342c305`, `bcdb4d00e`, `b883292dd` |
| `QuestifyCoreTests/PlayerGapRoutesTests/testTeamTrailConsentSyncAndFinish` | Added (new file) | `Tests/CoreTests/PlayerGapRoutesTests.swift` · `af74412be`, `9b342c305`, `bcdb4d00e`, `b883292dd` |
| `QuestifyCoreTests/PlayerJourneyProductionLeaseTests/testLeaseOpensTheNamedChinaHostAndKeepsMoneyUnsent` | Added (new file) | `Tests/CoreTests/PlayerJourneyProductionLeaseTests.swift` · `50d3ac23e`, `5d0e87739`, `40b6de9a0` |
| `QuestifyCoreTests/PlayerJourneyProductionLeaseTests/testOwnerGrantAdmitsTheReadsAndRefusesMoney` | Added (new file) | `Tests/CoreTests/PlayerJourneyProductionLeaseTests.swift` · `50d3ac23e`, `5d0e87739`, `40b6de9a0` |
| `QuestifyCoreTests/PlayerJourneyProductionLeaseTests/testProductionHostStaysRefusedWithoutALease` | Added (new file) | `Tests/CoreTests/PlayerJourneyProductionLeaseTests.swift` · `50d3ac23e`, `5d0e87739`, `40b6de9a0` |
| `QuestifyCoreTests/PlayerJourneyProductionLeaseTests/testUnknownSeatOutcomeKeepsTheSavedRequestIdOnTheProductionLease` | Added (new file) | `Tests/CoreTests/PlayerJourneyProductionLeaseTests.swift` · `50d3ac23e`, `5d0e87739`, `40b6de9a0` |
| `QuestifyCoreTests/PlayerJourneyTests/testPublicReferenceReadIsGetAndLeavesTheHistoryGrantClosed` | Added (existing file) | `Tests/CoreTests/PlayerJourneyTests.swift` · `5362ae56f` |
| `QuestifyCoreTests/PlayerJourneyTests/testPublicReferenceReadRejectsMalformedUnauthorizedAndABadToken` | Added (existing file) | `Tests/CoreTests/PlayerJourneyTests.swift` · `5362ae56f` |
| `QuestifyCoreTests/PlayerJourneyTests/testPublicReferenceRowsKeepLiteralZeroAndUnknownAsAnEmDash` | Added (existing file) | `Tests/CoreTests/PlayerJourneyTests.swift` · `5362ae56f` |
| `QuestifyCoreTests/PlayerParityBRoutesTests/testAnalyticsBatchQueueAndFlush` | Added (new file) | `Tests/CoreTests/PlayerParityBRoutesTests.swift` · `f1adac9e9` |
| `QuestifyCoreTests/PlayerParityBRoutesTests/testAnchorOnlyAGameReasonRefuses` | Added (new file) | `Tests/CoreTests/PlayerParityBRoutesTests.swift` · `f1adac9e9` |
| `QuestifyCoreTests/PlayerParityBRoutesTests/testCircleHostReadAndConfigure` | Added (new file) | `Tests/CoreTests/PlayerParityBRoutesTests.swift` · `f1adac9e9` |
| `QuestifyCoreTests/PlayerParityBRoutesTests/testEveryParityBPathIsGrantedAndMoneyIsNot` | Added (new file) | `Tests/CoreTests/PlayerParityBRoutesTests.swift` · `f1adac9e9` |
| `QuestifyCoreTests/PlayerParityBRoutesTests/testLeadTicketResolveAndSeatTarget` | Added (new file) | `Tests/CoreTests/PlayerParityBRoutesTests.swift` · `f1adac9e9` |
| `QuestifyCoreTests/PlayerParityBRoutesTests/testOrientAlternativeSaveAndReadback` | Added (new file) | `Tests/CoreTests/PlayerParityBRoutesTests.swift` · `f1adac9e9` |
| `QuestifyCoreTests/PlayerParityBRoutesTests/testPendingSeatStoreHoldsUntilCleared` | Added (new file) | `Tests/CoreTests/PlayerParityBRoutesTests.swift` · `f1adac9e9` |
| `QuestifyCoreTests/PlayerParityBRoutesTests/testScanGroupMemberTicketFormAndClassification` | Added (new file) | `Tests/CoreTests/PlayerParityBRoutesTests.swift` · `f1adac9e9` |
| `QuestifyCoreTests/PlayerParityBRoutesTests/testSharedControlReadValidatesTheStaffView` | Added (new file) | `Tests/CoreTests/PlayerParityBRoutesTests.swift` · `f1adac9e9` |
| `QuestifyCoreTests/PlayerParityBRoutesTests/testSharedExportRead` | Added (new file) | `Tests/CoreTests/PlayerParityBRoutesTests.swift` · `f1adac9e9` |
| `QuestifyCoreTests/PointsHistoryPageModelTests/testContinuationFollowsTheSourceRule` | Added (new file) | `Tests/CoreTests/PointsHistoryPageModelTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/PointsHistoryPageModelTests/testDirectionFilterIsLocalBecauseTheServerIgnoresIt` | Added (new file) | `Tests/CoreTests/PointsHistoryPageModelTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/PointsHistoryPageModelTests/testEmptyLedgerAndFilteredEmptyUseTheirOwnCopy` | Added (new file) | `Tests/CoreTests/PointsHistoryPageModelTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/PointsHistoryPageModelTests/testFailureWinsOverRowsAndUsesExistingKeys` | Added (new file) | `Tests/CoreTests/PointsHistoryPageModelTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/PointsHistoryPageModelTests/testLiteralZeroAmountAndTotalStayZero` | Added (new file) | `Tests/CoreTests/PointsHistoryPageModelTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/PointsHistoryPageModelTests/testNoPageYetIsLoadingOrUnknownNeverAnEmptyLedger` | Added (new file) | `Tests/CoreTests/PointsHistoryPageModelTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/PointsHistoryPageModelTests/testRowsKeepMissingNumbersAsEmDashAndSignedMagnitudes` | Added (new file) | `Tests/CoreTests/PointsHistoryPageModelTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/Port1ClubDetailRankingTests/testOneDecimalKeepsZeroAndDashesUnknown` | Added (existing file) | `Tests/CoreTests/Port1ClubDetailRankingTests.swift` · `e581fdcee` |
| `QuestifyCoreTests/PostGameReportTests/testEndedRowsAreNotCandidatesAndImpressionCarriesTheSourceRun` | Added (new file) | `Tests/CoreTests/PostGameReportTests.swift` · `74fe013d7` |
| `QuestifyCoreTests/PostGameReportTests/testFeedbackDraftLimitsAndOutcomes` | Added (new file) | `Tests/CoreTests/PostGameReportTests.swift` · `74fe013d7` |
| `QuestifyCoreTests/PostGameReportTests/testFeedbackKeepsTheRequestIdUntilAFinalAnswer` | Added (new file) | `Tests/CoreTests/PostGameReportTests.swift` · `74fe013d7` |
| `QuestifyCoreTests/PostGameReportTests/testFeedbackStaysHiddenOnProductionUntilGranted` | Added (new file) | `Tests/CoreTests/PostGameReportTests.swift` · `74fe013d7` |
| `QuestifyCoreTests/PostGameReportTests/testFinishResultOnlyClearsFromServerFacts` | Added (new file) | `Tests/CoreTests/PostGameReportTests.swift` · `74fe013d7` |
| `QuestifyCoreTests/PostGameReportTests/testMemoryKeepsOwnPhotosAndWritesTheDayOnce` | Added (new file) | `Tests/CoreTests/PostGameReportTests.swift` · `74fe013d7` |
| `QuestifyCoreTests/PostGameReportTests/testNotScoredUnqualifiedAndLegacyStayEmpty` | Added (new file) | `Tests/CoreTests/PostGameReportTests.swift` · `74fe013d7` |
| `QuestifyCoreTests/PostGameReportTests/testReportReadsTheRealWireAndKeepsUnknownsNil` | Added (new file) | `Tests/CoreTests/PostGameReportTests.swift` · `74fe013d7` |
| `QuestifyCoreTests/PostGameReportTests/testScopedBoardEchoCoverageAndWindow` | Added (new file) | `Tests/CoreTests/PostGameReportTests.swift` · `74fe013d7` |
| `QuestifyCoreTests/PostGameReportTests/testTeamBoardIsTeamsNotMembers` | Added (new file) | `Tests/CoreTests/PostGameReportTests.swift` · `74fe013d7` |
| `QuestifyCoreTests/PrivacyProtectionPageModelTests/testAgreeAndRevokeStayReady` | Added (new file) | `Tests/CoreTests/PrivacyProtectionPageModelTests.swift` · `c5150bf32` |
| `QuestifyCoreTests/PrivacyProtectionPageModelTests/testDeviceGrantWithoutAServerRowIsReady` | Added (new file) | `Tests/CoreTests/PrivacyProtectionPageModelTests.swift` · `c5150bf32` |
| `QuestifyCoreTests/PrivacyProtectionPageModelTests/testFixtureDataDecodesKnownEventsAndCountTokens` | Added (new file) | `Tests/CoreTests/PrivacyProtectionPageModelTests.swift` · `c5150bf32` |
| `QuestifyCoreTests/PrivacyProtectionPageModelTests/testLoadingIsVisibleBeforeTheLatestConsentReturns` | Added (new file) | `Tests/CoreTests/PrivacyProtectionPageModelTests.swift` · `c5150bf32` |
| `QuestifyCoreTests/PrivacyProtectionPageModelTests/testMissingLatestAndNoDeviceGrantIsEmptyAndDoesNotRequestUsageRecords` | Added (new file) | `Tests/CoreTests/PrivacyProtectionPageModelTests.swift` · `c5150bf32` |
| `QuestifyCoreTests/PrivacyProtectionPageModelTests/testMoneyWritesAndUsageRecordRouteStayOff` | Added (new file) | `Tests/CoreTests/PrivacyProtectionPageModelTests.swift` · `c5150bf32` |
| `QuestifyCoreTests/PrivacyProtectionPageModelTests/testReadFailureIsErrorAndDisabledReadStaysHidden` | Added (new file) | `Tests/CoreTests/PrivacyProtectionPageModelTests.swift` · `c5150bf32` |
| `QuestifyCoreTests/PrivacyProtectionPageModelTests/testStaleLatestConsentCannotReplaceTheCurrentRead` | Added (new file) | `Tests/CoreTests/PrivacyProtectionPageModelTests.swift` · `c5150bf32` |
| `QuestifyCoreTests/PrivacyProtectionPageModelTests/testUnknownEventIsNotZeroAndLiteralZeroStaysZero` | Added (new file) | `Tests/CoreTests/PrivacyProtectionPageModelTests.swift` · `c5150bf32` |
| `QuestifyCoreTests/PrivacyProtectionPageModelTests/testWithdrawDeviceConsentDoesNotPost` | Added (new file) | `Tests/CoreTests/PrivacyProtectionPageModelTests.swift` · `c5150bf32` |
| `QuestifyCoreTests/ProductionPlayFinishRouteTests/testCapturedEmptyActivityListDecodesNoRows` | Added (new file) | `Tests/CoreTests/ProductionPlayFinishRouteTests.swift` · `4ce602883`, `6367e0916` |
| `QuestifyCoreTests/ProductionPlayFinishRouteTests/testFlagOffShowsNoCard` | Added (new file) | `Tests/CoreTests/ProductionPlayFinishRouteTests.swift` · `4ce602883`, `6367e0916` |
| `QuestifyCoreTests/ProductionPlayFinishRouteTests/testReaderPostsActivityList` | Added (new file) | `Tests/CoreTests/ProductionPlayFinishRouteTests.swift` · `4ce602883`, `6367e0916` |
| `QuestifyCoreTests/ProfileBoundPhoneTests/testNullOrAbsentCategoryListIsNoPreferences` | Added (existing file) | `Tests/CoreTests/ProfileBoundPhoneTests.swift` · `1f0f33b4f` |
| `QuestifyCoreTests/ProfileInviteHistoryPageReadyTests/testAnAcceptedEmptyPageIsEmptyAndAKnownZeroTotalStaysZero` | Added (new file) | `Tests/CoreTests/ProfileInviteHistoryPageReadyTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/ProfileInviteHistoryPageReadyTests/testFailureWinsAndKeepsItsKind` | Added (new file) | `Tests/CoreTests/ProfileInviteHistoryPageReadyTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/ProfileInviteHistoryPageReadyTests/testIdentifiersAndRoutesStayTheExistingReadOnlyPair` | Added (new file) | `Tests/CoreTests/ProfileInviteHistoryPageReadyTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/ProfileInviteHistoryPageReadyTests/testMissingTotalIsAnEmDashNotZero` | Added (new file) | `Tests/CoreTests/ProfileInviteHistoryPageReadyTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/ProfileInviteHistoryPageReadyTests/testNothingLoadedIsLoadingOrUnknownNeverEmpty` | Added (new file) | `Tests/CoreTests/ProfileInviteHistoryPageReadyTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/ProfileInviteHistoryPageReadyTests/testRewardCoverageDistinguishesMissingPartialAndComplete` | Added (new file) | `Tests/CoreTests/ProfileInviteHistoryPageReadyTests.swift` · `b91de3b4a` |
| `QuestifyCoreTests/ProjectEditTests/testBlankTeamSizeStaysValidAndIsOmittedFromPayloadWhileLiteralZeroIsSent` | Added (existing file) | `Tests/CoreTests/ProjectEditTests.swift` · `a8098abfb`, `e581fdcee` |
| `QuestifyCoreTests/ProjectEditTests/testMissingTeamSizeStaysBlankAndLiteralZeroStaysZero` | Added (existing file) | `Tests/CoreTests/ProjectEditTests.swift` · `a8098abfb`, `e581fdcee` |
| `QuestifyCoreTests/PublicCatalogHostTests/testHiddenCatalogStaysUnavailable` | Added (new file) | `Tests/CoreTests/PublicCatalogHostTests.swift` · `ca4f39acd` |
| `QuestifyCoreTests/PublicCatalogHostTests/testHostPostsTheThreeReadsAndKeepsMoneyOff` | Added (new file) | `Tests/CoreTests/PublicCatalogHostTests.swift` · `ca4f39acd` |
| `QuestifyCoreTests/PublicCatalogHostTests/testMissingGrantSendsNothing` | Added (new file) | `Tests/CoreTests/PublicCatalogHostTests.swift` · `ca4f39acd` |
| `QuestifyCoreTests/PublicCatalogHostTests/testUniversalLinkReadsListFiltersAndInfoAndRefusesMoney` | Added (new file) | `Tests/CoreTests/PublicCatalogHostTests.swift` · `ca4f39acd` |
| `QuestifyCoreTests/PublicCatalogHostTests/testUnknownPriceIsAnEmDashAndALiteralZeroStaysZero` | Added (new file) | `Tests/CoreTests/PublicCatalogHostTests.swift` · `ca4f39acd` |
| `QuestifyCoreTests/PublicContentShareLinkTests/testAbsentAudienceAndStatusStayShareableAndPrivateOrUnpublishedDoNot` | Added (new file) | `Tests/CoreTests/PublicContentShareLinkTests.swift` · `107ceb4c6` |
| `QuestifyCoreTests/PublicContentShareLinkTests/testDecodedSquarePostMapsPublishedLifecycleOntoTheShareableCard` | Added (new file) | `Tests/CoreTests/PublicContentShareLinkTests.swift` · `107ceb4c6` |
| `QuestifyCoreTests/PublicContentShareLinkTests/testDiscoveryTemplateUsesTheParsedTemplatePath` | Added (new file) | `Tests/CoreTests/PublicContentShareLinkTests.swift` · `107ceb4c6` |
| `QuestifyCoreTests/PublicContentShareLinkTests/testPublicSquarePostUsesTheParsedDetailPathOnTheExistingChinaHost` | Added (new file) | `Tests/CoreTests/PublicContentShareLinkTests.swift` · `107ceb4c6` |
| `QuestifyCoreTests/PublicContentShareLinkTests/testTopicTemplatePathIsNotParsedSoOnlyTheMiniProgramPathIsCopied` | Added (new file) | `Tests/CoreTests/PublicContentShareLinkTests.swift` · `107ceb4c6` |
| `QuestifyCoreTests/PublicTopicTemplateTests/testFinishMedalNameIsOnlyThePublicDetailString` | Added (existing file) | `Tests/CoreTests/PublicTopicTemplateTests.swift` · `3bcaa2845` |
| `QuestifyCoreTests/PublishClarityH2Tests/testAcknowledgmentKeepsCommercialFactsAndRoundTrips` | Added (new file) | `Tests/CoreTests/PublishClarityH2Tests.swift` · `969ea25ca` |
| `QuestifyCoreTests/PublishClarityH2Tests/testAgreementAndStagesNeverClaimRehearsalOrOnSite` | Added (new file) | `Tests/CoreTests/PublishClarityH2Tests.swift` · `969ea25ca` |
| `QuestifyCoreTests/PublishClarityH2Tests/testCheckDecodesLocationAndRejectsMalformedRows` | Added (new file) | `Tests/CoreTests/PublishClarityH2Tests.swift` · `969ea25ca` |
| `QuestifyCoreTests/PublishClarityH2Tests/testFeatureAcceptsOnlyTheTwoGets` | Added (new file) | `Tests/CoreTests/PublishClarityH2Tests.swift` · `969ea25ca` |
| `QuestifyCoreTests/PublishClarityH2Tests/testHeadlinesNeverPromoteVisibilityToApproval` | Added (new file) | `Tests/CoreTests/PublishClarityH2Tests.swift` · `969ea25ca` |
| `QuestifyCoreTests/PublishClarityH2Tests/testMyProjectTopicFactSharesHeadlineAndExplainsSoldScope` | Added (new file) | `Tests/CoreTests/PublishClarityH2Tests.swift` · `969ea25ca` |
| `QuestifyCoreTests/PublishClarityH2Tests/testReadRouteIsAnExactGetWithTopicAndScope` | Added (new file) | `Tests/CoreTests/PublishClarityH2Tests.swift` · `969ea25ca` |
| `QuestifyCoreTests/PublishClarityH2Tests/testServerIssueLocatesByServerIDsOnlyWhenUnique` | Added (new file) | `Tests/CoreTests/PublishClarityH2Tests.swift` · `969ea25ca` |
| `QuestifyCoreTests/PublishClarityH2Tests/testServiceReadsOnlyWithItsOwnGrantAndSession` | Added (new file) | `Tests/CoreTests/PublishClarityH2Tests.swift` · `969ea25ca` |
| `QuestifyCoreTests/PublishClarityH2Tests/testStatusKeepsFiveFactsSeparate` | Added (new file) | `Tests/CoreTests/PublishClarityH2Tests.swift` · `969ea25ca` |
| `QuestifyCoreTests/PublishClarityH2Tests/testWhereFollowsMiniProgramFieldMapping` | Added (new file) | `Tests/CoreTests/PublishClarityH2Tests.swift` · `969ea25ca` |
| `QuestifyCoreTests/PublishFabuPageModelTests/testCoordinatorWiringUsesTheLiveStateAndDoesNotOpenPlayerEntry` | Added (new file) | `Tests/CoreTests/PublishFabuPageModelTests.swift` · `b23db8968` |
| `QuestifyCoreTests/PublishFabuPageModelTests/testEmptyAndUnknownAreAnEmDashAndZeroStaysZero` | Added (new file) | `Tests/CoreTests/PublishFabuPageModelTests.swift` · `b23db8968` |
| `QuestifyCoreTests/PublishFabuPageModelTests/testErrorKeepsARealTokenAndNumericTokensStayUnknown` | Added (new file) | `Tests/CoreTests/PublishFabuPageModelTests.swift` · `b23db8968` |
| `QuestifyCoreTests/PublishFabuPageModelTests/testKnownChapterCountAndMissingQuotaStayDistinct` | Added (new file) | `Tests/CoreTests/PublishFabuPageModelTests.swift` · `b23db8968` |
| `QuestifyCoreTests/PublishFabuPageModelTests/testLoadingHidesAStaleZeroAndUnknownOutcomeDoesNotShowIt` | Added (new file) | `Tests/CoreTests/PublishFabuPageModelTests.swift` · `b23db8968` |
| `QuestifyCoreTests/PublishFabuPageModelTests/testMissingCapabilityStaysHiddenAndDoesNotGuessZero` | Added (new file) | `Tests/CoreTests/PublishFabuPageModelTests.swift` · `b23db8968` |
| `QuestifyCoreTests/PublisherLifecycleTests/testMerchantPartnerProjectsHomeFactsAndDoesNotInventChargeOrCapacity` | Added (existing file) | `Tests/CoreTests/PublisherLifecycleTests.swift` · `226c530e7` |
| `QuestifyCoreTests/QuickPublishSimplePageTests/testBlankTitleWithAStopIsReady` | Added (new file) | `Tests/CoreTests/QuickPublishSimplePageTests.swift` · `2fe29ded2` |
| `QuestifyCoreTests/QuickPublishSimplePageTests/testDeniedSimplePublishStaysHiddenAndDoesNotSurfaceZero` | Added (new file) | `Tests/CoreTests/QuickPublishSimplePageTests.swift` · `2fe29ded2` |
| `QuestifyCoreTests/QuickPublishSimplePageTests/testFailedReadIsErrorAndNotAnEmptyOrZeroQuota` | Added (new file) | `Tests/CoreTests/QuickPublishSimplePageTests.swift` · `2fe29ded2` |
| `QuestifyCoreTests/QuickPublishSimplePageTests/testFixtureDataDecodesAndStringsFileMatchesTheModel` | Added (new file) | `Tests/CoreTests/QuickPublishSimplePageTests.swift` · `2fe29ded2` |
| `QuestifyCoreTests/QuickPublishSimplePageTests/testGrantedHomeStartsLoadingBeforeAnyRead` | Added (new file) | `Tests/CoreTests/QuickPublishSimplePageTests.swift` · `2fe29ded2` |
| `QuestifyCoreTests/QuickPublishSimplePageTests/testHomeGrantDoesNotImplyQuotaRead` | Added (new file) | `Tests/CoreTests/QuickPublishSimplePageTests.swift` · `2fe29ded2` |
| `QuestifyCoreTests/QuickPublishSimplePageTests/testLiteralZeroStaysZero` | Added (new file) | `Tests/CoreTests/QuickPublishSimplePageTests.swift` · `2fe29ded2` |
| `QuestifyCoreTests/QuickPublishSimplePageTests/testLoadingStaysLoadingUntilBothReadsFinish` | Added (new file) | `Tests/CoreTests/QuickPublishSimplePageTests.swift` · `2fe29ded2` |
| `QuestifyCoreTests/QuickPublishSimplePageTests/testMalformedPermissionIsErrorAndDoesNotReadQuota` | Added (new file) | `Tests/CoreTests/QuickPublishSimplePageTests.swift` · `2fe29ded2` |
| `QuestifyCoreTests/QuickPublishSimplePageTests/testMissingGrantStaysHiddenAndDoesNotRead` | Added (new file) | `Tests/CoreTests/QuickPublishSimplePageTests.swift` · `2fe29ded2` |
| `QuestifyCoreTests/QuickPublishSimplePageTests/testMissingPermissionFollowsExistingHomeContract` | Added (new file) | `Tests/CoreTests/QuickPublishSimplePageTests.swift` · `2fe29ded2` |
| `QuestifyCoreTests/QuickPublishSimplePageTests/testMissingThemesIsUnknownEvenWhenQuotaIsKnown` | Added (new file) | `Tests/CoreTests/QuickPublishSimplePageTests.swift` · `2fe29ded2` |
| `QuestifyCoreTests/QuickPublishSimplePageTests/testQuotaGrantWithoutHomeStaysHidden` | Added (new file) | `Tests/CoreTests/QuickPublishSimplePageTests.swift` · `2fe29ded2` |
| `QuestifyCoreTests/QuickPublishSimplePageTests/testReadsOnlyExistingHomeAndQuotaPaths` | Added (new file) | `Tests/CoreTests/QuickPublishSimplePageTests.swift` · `2fe29ded2` |
| `QuestifyCoreTests/QuickPublishSimplePageTests/testStaleLoadCannotReplaceANewerResult` | Added (new file) | `Tests/CoreTests/QuickPublishSimplePageTests.swift` · `2fe29ded2` |
| `QuestifyCoreTests/QuickPublishSimplePageTests/testUnknownTokenNumericStringAndFractionStayEmDash` | Added (new file) | `Tests/CoreTests/QuickPublishSimplePageTests.swift` · `2fe29ded2` |
| `QuestifyCoreTests/QuickPublishSimplePageTests/testUnlimitedNullCountIsAnEmDashAndNotZero` | Added (new file) | `Tests/CoreTests/QuickPublishSimplePageTests.swift` · `2fe29ded2` |
| `QuestifyCoreTests/QuickPublishSimplePageTests/testWhitespaceTitleStaysEmpty` | Added (new file) | `Tests/CoreTests/QuickPublishSimplePageTests.swift` · `2fe29ded2` |
| `QuestifyCoreTests/RegionalConfigurationTests/testEmptyAPIURLStaysUnconfiguredEvenWhenApprovalsExist` | Added (existing file) | `Tests/CoreTests/RegionalConfigurationTests.swift` · `f9c5e19c0` |
| `QuestifyCoreTests/RegistrationCoordinatorTests/testPaidQuoteDoesNotCreate` | Added (existing file) | `Tests/CoreTests/RegistrationCoordinatorTests.swift` · `37415f606` |
| `QuestifyCoreTests/RegistrationServiceTests/testActivitySignupConsentUsesSortedJSONAndNoPaymentField` | Added (existing file) | `Tests/CoreTests/RegistrationServiceTests.swift` · `4ce602883`, `803d9749c`, `90590ab25`, `4fd73317f` |
| `QuestifyCoreTests/RegistrationServiceTests/testCapturedConsentEnvelopeIsAccepted` | Added (existing file) | `Tests/CoreTests/RegistrationServiceTests.swift` · `4ce602883`, `803d9749c`, `90590ab25`, `4fd73317f` |
| `QuestifyCoreTests/RegistrationUIFlowTests/testFreePolicyConfirmsOnlyAKnownZeroQuote` | Added (existing file) | `Tests/CoreTests/RegistrationUIFlowTests.swift` · `f9a08d041`, `803d9749c`, `90590ab25`, `4fd73317f` |
| `QuestifyCoreTests/ReleaseMoneyWriteSwitchDerivationTests/testOffByDefaultAndFollowsAnInstalledDerivation` | Added (new file) | `Tests/CoreTests/ReleaseMoneyWriteSwitchDerivationTests.swift` · `dd579e03d` |
| `QuestifyCoreTests/ReleaseMoneyWriteSwitchDerivationTests/testReleaseBuildKeepsCompileTimeConstants` | Added (new file) | `Tests/CoreTests/ReleaseMoneyWriteSwitchDerivationTests.swift` · `dd579e03d` |
| `QuestifyCoreTests/ReviewedChinaLaunchTests/testShippedChinaAdmissionAcceptsOnlyTheReviewedHost` | Added (existing file) | `Tests/CoreTests/ReviewedChinaLaunchTests.swift` · `b82cbcc40` |
| `QuestifyCoreTests/RoamFinishAddressTests/testLocationSentencesAndUnknownDash` | Added (new file) | `Tests/CoreTests/RoamCloudStubTests.swift` · `89f841a26`, `897d71618` |
| `QuestifyCoreTests/RoamFinishAddressTests/testSelectedNameWinsAndAddressFillsAnEmptyName` | Added (new file) | `Tests/CoreTests/RoamCloudStubTests.swift` · `89f841a26`, `897d71618` |
| `QuestifyCoreTests/RoamPlaceCommentClientTests/testListUsesOwnerTypeFourAndDoesNotTreatAFailedReadAsEmpty` | Added (new file) | `Tests/CoreTests/RoamCloudStubTests.swift` · `89f841a26`, `897d71618` |
| `QuestifyCoreTests/RoamPlaceCommentClientTests/testPublishKeepsTheRequestIdAndSendsNoMoney` | Added (new file) | `Tests/CoreTests/RoamCloudStubTests.swift` · `89f841a26`, `897d71618` |
| `QuestifyCoreTests/RoamPlaceReviewAttemptTests/testLockStoreKeepsOnlyALockedAttempt` | Added (new file) | `Tests/CoreTests/RoamCloudStubTests.swift` · `89f841a26`, `897d71618` |
| `QuestifyCoreTests/RoamPlaceReviewAttemptTests/testUnknownStaysOnTheSameIdAndADifferentDraftDoesNotSend` | Added (new file) | `Tests/CoreTests/RoamCloudStubTests.swift` · `89f841a26`, `897d71618` |
| `QuestifyCoreTests/RoamContractTests/testMissingRunnerStatsStayUnknownAndLiteralZeroStaysZero` | Added (existing file) | `Tests/CoreTests/RoamContractTests.swift` · `e581fdcee` |
| `QuestifyCoreTests/RoamLiveSessionTests/testBackgroundHoldKeepsWalkActiveAndFinishReleasesIt` | Added (existing file) | `Tests/CoreTests/RoamLiveSessionTests.swift` · `1e48434aa`, `4c5e89ecc` |
| `QuestifyCoreTests/RoamLiveSessionTests/testLocationConsentRunsBeforeRevealAndFailureLeavesWalkUnstarted` | Added (existing file) | `Tests/CoreTests/RoamLiveSessionTests.swift` · `1e48434aa`, `4c5e89ecc` |
| `QuestifyCoreTests/RoamPassportOverviewTests/testHomeIndexStatesKeepUnknownAsEmDashAndKnownZeroNumeric` | Added (existing file) | `Tests/CoreTests/RoamPassportOverviewTests.swift` · `c5150bf32` |
| `QuestifyCoreTests/RootTabTests/testPlayerBarIsFourTabsWithoutPublish` | Added (existing file) | `Tests/CoreTests/RootTabTests.swift` · `7b4efc671` |
| `QuestifyCoreTests/SettingsIdentityApplicationsTests/testKnownRolesAreReadyAndUnknownRolesStayAnEmDash` | Added (existing file) | `Tests/CoreTests/SettingsIdentityApplicationsTests.swift` · `8708c66e0` |
| `QuestifyCoreTests/SettingsIdentityApplicationsTests/testLoadingAndFailureHideAccountActionsWithoutInventingZero` | Added (existing file) | `Tests/CoreTests/SettingsIdentityApplicationsTests.swift` · `8708c66e0` |
| `QuestifyCoreTests/SettingsIdentityApplicationsTests/testNilMarketOnAKnownRoleIsUnknownNotZero` | Added (existing file) | `Tests/CoreTests/SettingsIdentityApplicationsTests.swift` · `8708c66e0` |
| `QuestifyCoreTests/SettingsIdentityApplicationsTests/testSignedOutIsEmptyAndKeepsAKnownMarket` | Added (existing file) | `Tests/CoreTests/SettingsIdentityApplicationsTests.swift` · `8708c66e0` |
| `QuestifyCoreTests/SettingsIdentityApplicationsTests/testUnknownCountIsAnEmDashAndALiteralZeroStaysZero` | Added (existing file) | `Tests/CoreTests/SettingsIdentityApplicationsTests.swift` · `8708c66e0` |
| `QuestifyCoreTests/SettingsLegalAgreementPageTests/testAgreementGetStaysHiddenAndReleaseApprovalStaysOff` | Added (new file) | `Tests/CoreTests/SettingsLegalAgreementPageTests.swift` · `5e2aeabb1`, `c5150bf32` |
| `QuestifyCoreTests/SettingsLegalAgreementPageTests/testBlankDocumentIsUnknownAndATitledEmptyDocumentKeepsZero` | Added (new file) | `Tests/CoreTests/SettingsLegalAgreementPageTests.swift` · `5e2aeabb1`, `c5150bf32` |
| `QuestifyCoreTests/SettingsLegalAgreementPageTests/testBlankVersionStaysUnknownWhileTheSectionCountStaysLiteral` | Added (new file) | `Tests/CoreTests/SettingsLegalAgreementPageTests.swift` · `5e2aeabb1`, `c5150bf32` |
| `QuestifyCoreTests/SettingsLegalAgreementPageTests/testBundledReaderProjectsReadyEmptyAndErrorWithoutANetworkRoute` | Added (new file) | `Tests/CoreTests/SettingsLegalAgreementPageTests.swift` · `5e2aeabb1`, `c5150bf32` |
| `QuestifyCoreTests/SettingsLegalAgreementPageTests/testDebugFixtureDataUsesSyntheticLabelsAndTheSameFacts` | Added (new file) | `Tests/CoreTests/SettingsLegalAgreementPageTests.swift` · `5e2aeabb1`, `c5150bf32` |
| `QuestifyCoreTests/SettingsLegalAgreementPageTests/testIdleLoadingFailureAndMissingDoNotInventASectionCount` | Added (new file) | `Tests/CoreTests/SettingsLegalAgreementPageTests.swift` · `5e2aeabb1`, `c5150bf32` |
| `QuestifyCoreTests/SettingsLegalAgreementPageTests/testInFlightLoadStaysLoadingUntilTheBundledDocumentReturns` | Added (new file) | `Tests/CoreTests/SettingsLegalAgreementPageTests.swift` · `5e2aeabb1`, `c5150bf32` |
| `QuestifyCoreTests/SettingsLegalAgreementPageTests/testSectionIdentifierDoesNotUseANegativeIndex` | Added (new file) | `Tests/CoreTests/SettingsLegalAgreementPageTests.swift` · `5e2aeabb1`, `c5150bf32` |
| `QuestifyCoreTests/SettingsLegalAgreementPageTests/testUnknownCountIsAnEmDashAndALiteralZeroStaysZero` | Added (new file) | `Tests/CoreTests/SettingsLegalAgreementPageTests.swift` · `5e2aeabb1`, `c5150bf32` |
| `QuestifyCoreTests/SettingsNativeTests/testAboutPageKeepsSuppliedVersionAndBuildAndLeavesPlayerCodeInError` | Added (existing file) | `Tests/CoreTests/SettingsNativeTests.swift` · `78af17764` |
| `QuestifyCoreTests/SettingsNativeTests/testAboutPageUnknownMetadataIsAnEmDashAndALiteralZeroStaysZero` | Added (existing file) | `Tests/CoreTests/SettingsNativeTests.swift` · `78af17764` |
| `QuestifyCoreTests/SettingsNativeTests/testAboutPlayerCodePhasesDoNotInventAnImage` | Added (existing file) | `Tests/CoreTests/SettingsNativeTests.swift` · `78af17764` |
| `QuestifyCoreTests/SideQuestPlayerFlowTests/testASuppliedReadStaysHiddenOnTheProductionEntry` | Added (new file) | `Tests/CoreTests/SideQuestPlayerFlowTests.swift` · `f842b2ee1` |
| `QuestifyCoreTests/SideQuestPlayerFlowTests/testDiscoveryKeepsUnrestrictedRowsAndDropsEveryOtherPolicy` | Added (new file) | `Tests/CoreTests/SideQuestPlayerFlowTests.swift` · `f842b2ee1` |
| `QuestifyCoreTests/SideQuestPlayerFlowTests/testFilteredOutReadIsAnEmptyZeroNotAnUnknownCount` | Added (new file) | `Tests/CoreTests/SideQuestPlayerFlowTests.swift` · `f842b2ee1` |
| `QuestifyCoreTests/SideQuestPlayerFlowTests/testGateOrderStopsAtTheFirstClosedSwitch` | Added (new file) | `Tests/CoreTests/SideQuestPlayerFlowTests.swift` · `f842b2ee1` |
| `QuestifyCoreTests/SideQuestPlayerFlowTests/testListedAnswerStillDoesNotWriteAReadback` | Added (new file) | `Tests/CoreTests/SideQuestPlayerFlowTests.swift` · `f842b2ee1` |
| `QuestifyCoreTests/SideQuestPlayerFlowTests/testMoneyAndAcceptStayOff` | Added (new file) | `Tests/CoreTests/SideQuestPlayerFlowTests.swift` · `f842b2ee1` |
| `QuestifyCoreTests/SideQuestPlayerFlowTests/testProductionActionsDoNotMutateTheBookOrRecordAChoice` | Added (new file) | `Tests/CoreTests/SideQuestPlayerFlowTests.swift` · `f842b2ee1` |
| `QuestifyCoreTests/SideQuestPlayerFlowTests/testProductionEntryIsClosedBesideTheSearchMap` | Added (new file) | `Tests/CoreTests/SideQuestPlayerFlowTests.swift` · `f842b2ee1` |
| `QuestifyCoreTests/SideQuestPlayerFlowTests/testRepeatPolicyParserDoesNotGuess` | Added (new file) | `Tests/CoreTests/SideQuestPlayerFlowTests.swift` · `f842b2ee1` |
| `QuestifyCoreTests/SideQuestPlayerFlowTests/testUnknownReadsUseAnEmDashAndALoadedEmptyReadUsesZero` | Added (new file) | `Tests/CoreTests/SideQuestPlayerFlowTests.swift` · `f842b2ee1` |
| `QuestifyCoreTests/SignInWithAppleFlowTests/testAlreadyCancelledExchangeDoesNotSend` | Added (new file) | `Tests/CoreTests/SignInWithAppleFlowTests.swift` · `67d0b107e` |
| `QuestifyCoreTests/SignInWithAppleFlowTests/testBuildFilesDoNotEnableTheFlowOrChangeIdentity` | Added (new file) | `Tests/CoreTests/SignInWithAppleFlowTests.swift` · `67d0b107e` |
| `QuestifyCoreTests/SignInWithAppleFlowTests/testEmptyURLStaysHiddenAndDoesNotCallTheReviewedHost` | Added (new file) | `Tests/CoreTests/SignInWithAppleFlowTests.swift` · `67d0b107e` |
| `QuestifyCoreTests/SignInWithAppleFlowTests/testEntitlementAcceptsOnlyTheDefaultValue` | Added (new file) | `Tests/CoreTests/SignInWithAppleFlowTests.swift` · `67d0b107e` |
| `QuestifyCoreTests/SignInWithAppleFlowTests/testExplicitReviewedChinaHostIsUsedOnlyWhenTheCapabilityIsPresent` | Added (new file) | `Tests/CoreTests/SignInWithAppleFlowTests.swift` · `67d0b107e` |
| `QuestifyCoreTests/SignInWithAppleFlowTests/testInvalidCredentialAndRoleMismatchDoNotRetryOrAccept` | Added (new file) | `Tests/CoreTests/SignInWithAppleFlowTests.swift` · `67d0b107e` |
| `QuestifyCoreTests/SignInWithAppleFlowTests/testLoginFailureDoesNotReadTheAccountOrRetry` | Added (new file) | `Tests/CoreTests/SignInWithAppleFlowTests.swift` · `67d0b107e` |
| `QuestifyCoreTests/SignInWithAppleFlowTests/testMissingEntitlementOrAnotherMarketNeverSends` | Added (new file) | `Tests/CoreTests/SignInWithAppleFlowTests.swift` · `67d0b107e` |
| `QuestifyCoreTests/SignInWithAppleFlowTests/testRepositoryEntitlementIsTheOnlySignInValue` | Added (new file) | `Tests/CoreTests/SignInWithAppleFlowTests.swift` · `67d0b107e` |
| `QuestifyCoreTests/SignInWithAppleFlowTests/testReviewedCapabilityExchangesOnlyTheAppleRouteThenReadsTheSameAccount` | Added (new file) | `Tests/CoreTests/SignInWithAppleFlowTests.swift` · `67d0b107e` |
| `QuestifyCoreTests/SignInWithAppleFlowTests/testReviewedChinaHostStaysHiddenUntilTheCapabilityIsNamed` | Added (new file) | `Tests/CoreTests/SignInWithAppleFlowTests.swift` · `67d0b107e` |
| `QuestifyCoreTests/SignInWithAppleFlowTests/testUnapprovedHostAndOtherCapabilitiesStayHidden` | Added (new file) | `Tests/CoreTests/SignInWithAppleFlowTests.swift` · `67d0b107e` |
| `QuestifyCoreTests/SquareDetailPageReadyTests/testAcceptedPayloadWinsOverTheLoadingFlag` | Added (existing file) | `Tests/CoreTests/SquareDetailInteractionTests.swift` · `7e7896137` |
| `QuestifyCoreTests/SquareDetailPageReadyTests/testClosedGateAndLiveRoutesDoNotMarkAnythingNew` | Added (existing file) | `Tests/CoreTests/SquareDetailInteractionTests.swift` · `7e7896137` |
| `QuestifyCoreTests/SquareDetailPageReadyTests/testCommentPageDoesNotInventContinuationOrACount` | Added (existing file) | `Tests/CoreTests/SquareDetailInteractionTests.swift` · `7e7896137` |
| `QuestifyCoreTests/SquareDetailPageReadyTests/testDebugFixtureDataCoversReadyUnknownZeroAndEmpty` | Added (existing file) | `Tests/CoreTests/SquareDetailInteractionTests.swift` · `7e7896137` |
| `QuestifyCoreTests/SquareDetailPageReadyTests/testKnownFactsDoNotBorrowAnotherField` | Added (existing file) | `Tests/CoreTests/SquareDetailInteractionTests.swift` · `7e7896137` |
| `QuestifyCoreTests/SquareDetailPageReadyTests/testLoadingEmptyErrorAndUnknownStaySeparate` | Added (existing file) | `Tests/CoreTests/SquareDetailInteractionTests.swift` · `7e7896137` |
| `QuestifyCoreTests/SquareDetailPageReadyTests/testOmittedCountsStayUnknownAndLiteralZeroStaysZero` | Added (existing file) | `Tests/CoreTests/SquareDetailInteractionTests.swift` · `7e7896137` |
| `QuestifyCoreTests/SquareDetailPageReadyTests/testUnknownMarkIsAnEmDashAndNotZero` | Added (existing file) | `Tests/CoreTests/SquareDetailInteractionTests.swift` · `7e7896137` |
| `QuestifyCoreTests/SquareOptionalCountModelTests/testCommentLikeCountNilVersusZero` | Added (new file) | `Tests/CoreTests/SquareOptionalCountModelTests.swift` · `798e4d96e` |
| `QuestifyCoreTests/SquareOptionalCountModelTests/testDisplayTextUsesEmDashOnlyForUnknown` | Added (new file) | `Tests/CoreTests/SquareOptionalCountModelTests.swift` · `798e4d96e` |
| `QuestifyCoreTests/SquareOptionalCountModelTests/testPostCountsAreNilWhenOmittedNullNegativeOrNotANumber` | Added (new file) | `Tests/CoreTests/SquareOptionalCountModelTests.swift` · `798e4d96e` |
| `QuestifyCoreTests/SquareOptionalCountModelTests/testPostKnownCountsAndLikeNumAlias` | Added (new file) | `Tests/CoreTests/SquareOptionalCountModelTests.swift` · `798e4d96e` |
| `QuestifyCoreTests/SquareOptionalCountModelTests/testPostLiteralZeroStaysZeroAndIsNotNil` | Added (new file) | `Tests/CoreTests/SquareOptionalCountModelTests.swift` · `798e4d96e` |
| `QuestifyCoreTests/SquareRouteMapVerifiedTests/testArrayGeometryStaysOneSegmentPerChapter` | Added (new file) | `Tests/CoreTests/SquareRouteMapVerifiedTests.swift` · `11e7c2c45`, `d091fdab3` |
| `QuestifyCoreTests/SquareRouteMapVerifiedTests/testDuplicateStopIsNotInventedAndARoadlessChapterIsSkippedOnlyWhenItHasNoStop` | Added (new file) | `Tests/CoreTests/SquareRouteMapVerifiedTests.swift` · `11e7c2c45`, `d091fdab3` |
| `QuestifyCoreTests/SquareRouteMapVerifiedTests/testMissingBrokenOrPartialGeometryHidesTheMap` | Added (new file) | `Tests/CoreTests/SquareRouteMapVerifiedTests.swift` · `11e7c2c45`, `d091fdab3` |
| `QuestifyCoreTests/SquareRouteMapVerifiedTests/testUnknownTitleIsAnEmDash` | Added (new file) | `Tests/CoreTests/SquareRouteMapVerifiedTests.swift` · `11e7c2c45`, `d091fdab3` |
| `QuestifyCoreTests/SquareRouteMapVerifiedTests/testVerifiedStringGeometrySortsStopsAndKeepsTheRoadOffTheNodes` | Added (new file) | `Tests/CoreTests/SquareRouteMapVerifiedTests.swift` · `11e7c2c45`, `d091fdab3` |
| `QuestifyCoreTests/SquareStravaCardTests/testDraftMemberMismatchAndUnknownLock` | Added (new file) | `Tests/CoreTests/SquareStravaCardTests.swift` · `5362ae56f`, `2b32c132f` |
| `QuestifyCoreTests/SquareStravaCardTests/testHostedActivitiesComeFirstAndDuplicateIdsDrop` | Added (new file) | `Tests/CoreTests/SquareStravaCardTests.swift` · `5362ae56f`, `2b32c132f` |
| `QuestifyCoreTests/SquareStravaCardTests/testLiteralZeroIsKeptAndActivitySignalsShowTheBlock` | Added (new file) | `Tests/CoreTests/SquareStravaCardTests.swift` · `5362ae56f`, `2b32c132f` |
| `QuestifyCoreTests/SquareStravaCardTests/testPopoverStaysHiddenWithoutAnAnchorAndExcerptFallsBack` | Added (new file) | `Tests/CoreTests/SquareStravaCardTests.swift` · `5362ae56f`, `2b32c132f` |
| `QuestifyCoreTests/SquareStravaCardTests/testPostFollowFlagReusesTheCardDecodeAndStaysUnknown` | Added (new file) | `Tests/CoreTests/SquareStravaCardTests.swift` · `5362ae56f`, `2b32c132f` |
| `QuestifyCoreTests/SquareStravaCardTests/testRouteNeedsTwoPointsAndDropsInvalidCoordinates` | Added (new file) | `Tests/CoreTests/SquareStravaCardTests.swift` · `5362ae56f`, `2b32c132f` |
| `QuestifyCoreTests/SquareStravaCardTests/testShareOmitsPrivatePosts` | Added (new file) | `Tests/CoreTests/SquareStravaCardTests.swift` · `5362ae56f`, `2b32c132f` |
| `QuestifyCoreTests/SquareStravaCardTests/testTextPostStaysATextCard` | Added (new file) | `Tests/CoreTests/SquareStravaCardTests.swift` · `5362ae56f`, `2b32c132f` |
| `QuestifyCoreTests/StampAlbumIndexPageModelTests/testContinuationFailureKeepsTheKnownTotal` | Added (new file) | `Tests/CoreTests/StampAlbumIndexPageModelTests.swift` · `484677f45` |
| `QuestifyCoreTests/StampAlbumIndexPageModelTests/testDeniedAndSignInStayHiddenCounts` | Added (new file) | `Tests/CoreTests/StampAlbumIndexPageModelTests.swift` · `484677f45` |
| `QuestifyCoreTests/StampAlbumIndexPageModelTests/testEmptyAndUnknownTextIsAnEmDash` | Added (new file) | `Tests/CoreTests/StampAlbumIndexPageModelTests.swift` · `484677f45` |
| `QuestifyCoreTests/StampAlbumIndexPageModelTests/testErrorTokenIsKeptAndBlankUnknownOrZeroTokensAreUnknown` | Added (new file) | `Tests/CoreTests/StampAlbumIndexPageModelTests.swift` · `484677f45` |
| `QuestifyCoreTests/StampAlbumIndexPageModelTests/testKnownZeroVisibleRowsDoNotReplaceAPositiveTotal` | Added (new file) | `Tests/CoreTests/StampAlbumIndexPageModelTests.swift` · `484677f45` |
| `QuestifyCoreTests/StampAlbumIndexPageModelTests/testLiteralTotalStaysAndNumericStringDoesNotBecomeZero` | Added (new file) | `Tests/CoreTests/StampAlbumIndexPageModelTests.swift` · `484677f45` |
| `QuestifyCoreTests/StampAlbumIndexPageModelTests/testLoadingHidesAStaleZeroAndAStaleFailure` | Added (new file) | `Tests/CoreTests/StampAlbumIndexPageModelTests.swift` · `484677f45` |
| `QuestifyCoreTests/StampAlbumIndexPageModelTests/testMalformedAndUnreadableCodeDoNotBecomeZero` | Added (new file) | `Tests/CoreTests/StampAlbumIndexPageModelTests.swift` · `484677f45` |
| `QuestifyCoreTests/StampAlbumIndexPageModelTests/testPaymentSwitchesStayFalse` | Added (new file) | `Tests/CoreTests/StampAlbumIndexPageModelTests.swift` · `484677f45` |
| `QuestifyCoreTests/StampAlbumIndexPageModelTests/testRouteStaysTheExistingListContractAndCaptureStaysHidden` | Added (new file) | `Tests/CoreTests/StampAlbumIndexPageModelTests.swift` · `484677f45` |
| `QuestifyCoreTests/StampAlbumIndexPagerProjectionTests/testDeniedReadDoesNotBecomeAnEmptyAlbum` | Added (new file) | `Tests/CoreTests/StampAlbumIndexPageModelTests.swift` · `484677f45` |
| `QuestifyCoreTests/StampAlbumIndexPagerProjectionTests/testUnreadPagerIsUnknownAndAReadKeepsTheServerTotal` | Added (new file) | `Tests/CoreTests/StampAlbumIndexPageModelTests.swift` · `484677f45` |
| `QuestifyCoreTests/StampCameraPageReadyTests/testConfirmedAlbumCountStaysLiteral` | Added (new file) | `Tests/CoreTests/StampCameraPageReadyTests.swift` · `d8b396d1a` |
| `QuestifyCoreTests/StampCameraPageReadyTests/testEmptyAlbumAndEmptyScreenUseTheDash` | Added (new file) | `Tests/CoreTests/StampCameraPageReadyTests.swift` · `d8b396d1a` |
| `QuestifyCoreTests/StampCameraPageReadyTests/testErrorKeepsANonNumericMessage` | Added (new file) | `Tests/CoreTests/StampCameraPageReadyTests.swift` · `d8b396d1a` |
| `QuestifyCoreTests/StampCameraPageReadyTests/testFixtureDataMatchesTheProjection` | Added (new file) | `Tests/CoreTests/StampCameraPageReadyTests.swift` · `d8b396d1a` |
| `QuestifyCoreTests/StampCameraPageReadyTests/testKnownCaptionLengthZeroStaysZero` | Added (new file) | `Tests/CoreTests/StampCameraPageReadyTests.swift` · `d8b396d1a` |
| `QuestifyCoreTests/StampCameraPageReadyTests/testLoadingWinsAndShowsNeitherDashNorZero` | Added (new file) | `Tests/CoreTests/StampCameraPageReadyTests.swift` · `d8b396d1a` |
| `QuestifyCoreTests/StampCameraPageReadyTests/testNumericStringAndUnknownTokenAreNotGuessed` | Added (new file) | `Tests/CoreTests/StampCameraPageReadyTests.swift` · `d8b396d1a` |
| `QuestifyCoreTests/StampCameraPageReadyTests/testUnknownMissingAndNonPositiveCreatedIDAreDash` | Added (new file) | `Tests/CoreTests/StampCameraPageReadyTests.swift` · `d8b396d1a` |
| `QuestifyCoreTests/StampCameraPageReadyTests/testWritesStayHiddenAndListStaysUnregistered` | Added (new file) | `Tests/CoreTests/StampCameraPageReadyTests.swift` · `d8b396d1a` |
| `QuestifyCoreTests/TeamCommandWriterTests/testUnknownKeepsTheRequestIDUntil2xxOr4xx` | Added (new file) | `Tests/CoreTests/TeamCommandWriterTests.swift` · `50d3ac23e`, `d85088b19`, `89f841a26`, `aafc5179c` |
| `QuestifyCoreTests/TeamCreateClosedLeaseTests/testClosedLeaseShowsTheRefusalAndDoesNotSend` | Added (new file) | `Tests/CoreTests/TeamCreateClosedLeaseTests.swift` · `6367e0916` |
| `QuestifyCoreTests/TeamCreateClosedLeaseTests/testCreateBodyRejectsMoneyAndAcceptsTheOwnedRegistrationShape` | Added (new file) | `Tests/CoreTests/TeamCreateClosedLeaseTests.swift` · `6367e0916` |
| `QuestifyCoreTests/TeamCreateClosedLeaseTests/testTeamOpenMatchesTheMiniProgramRule` | Added (new file) | `Tests/CoreTests/TeamCreateClosedLeaseTests.swift` · `6367e0916` |
| `QuestifyCoreTests/TeamOrientBoardTests/testOmittedCountsAreEmDashAndLiteralZeroStaysZero` | Added (existing file) | `Tests/CoreTests/TeamOrientBoardTests.swift` · `c5150bf32` |
| `QuestifyCoreTests/TeamPagePresentationTests/testDetailPhaseCoversLoadingEmptyErrorUnknownAndReady` | Added (existing file) | `Tests/CoreTests/TeamPagePresentationTests.swift` · `c5150bf32` |
| `QuestifyCoreTests/TeamPagePresentationTests/testInvitationMemberCountUnknownIsEmDashAndZeroStaysZero` | Added (existing file) | `Tests/CoreTests/TeamPagePresentationTests.swift` · `c5150bf32` |
| `QuestifyCoreTests/TeamPagePresentationTests/testInvitationReadoutSeparatesLoadingEmptyAndError` | Added (existing file) | `Tests/CoreTests/TeamPagePresentationTests.swift` · `c5150bf32` |
| `QuestifyCoreTests/TeamPagePresentationTests/testMemberCountUnknownIsEmDashAndLiteralZeroStaysZero` | Added (existing file) | `Tests/CoreTests/TeamPagePresentationTests.swift` · `c5150bf32` |
| `QuestifyCoreTests/TeamPageSecondPassTests/testJoinIndexFixtureKeepsOmittedCountsUnknown` | Added (existing file) | `Tests/CoreTests/TeamPageSecondPassTests.swift` · `c5150bf32` |
| `QuestifyCoreTests/TeamPageSecondPassTests/testLoadedDetailPhaseUsesServerCountsAndFailureIsNotZero` | Added (existing file) | `Tests/CoreTests/TeamPageSecondPassTests.swift` · `c5150bf32` |
| `QuestifyCoreTests/TeamSeatFactsTests/testCodedRejectionsBranchOnMachineCodeOnly` | Added (new file) | `Tests/CoreTests/TeamSeatFactsTests.swift` · `c28c3d24c` |
| `QuestifyCoreTests/TeamSeatFactsTests/testDutyAndLeaveConsequenceSeparateCaptainFromMember` | Added (new file) | `Tests/CoreTests/TeamSeatFactsTests.swift` · `c28c3d24c` |
| `QuestifyCoreTests/TeamSeatFactsTests/testInvitationPreviewMembersWithoutIdsDecodeButCannotBeTargets` | Added (new file) | `Tests/CoreTests/TeamSeatFactsTests.swift` · `c28c3d24c` |
| `QuestifyCoreTests/TeamSeatFactsTests/testInviteLineReplaysServerDeadline` | Added (new file) | `Tests/CoreTests/TeamSeatFactsTests.swift` · `c28c3d24c` |
| `QuestifyCoreTests/TeamSeatFactsTests/testSeatRowsFollowMiniProgramAndOmitUnknown` | Added (new file) | `Tests/CoreTests/TeamSeatFactsTests.swift` · `c28c3d24c` |
| `QuestifyCoreTests/TemplateAuthoringIntroReadModelTests/testCoordinatorReadsExistingHomeAndHidesAFailedRead` | Added (new file) | `Tests/CoreTests/TemplateAuthoringIntroReadModelTests.swift` · `4f180d862` |
| `QuestifyCoreTests/TemplateAuthoringIntroReadModelTests/testEmptyIsDistinctFromUnknownAndFromLiteralZero` | Added (new file) | `Tests/CoreTests/TemplateAuthoringIntroReadModelTests.swift` · `4f180d862` |
| `QuestifyCoreTests/TemplateAuthoringIntroReadModelTests/testFixtureRecommendedPoolKeepsCategoryAndSkipsOtherPools` | Added (new file) | `Tests/CoreTests/TemplateAuthoringIntroReadModelTests.swift` · `4f180d862` |
| `QuestifyCoreTests/TemplateAuthoringIntroReadModelTests/testLoadingAndUnknownAreEmDashNeverZero` | Added (new file) | `Tests/CoreTests/TemplateAuthoringIntroReadModelTests.swift` · `4f180d862` |
| `QuestifyCoreTests/TemplateAuthoringIntroReadModelTests/testNonIntegerCountsAreUnknownAndNegativeUseIsError` | Added (new file) | `Tests/CoreTests/TemplateAuthoringIntroReadModelTests.swift` · `4f180d862` |
| `QuestifyCoreTests/TemplateAuthoringIntroReadModelTests/testPrefixStaysThreeAndDecodedHomeNilCountIsUnknown` | Added (new file) | `Tests/CoreTests/TemplateAuthoringIntroReadModelTests.swift` · `4f180d862` |
| `QuestifyCoreTests/TemplateAuthoringIntroReadModelTests/testRefreshFailureKeepsReadyCardsAndEmptySuccessClearsThem` | Added (new file) | `Tests/CoreTests/TemplateAuthoringIntroReadModelTests.swift` · `4f180d862` |
| `QuestifyCoreTests/TemplateAuthoringIntroReadModelTests/testSingleFlightAndCancelDropTheLateDocument` | Added (new file) | `Tests/CoreTests/TemplateAuthoringIntroReadModelTests.swift` · `4f180d862` |
| `QuestifyCoreTests/TemplateAuthoringIntroReadModelTests/testUnknownTokensStayEmDashAndLiteralZeroStaysZero` | Added (new file) | `Tests/CoreTests/TemplateAuthoringIntroReadModelTests.swift` · `4f180d862` |
| `QuestifyCoreTests/TemplateAuthoringPageReadinessTests/testEditorPhasesKeepLiteralZeroAndUnknownDash` | Added (new file) | `Tests/CoreTests/TemplateAuthoringPageReadinessTests.swift` · `eb4f54a0c` |
| `QuestifyCoreTests/TemplateAuthoringPageReadinessTests/testLibraryInfoUsesExistingPayloadWithoutSendingOrGuessingZero` | Added (new file) | `Tests/CoreTests/TemplateAuthoringPageReadinessTests.swift` · `eb4f54a0c` |
| `QuestifyCoreTests/TemplateAuthoringPageReadinessTests/testMissingSessionAndUnreadableInfoStayHidden` | Added (new file) | `Tests/CoreTests/TemplateAuthoringPageReadinessTests.swift` · `eb4f54a0c` |
| `QuestifyCoreTests/TemplateIndexPageModelTests/testCoordinatorLoadsExistingReadsAndKeepsUnknownDistinct` | Added (new file) | `Tests/CoreTests/TemplateIndexPageModelTests.swift` · `50d3ac23e`, `c5150bf32` |
| `QuestifyCoreTests/TemplateIndexPageModelTests/testHiddenCapabilityStaysHiddenAndFlagsStayOff` | Added (new file) | `Tests/CoreTests/TemplateIndexPageModelTests.swift` · `50d3ac23e`, `c5150bf32` |
| `QuestifyCoreTests/TemplateIndexPageModelTests/testMissingChapterIsUnknownWhileLiteralZeroStaysZero` | Added (new file) | `Tests/CoreTests/TemplateIndexPageModelTests.swift` · `50d3ac23e`, `c5150bf32` |
| `QuestifyCoreTests/TemplateIndexPageModelTests/testPhasesKeepUnknownDistinctFromEmptyAndError` | Added (new file) | `Tests/CoreTests/TemplateIndexPageModelTests.swift` · `50d3ac23e`, `c5150bf32` |
| `QuestifyCoreTests/TemplateIndexPageModelTests/testPlayUseAndPlayersDoNotGuessZero` | Added (new file) | `Tests/CoreTests/TemplateIndexPageModelTests.swift` · `50d3ac23e`, `c5150bf32` |
| `QuestifyCoreTests/TemplateIndexPageModelTests/testUnknownCountIsAnEmDashAndZeroStaysZero` | Added (new file) | `Tests/CoreTests/TemplateIndexPageModelTests.swift` · `50d3ac23e`, `c5150bf32` |
| `QuestifyCoreTests/TicketWalletTests/testListTopicCompletedSplitsFiltersWithoutInventingRows` | Added (existing file) | `Tests/CoreTests/TicketWalletTests.swift` · `b9c0ebec8` |
| `QuestifyCoreTests/TopicCreatorEditorServiceTests/testAttributeBindingIsAQueryGetAndRejectsAnotherConfigVersion` | Added (new file) | `Tests/CoreTests/TopicCreatorEditorServiceTests.swift` · `aafba56c9` |
| `QuestifyCoreTests/TopicCreatorEditorServiceTests/testAuthorEditAndSavedDetailPostFormAndValidatePayload` | Added (new file) | `Tests/CoreTests/TopicCreatorEditorServiceTests.swift` · `aafba56c9` |
| `QuestifyCoreTests/TopicCreatorEditorServiceTests/testChinaGateAdmitsTheG2G3RoutesAndKeepsMoneyClosed` | Added (new file) | `Tests/CoreTests/TopicCreatorEditorServiceTests.swift` · `aafba56c9` |
| `QuestifyCoreTests/TopicCreatorEditorServiceTests/testDisabledAndRejectedAndUnauthorized` | Added (new file) | `Tests/CoreTests/TopicCreatorEditorServiceTests.swift` · `aafba56c9` |
| `QuestifyCoreTests/TopicCreatorEditorServiceTests/testOrderCenterDetailReadsSummaryAndNeverInfersPaid` | Added (new file) | `Tests/CoreTests/TopicCreatorEditorServiceTests.swift` · `aafba56c9` |
| `QuestifyCoreTests/TopicCreatorEditorServiceTests/testPlaySetupGetAndWholePutStripNextDayPrefix` | Added (new file) | `Tests/CoreTests/TopicCreatorEditorServiceTests.swift` · `aafba56c9` |
| `QuestifyCoreTests/TopicCreatorEditorServiceTests/testPublishDraftCarriesVersionsAndRequestIdAndAnUnknownStaysUnknown` | Added (new file) | `Tests/CoreTests/TopicCreatorEditorServiceTests.swift` · `aafba56c9` |
| `QuestifyCoreTests/TopicCreatorEditorServiceTests/testShareCodeHostQRCodeAndInviteChapters` | Added (new file) | `Tests/CoreTests/TopicCreatorEditorServiceTests.swift` · `aafba56c9` |
| `QuestifyCoreTests/TopicCreatorEditorServiceTests/testStateKeysListNamedCreateAndRename` | Added (new file) | `Tests/CoreTests/TopicCreatorEditorServiceTests.swift` · `aafba56c9` |
| `QuestifyCoreTests/TopicCreatorEditorServiceTests/testSupplyTermsSendsOnlyPerkOrTrafficAndNoFee` | Added (new file) | `Tests/CoreTests/TopicCreatorEditorServiceTests.swift` · `aafba56c9` |
| `QuestifyCoreTests/TopicPricingPageReadyTests/testBlockedConfirmAndLiteralZeroReference` | Added (new file) | `Tests/CoreTests/TopicPricingPageReadyTests.swift` · `575baf797` |
| `QuestifyCoreTests/TopicPricingPageReadyTests/testGuidedZeroTeamCannotSubmitEvenWhenFloorIsZero` | Added (new file) | `Tests/CoreTests/TopicPricingPageReadyTests.swift` · `575baf797` |
| `QuestifyCoreTests/TopicPricingPageReadyTests/testLiteralZeroFloorStaysZeroAndUnknownConfirmIsNotBlocked` | Added (new file) | `Tests/CoreTests/TopicPricingPageReadyTests.swift` · `575baf797` |
| `QuestifyCoreTests/TopicPricingPageReadyTests/testLoadingEmptyErrorAndUnknownStayDistinct` | Added (new file) | `Tests/CoreTests/TopicPricingPageReadyTests.swift` · `575baf797` |
| `QuestifyCoreTests/TopicPricingPageReadyTests/testMissingCapabilityStaysHiddenAndPlayerFirstNeverEnters` | Added (new file) | `Tests/CoreTests/TopicPricingPageReadyTests.swift` · `575baf797` |
| `QuestifyCoreTests/TopicPricingPageReadyTests/testMissingTopicIsEmptyAndDoesNotInventAZeroFloor` | Added (new file) | `Tests/CoreTests/TopicPricingPageReadyTests.swift` · `575baf797` |
| `QuestifyCoreTests/TopicPricingPageReadyTests/testRefreshKeepsThePreviousFloor` | Added (new file) | `Tests/CoreTests/TopicPricingPageReadyTests.swift` · `575baf797` |
| `QuestifyCoreTests/TopicPricingPageReadyTests/testUnknownMoneyIsADashAndLiteralZeroStaysZero` | Added (new file) | `Tests/CoreTests/TopicPricingPageReadyTests.swift` · `575baf797` |
| `QuestifyCoreTests/TopicPricingPageReadyTests/testWelcomeStaysPlayerFirst` | Added (new file) | `Tests/CoreTests/TopicPricingPageReadyTests.swift` · `575baf797` |
| `QuestifyCoreTests/TopicPricingXcxTests/testMerchantPartnerProfileProjectsHomeFactsWithoutChargeOrZeroFill` | Added (existing file) | `Tests/CoreTests/TopicPricingXcxTests.swift` · `226c530e7` |
| `QuestifyCoreTests/TopicPricingXcxTests/testPartnerMoneyUnknownIsDashAndZeroStaysZero` | Added (existing file) | `Tests/CoreTests/TopicPricingXcxTests.swift` · `226c530e7` |
| `QuestifyCoreTests/TopicPricingXcxTests/testPartnerPreviewPhaseCoversLoadingEmptyErrorAndUnknown` | Added (existing file) | `Tests/CoreTests/TopicPricingXcxTests.swift` · `226c530e7` |
| `QuestifyCoreTests/TopicTemplateAdoptionTests/testConditionRowsOnlyFromAuthoritativeFacts` | Added (new file) | `Tests/CoreTests/TopicTemplateAdoptionTests.swift` · `15aa3dad9` |
| `QuestifyCoreTests/TopicTemplateAdoptionTests/testCreditShowsAttributionOnly` | Added (new file) | `Tests/CoreTests/TopicTemplateAdoptionTests.swift` · `15aa3dad9` |
| `QuestifyCoreTests/TopicTemplateAdoptionTests/testEditorNodeMappingClaimsOnlyUniqueSameName` | Added (new file) | `Tests/CoreTests/TopicTemplateAdoptionTests.swift` · `15aa3dad9` |
| `QuestifyCoreTests/TopicTemplateAdoptionTests/testMalformedDeliveryDoesNotBreakTheDetail` | Added (new file) | `Tests/CoreTests/TopicTemplateAdoptionTests.swift` · `15aa3dad9` |
| `QuestifyCoreTests/TopicTemplateAdoptionTests/testRequestIdFormat` | Added (new file) | `Tests/CoreTests/TopicTemplateAdoptionTests.swift` · `15aa3dad9` |
| `QuestifyCoreTests/TopicTemplateAdoptionTests/testTodosModelKeepsLastViewOnFailureAndRereadsOnUnknown` | Added (new file) | `Tests/CoreTests/TopicTemplateAdoptionTests.swift` · `15aa3dad9` |
| `QuestifyCoreTests/TopicTemplateAdoptionTests/testTodosOnlyErrorBlocksAndUnknownStatusIsNotBound` | Added (new file) | `Tests/CoreTests/TopicTemplateAdoptionTests.swift` · `15aa3dad9` |
| `QuestifyCoreTests/TopicTemplateAdoptionTests/testUseReceiptKeepsTopicIdObjectAndIncrement` | Added (new file) | `Tests/CoreTests/TopicTemplateAdoptionTests.swift` · `15aa3dad9` |
| `QuestifyCoreTests/TopicTemplateUseTests/testCopiedMessageCountsOnlyErrorIssuesAsBlocking` | Added (existing file) | `Tests/CoreTests/TopicTemplateUseTests.swift` · `15aa3dad9` |
| `QuestifyCoreTests/TopicTemplateUseTests/testFailureIsNotSuccessAndMintsAFreshIdNextTime` | Added (existing file) | `Tests/CoreTests/TopicTemplateUseTests.swift` · `15aa3dad9` |
| `QuestifyCoreTests/TopicTemplateUseTests/testPlacedTemplateSendsSameCityAndRevisionNeverNewCity` | Added (existing file) | `Tests/CoreTests/TopicTemplateUseTests.swift` · `15aa3dad9` |
| `QuestifyCoreTests/TopicTemplateUseTests/testSecondTapAfterCopyReopensTheSameDraft` | Added (existing file) | `Tests/CoreTests/TopicTemplateUseTests.swift` · `15aa3dad9` |
| `QuestifyCoreTests/TopicTemplateUseTests/testUnknownKeepsRequestIdUntilTheReceiptIsRead` | Added (existing file) | `Tests/CoreTests/TopicTemplateUseTests.swift` · `15aa3dad9` |
| `QuestifyCoreTests/TopicTests/testDetailDocumentIsTheSameInfoToUserBody` | Added (existing file) | `Tests/CoreTests/TopicTests.swift` · `89f841a26`, `d091fdab3` |
| `QuestifyCoreTests/UGGameplayTests/testAbsentCapabilityHidesTheFeatureAndUndeclaredDoesNotBlock` | Added (new file) | `Tests/CoreTests/UGGameplayTests.swift` · `d85088b19`, `89f841a26`, `a086ae037`, `776df1ac7`, `4ecbb385e` (+1 more) |
| `QuestifyCoreTests/UGGameplayTests/testAccusationDropsAnObjectScreenAndASecretSuspect` | Added (new file) | `Tests/CoreTests/UGGameplayTests.swift` · `d85088b19`, `89f841a26`, `a086ae037`, `776df1ac7`, `4ecbb385e` (+1 more) |
| `QuestifyCoreTests/UGGameplayTests/testAccusationIsNotPublishableAndDropsSecrets` | Added (new file) | `Tests/CoreTests/UGGameplayTests.swift` · `d85088b19`, `89f841a26`, `a086ae037`, `776df1ac7`, `4ecbb385e` (+1 more) |
| `QuestifyCoreTests/UGGameplayTests/testAnswerLayerStaysKnownAndALongDigitIsNotShown` | Added (new file) | `Tests/CoreTests/UGGameplayTests.swift` · `d85088b19`, `89f841a26`, `a086ae037`, `776df1ac7`, `4ecbb385e` (+1 more) |
| `QuestifyCoreTests/UGGameplayTests/testClueNamesStayLiteralAndFlipIsNotAMirror` | Added (new file) | `Tests/CoreTests/UGGameplayTests.swift` · `d85088b19`, `89f841a26`, `a086ae037`, `776df1ac7`, `4ecbb385e` (+1 more) |
| `QuestifyCoreTests/UGGameplayTests/testClueTransformDoesNotReverseTwiceOrGuess` | Added (new file) | `Tests/CoreTests/UGGameplayTests.swift` · `d85088b19`, `89f841a26`, `a086ae037`, `776df1ac7`, `4ecbb385e` (+1 more) |
| `QuestifyCoreTests/UGGameplayTests/testContractOrderHidesSkipGemAndPublish` | Added (new file) | `Tests/CoreTests/UGGameplayTests.swift` · `d85088b19`, `89f841a26`, `a086ae037`, `776df1ac7`, `4ecbb385e` (+1 more) |
| `QuestifyCoreTests/UGGameplayTests/testCoreSourcesCarryNoFixtureAnswerWalletOrLiveSession` | Added (new file) | `Tests/CoreTests/UGGameplayTests.swift` · `d85088b19`, `89f841a26`, `a086ae037`, `776df1ac7`, `4ecbb385e` (+1 more) |
| `QuestifyCoreTests/UGGameplayTests/testEarlyCloseIsNotFailureAndUnreadableProgressIsPending` | Added (new file) | `Tests/CoreTests/UGGameplayTests.swift` · `d85088b19`, `89f841a26`, `a086ae037`, `776df1ac7`, `4ecbb385e` (+1 more) |
| `QuestifyCoreTests/UGGameplayTests/testFractionalNumbersStayUnknown` | Added (new file) | `Tests/CoreTests/UGGameplayTests.swift` · `d85088b19`, `89f841a26`, `a086ae037`, `776df1ac7`, `4ecbb385e` (+1 more) |
| `QuestifyCoreTests/UGGameplayTests/testHangmanDropsPrivateKeysAndKeepsASeparator` | Added (new file) | `Tests/CoreTests/UGGameplayTests.swift` · `d85088b19`, `89f841a26`, `a086ae037`, `776df1ac7`, `4ecbb385e` (+1 more) |
| `QuestifyCoreTests/UGGameplayTests/testHangmanProjectionDoesNotStoreOrCutTheAnswer` | Added (new file) | `Tests/CoreTests/UGGameplayTests.swift` · `d85088b19`, `89f841a26`, `a086ae037`, `776df1ac7`, `4ecbb385e` (+1 more) |
| `QuestifyCoreTests/UGGameplayTests/testHangmanSubmitPostsTheAdvancedActionAndKeepsAnUnknownRequestID` | Added (new file) | `Tests/CoreTests/UGGameplayTests.swift` · `d85088b19`, `89f841a26`, `a086ae037`, `776df1ac7`, `4ecbb385e` (+1 more) |
| `QuestifyCoreTests/UGGameplayTests/testHelpLadderKeepsLegacyAndRejectsUnknownTypesGemsAndSkipControl` | Added (new file) | `Tests/CoreTests/UGGameplayTests.swift` · `d85088b19`, `89f841a26`, `a086ae037`, `776df1ac7`, `4ecbb385e` (+1 more) |
| `QuestifyCoreTests/UGGameplayTests/testHelpReceiptDoesNotRenderUnknownOrNotScoredAsZero` | Added (new file) | `Tests/CoreTests/UGGameplayTests.swift` · `d85088b19`, `89f841a26`, `a086ae037`, `776df1ac7`, `4ecbb385e` (+1 more) |
| `QuestifyCoreTests/UGGameplayTests/testHelpUseDoesNotSliceOrOpenAWallet` | Added (new file) | `Tests/CoreTests/UGGameplayTests.swift` · `d85088b19`, `89f841a26`, `a086ae037`, `776df1ac7`, `4ecbb385e` (+1 more) |
| `QuestifyCoreTests/UGGameplayTests/testImageOptionDropsUndeliveredMediaAndDoesNotStoreCorrect` | Added (new file) | `Tests/CoreTests/UGGameplayTests.swift` · `d85088b19`, `89f841a26`, `a086ae037`, `776df1ac7`, `4ecbb385e` (+1 more) |
| `QuestifyCoreTests/UGGameplayTests/testReaderRefusesProductionWritesAndAnAbsentGrant` | Added (new file) | `Tests/CoreTests/UGGameplayTests.swift` · `d85088b19`, `89f841a26`, `a086ae037`, `776df1ac7`, `4ecbb385e` (+1 more) |
| `QuestifyCoreTests/UGGameplayTests/testReaderRejectsALeadingZeroAndDropsAStaleOrFailedRead` | Added (new file) | `Tests/CoreTests/UGGameplayTests.swift` · `d85088b19`, `89f841a26`, `a086ae037`, `776df1ac7`, `4ecbb385e` (+1 more) |
| `QuestifyCoreTests/UGGameplayTests/testReceiptKeepsBonusSourceOffTheNet` | Added (new file) | `Tests/CoreTests/UGGameplayTests.swift` · `d85088b19`, `89f841a26`, `a086ae037`, `776df1ac7`, `4ecbb385e` (+1 more) |
| `QuestifyCoreTests/UGGameplayTests/testReceiptUnknownStaysPendingAndScopeChangeDiscards` | Added (new file) | `Tests/CoreTests/UGGameplayTests.swift` · `d85088b19`, `89f841a26`, `a086ae037`, `776df1ac7`, `4ecbb385e` (+1 more) |
| `QuestifyCoreTests/UGGameplayTests/testRunQuotaDoesNotPreferRootOrTurnUnknownIntoZero` | Added (new file) | `Tests/CoreTests/UGGameplayTests.swift` · `d85088b19`, `89f841a26`, `a086ae037`, `776df1ac7`, `4ecbb385e` (+1 more) |
| `QuestifyCoreTests/UGGameplayTests/testSameHelpRequestIsNotAConflict` | Added (new file) | `Tests/CoreTests/UGGameplayTests.swift` · `d85088b19`, `89f841a26`, `a086ae037`, `776df1ac7`, `4ecbb385e` (+1 more) |
| `QuestifyCoreTests/UGGameplayTests/testUnknownNumbersAreNeverZero` | Added (new file) | `Tests/CoreTests/UGGameplayTests.swift` · `d85088b19`, `89f841a26`, `a086ae037`, `776df1ac7`, `4ecbb385e` (+1 more) |
| `QuestifyCoreTests/UniversalLinkParserTests/testDefaultConfigurationClaimsNoDomainAndAcceptsNothing` | Added (new file) | `Tests/CoreTests/UniversalLinkParserTests.swift` · `ca4f39acd`, `ab93558a1` |
| `QuestifyCoreTests/UniversalLinkParserTests/testFixtureHostAgreesWithTypedRouterOnKnownRoutes` | Added (new file) | `Tests/CoreTests/UniversalLinkParserTests.swift` · `ca4f39acd`, `ab93558a1` |
| `QuestifyCoreTests/UniversalLinkParserTests/testLiteralLocalAndSingleLabelHostsStayClosedEvenWhenListed` | Added (new file) | `Tests/CoreTests/UniversalLinkParserTests.swift` · `ca4f39acd`, `ab93558a1` |
| `QuestifyCoreTests/UniversalLinkParserTests/testMalformedOriginsCannotReviveAHost` | Added (new file) | `Tests/CoreTests/UniversalLinkParserTests.swift` · `ca4f39acd`, `ab93558a1` |
| `QuestifyCoreTests/UniversalLinkParserTests/testOptionalAddressFormsStayClosedWhenTheySurviveParsing` | Added (new file) | `Tests/CoreTests/UniversalLinkParserTests.swift` · `ca4f39acd`, `ab93558a1` |
| `QuestifyCoreTests/UniversalLinkParserTests/testOverlongAndTraversalNeverReachARoute` | Added (new file) | `Tests/CoreTests/UniversalLinkParserTests.swift` · `ca4f39acd`, `ab93558a1` |
| `QuestifyCoreTests/UniversalLinkParserTests/testTrailingSlashOriginIsNormalizedWithoutOpeningTheTypedRouter` | Added (new file) | `Tests/CoreTests/UniversalLinkParserTests.swift` · `ca4f39acd`, `ab93558a1` |
| `QuestifyCoreTests/VideoBountySourceTests/testAppealAndCancelLockTheirOwnIdsAndASuccessClearsOnlyThatId` | Added (new file) | `Tests/CoreTests/VideoBountySourceTests.swift` · `0242ef8d3`, `27b8a4ffc`, `50d3ac23e`, `f85385a8b` |
| `QuestifyCoreTests/VideoBountySourceTests/testCampaignListKeepsOnlyServerRows` | Added (new file) | `Tests/CoreTests/VideoBountySourceTests.swift` · `0242ef8d3`, `27b8a4ffc`, `50d3ac23e`, `f85385a8b` |
| `QuestifyCoreTests/VideoBountySourceTests/testChinaGrantAdmitsOnlyTheVideoBountyPathsThisClientCalls` | Added (new file) | `Tests/CoreTests/VideoBountySourceTests.swift` · `0242ef8d3`, `27b8a4ffc`, `50d3ac23e`, `f85385a8b` |
| `QuestifyCoreTests/VideoBountySourceTests/testChinaHostSendsTheCampaignList` | Added (new file) | `Tests/CoreTests/VideoBountySourceTests.swift` · `0242ef8d3`, `27b8a4ffc`, `50d3ac23e`, `f85385a8b` |
| `QuestifyCoreTests/VideoBountySourceTests/testEmptyCampaignListStaysEmptyAndANonArrayDoesNotBecomeOne` | Added (new file) | `Tests/CoreTests/VideoBountySourceTests.swift` · `0242ef8d3`, `27b8a4ffc`, `50d3ac23e`, `f85385a8b` |
| `QuestifyCoreTests/VideoBountySourceTests/testMissingAmountIsNilAndARecordedZeroStaysZero` | Added (new file) | `Tests/CoreTests/VideoBountySourceTests.swift` · `0242ef8d3`, `27b8a4ffc`, `50d3ac23e`, `f85385a8b` |
| `QuestifyCoreTests/VideoBountySourceTests/testReadsAreTheMineListsAndTheCampaignList` | Added (new file) | `Tests/CoreTests/VideoBountySourceTests.swift` · `0242ef8d3`, `27b8a4ffc`, `50d3ac23e`, `f85385a8b` |
| `QuestifyCoreTests/VideoBountySourceTests/testRereadWithoutASavedIdSendsNothing` | Added (new file) | `Tests/CoreTests/VideoBountySourceTests.swift` · `0242ef8d3`, `27b8a4ffc`, `50d3ac23e`, `f85385a8b` |
| `QuestifyCoreTests/VideoBountySourceTests/testSubmissionRulesMatchTheMiniProgram` | Added (new file) | `Tests/CoreTests/VideoBountySourceTests.swift` · `0242ef8d3`, `27b8a4ffc`, `50d3ac23e`, `f85385a8b` |
| `QuestifyCoreTests/VideoBountySourceTests/testUnknownSubmitStaysOnTheSameRequestIdUntilAConfirmedAnswer` | Added (new file) | `Tests/CoreTests/VideoBountySourceTests.swift` · `0242ef8d3`, `27b8a4ffc`, `50d3ac23e`, `f85385a8b` |
| `QuestifyCoreTests/WP04CoopSquareDeleteTests/testAuthorDeleteRereadsTheListWithoutThePost` | Added (new file) | `Tests/CoreTests/WP04CoopSquareDeleteTests.swift` · `e83825c86` |
| `QuestifyCoreTests/WP04CoopSquareDeleteTests/testClientTypesBuildTheFivePaths` | Added (new file) | `Tests/CoreTests/WP04CoopSquareDeleteTests.swift` · `e83825c86` |
| `QuestifyCoreTests/WP04CoopSquareDeleteTests/testReadsAreGetAndMarkReadIsPost` | Added (new file) | `Tests/CoreTests/WP04CoopSquareDeleteTests.swift` · `e83825c86` |
| `QuestifyCoreTests/WP07CommerceClientTests/testCouponUsabilityKeepsDeductionAtZero` | Added (new file) | `Tests/CoreTests/WP07CommerceClientTests.swift` · `84571b689`, `00a0b335b`, `4a3fbac20` |
| `QuestifyCoreTests/WP07CommerceClientTests/testCreateAndActivateDoNotSendAndDoNotOpenOnTheProductionHost` | Added (new file) | `Tests/CoreTests/WP07CommerceClientTests.swift` · `84571b689`, `00a0b335b`, `4a3fbac20` |
| `QuestifyCoreTests/WP07CommerceClientTests/testEmptyQuoteIsEmptyAndMissingTotalIsUnknown` | Added (new file) | `Tests/CoreTests/WP07CommerceClientTests.swift` · `84571b689`, `00a0b335b`, `4a3fbac20` |
| `QuestifyCoreTests/WP07CommerceClientTests/testGroupQuoteUsesServerTierAndPayAmountNotCatalogCash` | Added (new file) | `Tests/CoreTests/WP07CommerceClientTests.swift` · `84571b689`, `00a0b335b`, `4a3fbac20` |
| `QuestifyCoreTests/WP08DeepLinkAuditCoverageTests/testClosedSegmentsCannotBeReclassifiedAsSafeDestinations` | Added (new file) | `Tests/CoreTests/WP08DeepLinkAuditCoverageTests.swift` · `7febb7051` |
| `QuestifyCoreTests/WP08DeepLinkAuditCoverageTests/testEveryAppEntryURLShapeHasAClassification` | Added (new file) | `Tests/CoreTests/WP08DeepLinkAuditCoverageTests.swift` · `7febb7051` |
| `QuestifyCoreTests/WP08DeepLinkAuditCoverageTests/testNavigationIntentOpensOnlyPublicTopicTeamAndMerchant` | Added (new file) | `Tests/CoreTests/WP08DeepLinkAuditCoverageTests.swift` · `7febb7051` |
| `QuestifyCoreTests/WP08HostTipSurfaceTests/testAttributionNullsStayUnknownAndNotZero` | Added (new file) | `Tests/CoreTests/WP08HostTipSurfaceTests.swift` · `0242ef8d3` |
| `QuestifyCoreTests/WP08HostTipSurfaceTests/testChannelProviderOffIsUnavailable` | Added (new file) | `Tests/CoreTests/WP08HostTipSurfaceTests.swift` · `0242ef8d3` |
| `QuestifyCoreTests/WP08HostTipSurfaceTests/testConfigBodyOmitsShareAndPayFields` | Added (new file) | `Tests/CoreTests/WP08HostTipSurfaceTests.swift` · `0242ef8d3` |
| `QuestifyCoreTests/WP08HostTipSurfaceTests/testGrantCoversTheNamedRoutesAndLeavesMoneyClosed` | Added (new file) | `Tests/CoreTests/WP08HostTipSurfaceTests.swift` · `0242ef8d3` |
| `QuestifyCoreTests/WP08HostTipSurfaceTests/testHostTipReadPathsAreTheMineRoutes` | Added (new file) | `Tests/CoreTests/WP08HostTipSurfaceTests.swift` · `0242ef8d3` |
| `QuestifyCoreTests/WP08HostTipSurfaceTests/testLandingSaveOmitsPriceAndApprovedStatus` | Added (new file) | `Tests/CoreTests/WP08HostTipSurfaceTests.swift` · `0242ef8d3` |
| `QuestifyCoreTests/WP08HostTipSurfaceTests/testMissingPrepareAmountIsAnEmDash` | Added (new file) | `Tests/CoreTests/WP08HostTipSurfaceTests.swift` · `0242ef8d3` |
| `QuestifyCoreTests/WP08HostTipSurfaceTests/testPrepare501IsUnavailableAndNotAPayment` | Added (new file) | `Tests/CoreTests/WP08HostTipSurfaceTests.swift` · `0242ef8d3` |
| `QuestifyCoreTests/WP08HostTipSurfaceTests/testRedeemedReceiptKeepsLiteralZeroAndDashesMissingFields` | Added (new file) | `Tests/CoreTests/WP08HostTipSurfaceTests.swift` · `0242ef8d3` |
| `QuestifyCoreTests/WP11SessionLocationTests/testOwn10_3UnconfirmedNeverBlocksAndUnsupportedNamesMissingKeys` | Added (new file) | `Tests/CoreTests/WP11SessionLocationTests.swift` · `ce5e28999`, `1e48434aa` |
| `QuestifyCoreTests/WP11SessionLocationTests/testOwnD01aSpendRulesListedSeparatelyAndDeletedRowsDropped` | Added (new file) | `Tests/CoreTests/WP11SessionLocationTests.swift` · `ce5e28999`, `1e48434aa` |
| `QuestifyCoreTests/WP11SessionLocationTests/testOwnD01bTwoRefusalReasonsFromTheServerQuote` | Added (new file) | `Tests/CoreTests/WP11SessionLocationTests.swift` · `ce5e28999`, `1e48434aa` |
| `QuestifyCoreTests/WP11SessionLocationTests/testOwnD01cClientPriceDoesNotApplyAPointRate` | Added (new file) | `Tests/CoreTests/WP11SessionLocationTests.swift` · `ce5e28999`, `1e48434aa` |
| `QuestifyCoreTests/WP11SessionLocationTests/testOwnD07aBackgroundFlagsOnlyWhileABackgroundHoldExists` | Added (new file) | `Tests/CoreTests/WP11SessionLocationTests.swift` · `ce5e28999`, `1e48434aa` |
| `QuestifyCoreTests/WP11SessionLocationTests/testOwnD07aReferenceCountedHoldsStopOnlyAtZero` | Added (new file) | `Tests/CoreTests/WP11SessionLocationTests.swift` · `ce5e28999`, `1e48434aa` |
| `QuestifyCoreTests/WP11SessionLocationTests/testOwnD07dAccountChangeReleasesWithinOneCallback` | Added (new file) | `Tests/CoreTests/WP11SessionLocationTests.swift` · `ce5e28999`, `1e48434aa` |
| `QuestifyCoreTests/WP11SessionLocationTests/testOwnD07dDriverFailureEndsEveryHoldAndTellsItsOwner` | Added (new file) | `Tests/CoreTests/WP11SessionLocationTests.swift` · `ce5e28999`, `1e48434aa` |
| `QuestifyCoreTests/WP11SessionLocationTests/testOwnD07dNoHoldMeansNoUpdatesAndBackgroundIsNotARelease` | Added (new file) | `Tests/CoreTests/WP11SessionLocationTests.swift` · `ce5e28999`, `1e48434aa` |
| `QuestifyCoreTests/WP11SessionLocationTests/testOwnD07dRevokeMovesRevisionNotifiesAndKeepsOtherPurposes` | Added (new file) | `Tests/CoreTests/WP11SessionLocationTests.swift` · `ce5e28999`, `1e48434aa` |
| `QuestifyCoreTests/WP11SessionLocationTests/testOwnD07ePurposesListedForThePrivacyPage` | Added (new file) | `Tests/CoreTests/WP11SessionLocationTests.swift` · `ce5e28999`, `1e48434aa` |
| `QuestifyCoreTests/WP11SessionLocationTests/testOwnOPT042aResumeOnlyWhatWasPlayingAndNeverFromBackground` | Added (new file) | `Tests/CoreTests/WP11SessionLocationTests.swift` · `ce5e28999`, `1e48434aa` |
| `QuestifyCoreTests/WP11SessionLocationTests/testOwnOPT042bCountdownUsesServerClockOrAnEmDash` | Added (new file) | `Tests/CoreTests/WP11SessionLocationTests.swift` · `ce5e28999`, `1e48434aa` |
| `QuestifyCoreTests/WP11SessionLocationTests/testOwnOPT072RequestReferenceIsSanitizedScopedAndFresh` | Added (new file) | `Tests/CoreTests/WP11SessionLocationTests.swift` · `ce5e28999`, `1e48434aa` |
| `QuestifyCoreTests/WalletCommerceTests/testEarningsOverviewFixtureKeepsUnknownAsEmDashAndKnownZero` | Added (existing file) | `Tests/CoreTests/WalletCommerceTests.swift` · `1e48434aa`, `e416a3354` |
| `QuestifyCoreTests/WalletCommerceTests/testSyntheticSourceTasksSplitEarnAndSpendRules` | Added (existing file) | `Tests/CoreTests/WalletCommerceTests.swift` · `1e48434aa`, `e416a3354` |
| `QuestifyCoreTests/WalletIncomeDetailPageModelTests/testCapabilityFlagsStayOffAndReuseTheExistingRead` | Added (new file) | `Tests/CoreTests/WalletIncomeDetailPageModelTests.swift` · `d93a0769a` |
| `QuestifyCoreTests/WalletIncomeDetailPageModelTests/testExistingBalanceListFeedsEmptyUnknownZeroAndError` | Added (new file) | `Tests/CoreTests/WalletIncomeDetailPageModelTests.swift` · `d93a0769a` |
| `QuestifyCoreTests/WalletIncomeDetailPageModelTests/testFreshPagerIsUnknownRatherThanAnEmptyZero` | Added (new file) | `Tests/CoreTests/WalletIncomeDetailPageModelTests.swift` · `d93a0769a` |
| `QuestifyCoreTests/WalletIncomeDetailPageModelTests/testLoadingEmptyErrorAndUnknownNeverShowZero` | Added (new file) | `Tests/CoreTests/WalletIncomeDetailPageModelTests.swift` · `d93a0769a` |
| `QuestifyCoreTests/WorkshopPaidInstalledTextTests/testDifferentReceiptCannotBindToCapturedInstallation` | Added (existing file) | `Tests/CoreTests/WorkshopPaidInstalledTextTests.swift` · `fad470999` |
| `QuestifyCoreTests/WorkshopPaidInstalledTextTests/testNullOptionalFieldIsAbsentAndUnknownKeyIsRejected` | Added (existing file) | `Tests/CoreTests/WorkshopPaidInstalledTextTests.swift` · `fad470999` |
| `QuestifyCoreTests/WorkshopPurchasedV2PathTests/testListAndDetailPostTheV2Paths` | Added (new file) | `Tests/CoreTests/WorkshopPurchasedV2PathTests.swift` · `4ce602883` |
| `tools/tests/test_app_unit_target.py::AppUnitTargetTests.test_shared_scheme_matches_target_and_questify_runs_every_class` | Added (existing file) | `tools/tests/test_app_unit_target.py` · `f64760f0a` |
| `tools/tests/test_check_missing_string_keys.py::MissingStringKeyTests.test_missing_key_and_missing_chinese_fail` | Added (new file) | `tools/tests/test_check_missing_string_keys.py` · `f94865c3d` |
| `tools/tests/test_check_missing_string_keys.py::MissingStringKeyTests.test_translated_key_passes` | Added (new file) | `tools/tests/test_check_missing_string_keys.py` · `f94865c3d` |
| `tools/tests/test_design_fixture_release_exclusion.py::DesignFixtureReleaseExclusionTests.test_audit_lists_every_declared_fixture_symbol` | Added (new file) | `tools/tests/test_design_fixture_release_exclusion.py` · `20c7e3639` |
| `tools/tests/test_design_fixture_release_exclusion.py::DesignFixtureReleaseExclusionTests.test_comments_do_not_count_and_string_literals_do` | Added (new file) | `tools/tests/test_design_fixture_release_exclusion.py` · `20c7e3639` |
| `tools/tests/test_design_fixture_release_exclusion.py::DesignFixtureReleaseExclusionTests.test_debug_guard_and_release_else_are_distinct` | Added (new file) | `tools/tests/test_design_fixture_release_exclusion.py` · `20c7e3639` |
| `tools/tests/test_design_fixture_release_exclusion.py::DesignFixtureReleaseExclusionTests.test_identifier_outside_debug_fails` | Added (new file) | `tools/tests/test_design_fixture_release_exclusion.py` · `20c7e3639` |
| `tools/tests/test_design_fixture_release_exclusion.py::DesignFixtureReleaseExclusionTests.test_missing_release_exclusion_is_reported` | Added (new file) | `tools/tests/test_design_fixture_release_exclusion.py` · `20c7e3639` |
| `tools/tests/test_design_fixture_release_exclusion.py::DesignFixtureReleaseExclusionTests.test_repository_keeps_fixture_symbols_out_of_the_release_projection` | Added (new file) | `tools/tests/test_design_fixture_release_exclusion.py` · `20c7e3639` |
| `tools/tests/test_locale_formats.py::CurrencyRuleTests.test_known_zero_stays_zero_for_explicit_currency` | Added (new file) | `tools/tests/test_locale_formats.py` · `48f19094a` |
| `tools/tests/test_locale_formats.py::CurrencyRuleTests.test_locale_does_not_choose_or_convert_currency` | Added (new file) | `tools/tests/test_locale_formats.py` · `48f19094a` |
| `tools/tests/test_locale_formats.py::CurrencyRuleTests.test_unknown_amounts_are_an_em_dash_and_never_zero` | Added (new file) | `tools/tests/test_locale_formats.py` · `48f19094a` |
| `tools/tests/test_locale_formats.py::CurrencyRuleTests.test_usd_formatting_does_not_enable_a_us_backend` | Added (new file) | `tools/tests/test_locale_formats.py` · `48f19094a` |
| `tools/tests/test_locale_formats.py::DateRuleTests.test_civil_clocks_do_not_shift_and_english_drops_seconds` | Added (new file) | `tools/tests/test_locale_formats.py` · `48f19094a` |
| `tools/tests/test_locale_formats.py::DateRuleTests.test_civil_dates_follow_the_locale_and_invalid_days_stay_verbatim` | Added (new file) | `tools/tests/test_locale_formats.py` · `48f19094a` |
| `tools/tests/test_locale_formats.py::DateRuleTests.test_instants_use_the_named_zone_rather_than_the_locale` | Added (new file) | `tools/tests/test_locale_formats.py` · `48f19094a` |
| `tools/tests/test_locale_formats.py::LocaleIdentityTests.test_both_display_locales_share_grouping_and_decimal_marks` | Added (new file) | `tools/tests/test_locale_formats.py` · `48f19094a` |
| `tools/tests/test_locale_formats.py::LocaleIdentityTests.test_supported_tags_collapse_and_unknown_locales_fail_closed` | Added (new file) | `tools/tests/test_locale_formats.py` · `48f19094a` |
| `tools/tests/test_locale_formats.py::PluralRuleTests.test_chinese_does_not_read_the_english_singular_template` | Added (new file) | `tools/tests/test_locale_formats.py` · `48f19094a` |
| `tools/tests/test_locale_formats.py::PluralRuleTests.test_english_one_is_absolute_integer_one_and_chinese_is_always_other` | Added (new file) | `tools/tests/test_locale_formats.py` · `48f19094a` |
| `tools/tests/test_locale_formats.py::ReleaseLockTests.test_shipped_plural_selectors_were_not_rewritten` | Added (new file) | `tools/tests/test_locale_formats.py` · `48f19094a` |
| `tools/tests/test_locale_formats.py::ReleaseLockTests.test_us_production_profile_has_no_invented_host` | Added (new file) | `tools/tests/test_locale_formats.py` · `48f19094a` |
| `tools/tests/test_locale_formats.py::ReleaseLockTests.test_version_and_gates_stay_off` | Added (new file) | `tools/tests/test_locale_formats.py` · `48f19094a` |
| `tools/tests/test_xcode_cloud_plans.py::XcodeCloudPlanTests.test_ci_scripts_do_not_generate_sign_or_store_secrets` | Added (new file) | `tools/tests/test_xcode_cloud_plans.py` · `3dca4729f`, `f64760f0a`, `a7a11b923` |
| `tools/tests/test_xcode_cloud_plans.py::XcodeCloudPlanTests.test_committed_project_matches_generator_and_shards_cover_every_class_once` | Added (new file) | `tools/tests/test_xcode_cloud_plans.py` · `3dca4729f`, `f64760f0a`, `a7a11b923` |
| `tools/tests/test_xcode_cloud_plans.py::XcodeCloudPlanTests.test_generator_pattern_matches_this_contract` | Added (new file) | `tools/tests/test_xcode_cloud_plans.py` · `3dca4729f`, `f64760f0a`, `a7a11b923` |
| `tools/tests/test_xcode_cloud_plans.py::XcodeCloudPlanTests.test_post_clone_writes_simulator_arch_xcconfig_without_applying_it` | Added (new file) | `tools/tests/test_xcode_cloud_plans.py` · `3dca4729f`, `f64760f0a`, `a7a11b923` |
| `tools/tests/test_xcode_cloud_plans.py::XcodeCloudPlanTests.test_prepare_disables_signing_without_touching_the_deployment_target_or_this_checkout` | Added (new file) | `tools/tests/test_xcode_cloud_plans.py` · `3dca4729f`, `f64760f0a`, `a7a11b923` |
