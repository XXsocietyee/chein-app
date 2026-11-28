# K17 AppUnit acceptance — cursor/1128-acceptance

Lane2 simulator `Questify-iPhone17-Lane2` `2337B386-AC5F-4417-B8B8-012A8DB888BD`.
DerivedData `~/Library/Developer/Xcode/DerivedData/cursor-1128-acceptance`.
Base `origin/ui/combined-r7` `c4e43841afaddd576a72104f8bf8641af2060732` (K11–K16 and the sensors/artworkHosts argument-order fix). Merged by fast-forward. Not rebased.

Gates on this tree: `check_scaffold.py` PASS (5403 Swift files, AppSession.swift 7977 lines), `check_a11y_lint.py` 0 new, `contract_ratchet.py --check` 46 failing / baseline 46 / new 0. No new `String(localized:)` literals.

## Lane2

| shard | tests | failures | failing methods |
|---|---:|---:|---:|
| QuestifyAppUnitTests-Shard01 (rerun after the stale edits) | 1890 | 20 | 8 |
| QuestifyAppUnitTests-Shard02 | 2002 | 39 | 19 |
| QuestifyAppUnitTests-Shard03 | 2110 | 35 | 18 |
| QuestifyAppUnitTests-Shard04 | 2088 | 48 | 23 |

56 unique failing methods. The reviewed merchant and nearby-team wiring tests are in every shard, so the raw failure counts overlap. Shard01 before the accent and poi-detail edits was 1890 tests / 25 failures; the rerun is the number above.

## Tests fixed

Stale tests only. The product behavior was already right.

- `Tests/AppUnitTests/ClubTopicDirectorLoadStateTests.swift` — `@testable import Questify`, so `ClubTopicDirectorEmbeddedMount` is in scope. Suite passed on shard02.
- `Tests/AppUnitTests/DesignR1FoundationTests.swift` — selected tab, primary pill, and merchant pill compare to `CYDomainPalette.systemAccent` (`Color(uiColor: .systemBlue)`). `Color.accentColor` is a different provider. Passed on the shard01 rerun.
- `Tests/AppUnitTests/DesignSystemTokenMappingTests.swift` — same accent comparison for `actionPrimaryBg`, `tabSelectedTint`, and selected chips. Suite passed on shard04.
- `Tests/AppUnitTests/MPParityDeepLinkRouteTests.swift` — `subpackageRoam/poi-detail/index` sample carries `poiId=5`. An empty query is not a link (`Core/MiniProgramPageLink.swift`). Passed on the shard01 rerun.
- `Tests/AppUnitTests/Fix1128bPlayReleaseCompositionTests.swift` — helper renamed to `Fix1128bPlayReleaseRecorder` so it is not a second `Fix1128bRecorder`. Predicates unchanged. One assertion still fails (below).
- `Tests/AppUnitTests/ReleasePlayerServiceAuditTests.swift` — `Row` accepts a one-argument closure, and the throwing merchant-center source read is called with `try`. Predicates unchanged. Two census rows still fail (below).
- `Tests/AppUnitTests/PlayReadCompositionTests.swift` — a lead spectator with `registered: false` stays `.active`. `PlayProgression.availability` (`Core/PlayProgression.swift:37`) skips the registration gate only when `leadSpectator != true`. The empty-gate and missing-pass assertions are unchanged. Shard02 recorded the old `.registrationRequired` expectation; this line was updated after that shard.

## Owner list

Money, security, and deletion tests were not edited.

- `ReviewedMerchantMarketingWiringTests.testReviewedChinaCompositionAllowsExactlyTheTwoRoutesForMerchantsOnly` — `Tests/AppUnitTests/ReviewedHookWiring2Tests.swift:159` must refuse settle, `:160` count 3 not 2. The composition admits `api/merchant/predict/settle`.
- `ReviewedNearbyTeamWriteWiringTests.testReviewedChinaCompositionAllowsExactlyTheWritesAndRefusesNeighbours` — `Tests/AppUnitTests/ReviewedHookWiring2Tests.swift:466` must refuse quit and disband, `:467` count 6 not 4. Bodies `{"teamId":5}` match `ReviewedTeamMembershipWriteRoute`.
- `PlayGapOwnerGrantTests.testCreatorTailRoutesAreGrantedInBothListsAndMoneyStaysOff` — `Tests/AppUnitTests/PlayGapOwnerGrantTests.swift:46`. `playPaths` contains `api/club/lead/release-station` and `api/club/lead/unlock-chapter-receipt`.
- `MerchantCustomerDetailSectionsTests.testBothPermissionsExposeOnlyExactNonNullAmount` — `Tests/AppUnitTests/MerchantCustomerDetailSectionsTests.swift:32` `¥42.00` vs `CNY 42.00`, `:33` the amount label, `:40` `¥0.00` vs `CNY 0.00`, `:41` the zero amount label.
- `BeGapMerchantSwitchTests.testOwnerGrantAdmitsMerchantReadsAndStillRefusesMoney` — `Tests/AppUnitTests/BeGapMerchantSwitchTests.swift:45`. Mark is `liveInProduction`, expected `missing`.
- `MPFirstCMAGrantTests.testC_F17ProductionGrantsTheOriginalRoutesTheMPSends` — `Tests/AppUnitTests/MPFirstCMAGrantTests.swift:87`. The production project-write grant contains the edit-request submit path.
- `AppCompositionRootTests.testMerchantEntryIntentDoesNotGrantMerchantRoleOrWriteAccess` — `Tests/AppUnitTests/AppCompositionRootTests.swift:208`. Status is `approved`, expected `disabled`.
- `SocialMemberActionLifecycleAppTests.testAuthenticatedAccountAndRoleReplacementCannotRetainPriorGrantsOrReviews` — `Tests/AppUnitTests/SocialMemberActionAppTests.swift:117` and `:123`. Status is `approved`, expected `disabled`.
- `SocialMemberActionLifecycleAppTests.testRestorationKeepsOldUnknownOwnerKeyAndDifferentRealmCannotUseApprovalOrLock` — `Tests/AppUnitTests/SocialMemberActionAppTests.swift:150`. Status is `approved`, expected `disabled`.
- `ReviewedChinaLaunchCompositionTests.testAbsentCapabilityStaysHiddenAndWritesStayOff` — `Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift:210` play capability set does not match, `:214` presence is `true`, expected `false`.
- `MPFirstClubWriteRouteR10Tests.testAdmitsTopicDirectorReadsOnTheirExactBody` — `Tests/AppUnitTests/MPFirstClubWriteRouteR10Tests.swift:102`. `api/club/crm/topic-customers` with `{"clubId":3,"topicId":7}` is admitted.

## Product failures

Not edited. A failing assertion here is the product, not a stale expectation.

Merchant operations (`Tests/AppUnitTests/ReviewedHookWiring2Tests.swift`):

- `:558` `testLeaseCoversExactlyTheFourSavesForMerchantsInChina`. The lease also contains `api/merchant/business-status/update` (`App/AppCompositionRoot.swift` `ReviewedMerchantOperationsRoute`).
- `:570` `testReviewedChinaCompositionAllowsExactlyTheReadsAndSavesForMerchantsOnly` admits decor-empty, decor-array, decor-extra-key, npc-partial, npc-number, and form-body-save.
- `:571` admitted count is 16, expected 10.

Other:

- `Tests/AppUnitTests/Fix1128bPlayReleaseCompositionTests.swift:122` — `ReviewedProductionFormMutationRoute.acceptsPlayerWrite` accepts GET `api/play/tag/81/revoke`.
- `Tests/AppUnitTests/MerchantProjectBrowseCompositionTests.swift:499` — overview record body is 0 bytes and `application/x-www-form-urlencoded`, expected 2 bytes of JSON.
- `Tests/AppUnitTests/MerchantWorkbenchRemindersTests.swift:572` — account lands on `consumerTabs`, expected `merchantTabs`.
- `Tests/AppUnitTests/ProfileFavoriteTopicReadTests.swift:147` and `:152` — chapter cover return does not reuse the same reader.
- `Tests/AppUnitTests/ProfileFavoriteDetailTests.swift:184` and `:188` — author child navigation does not return to the same detail reader.
- `Tests/AppUnitTests/ReleasePlayerServiceAuditTests.swift:84` — City board is on, catalog kind is off.
- `Tests/AppUnitTests/ReleasePlayerServiceAuditTests.swift:146` — `/api/map/public-layers` is not admitted.
- `Tests/AppUnitTests/NativeAttributeAuthorProjectHostTests.swift:320` — caught `staleSource`.
- `Tests/AppUnitTests/PlayBranchHistoryFixtureHandshakeTests.swift:240` — consumed-action count 8, expected 7.
- `Tests/AppUnitTests/PremergeScreensViewModelTests.swift:131` — roam presence disable is `.failed`, expected `.disabled`.
- `Tests/AppUnitTests/PremergeScreensViewModelTests.swift:138` — club picker is `.failed("俱乐部信息加载失败")`, expected `.openClub`.
- `Tests/AppUnitTests/RuntimeSessionRoleConsistencyTests.swift:45` — missing explicit role unwraps no `Account`.

Hosted SwiftUI lifetime. These fail with `InvalidTransition` idle → `failed(deinit)` and/or the original control never appears. Left as product failures.

- `Tests/AppUnitTests/RoamHistoryHubToolsTests.swift:115` and `:127` — `testEmptyHistoryStillOffersOriginalMonthlyRecapAndReturns`, `testHubHistoryForwardsOriginalToolsThroughReadFailureRetryAndBack`.
- `Tests/AppUnitTests/RoamHistoryHubToolsTests.swift:174` — `testPrivateExportUsesOriginalUnconfiguredReaderWithoutGrantOrAutomaticPrepare`.
- `Tests/AppUnitTests/RoamNearbyOwnedStateRecoveryTests.swift:107` and `Tests/AppUnitTests/WorkshopPurchasedNormalAccountTests.swift:89` — `testActualOwnedRetryRestoresJoinedRowsWithoutRefetchingIndependentApplications`.
- `Tests/AppUnitTests/NativeFriendRequestReviewHostingTests.swift:112`, `:138`, `:163`, `:206`, with `WorkshopPurchasedNormalAccountTests.swift:89` — review sheet never appears.
- `Tests/AppUnitTests/RoamAnniversaryReadIntentTests.swift:179` — `testActualFirstReadCoveredBeforeCompletionStillRestartsOnReturn`.
- `Tests/AppUnitTests/RoamHomeResumeEntryRecoveryTests.swift:162` and `:165` — resume control does not settle (continue and pending-check).
- `Tests/AppUnitTests/RoamAlbumIntentLifetimeTests.swift:171` — `testActualBackgroundDoesNotReopenOriginalExpiredMetadataScope`.
- `Tests/AppUnitTests/RoamAnniversaryHistoryRecoveryTests.swift:129` and `:146` — `testTwoPageReturnFailureKeepsOldRowsThenRetriesSameDayAndLoadedDepthAtomically`.
- `Tests/AppUnitTests/RoamReceivedStampMetadataHostTests.swift:179` and `:183` — nil host and album entry.
- `Tests/AppUnitTests/NativeFriendDirectoryNavigationHostingTests.swift:131`, `:188`, `:241` — metadata, grant withdrawal, and public profile.
- `Tests/AppUnitTests/RoamAnniversaryHostRestorationTests.swift:95` and `:120` — menu hub, passport retry, and uninjected route-unavailable control.
- `Tests/AppUnitTests/RoamEnrolledTopicsLifetimeTests.swift:139` and `:146` — detail push, sign-out, and failed-read retry.
- `Tests/AppUnitTests/RoamMonthlyRecapRestoredHostTests.swift:228`, `:249`, and `:274` — revocation and kind picker.
- `Tests/AppUnitTests/RoamNearbyEventsRestoredDetailTests.swift:190` and `:200` — HTTP retry and read-only topic control.
- `Tests/AppUnitTests/RoamOfficialTasksLifetimeTests.swift:157` and `:167` — detail push and error retry.
- `Tests/AppUnitTests/RoamTileIntentLifetimeTests.swift:190` — `testActualDepartureAndReopenRetireHeldReadWithoutAutomaticRecovery`.
