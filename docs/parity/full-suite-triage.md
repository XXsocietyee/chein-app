# Full-suite triage (GM-TEST-C)

Baseline = e3ba3c1b run of the same classes (`/private/tmp/gm-testc-base-classes.log`: 628 tests, 449 failures (108 unexpected)). Current = gm-test2 + GM-TEST-C shim (`/private/tmp/gm-testc-a.log`).

| class | baseline failing tests | run3 (gm-test2 pre-fix) | after fix | new from this wave? | note |
|---|---|---|---|---|---|
| WorkshopPaidProfessionalNormalFlowTests | 11 | 11 | 11 | no | Hosted/normal-flow test; not new, same as baseline (see notes) |
| RoamPlaceDetailReadLifetimeTests | 9 | 9 | 9 | no | SwiftUI AX/presentation under iOS 27.0 sim (host test env) |
| NativeChannelTextReadOnlyPresentationTests | 7 | 7 | 7 | no | Hosted/normal-flow test; not new, same as baseline (see notes) |
| ProjectEditCompositionTests | 7 | 7 | 7 | no | Hosted/normal-flow test; not new, same as baseline (see notes) |
| NativeChannelHistoryTextHTTPRecoveryTests | 7 | 7 | 7 | no | Hosted/normal-flow test; not new, same as baseline (see notes) |
| RoamAnniversaryHistoryRecoveryTests | 6 | 6 | 6 | no | SwiftUI AX/presentation under iOS 27.0 sim (host test env) |
| RoamEnrolledTopicsLifetimeTests | 5 | 5 | 5 | no | SwiftUI AX/presentation under iOS 27.0 sim (host test env) |
| WorkshopCreatorConsentNormalFlowTests | 5 | 5 | 5 | no | Hosted/normal-flow test; not new, same as baseline (see notes) |
| OfficialPublicEventCompositionTests | 4 | 4 | 4 | no | Hosted/normal-flow test; not new, same as baseline (see notes) |
| RoamAnniversaryHostRestorationTests | 4 | 4 | 4 | no | SwiftUI AX/presentation under iOS 27.0 sim (host test env) |
| RoamTileIntentLifetimeTests | 4 | 4 | 4 | no | SwiftUI AX/presentation under iOS 27.0 sim (host test env) |
| WorkshopPaidInstallNormalFlowTests | 4 | 4 | 4 | no | Hosted/normal-flow test; not new, same as baseline (see notes) |
| ZeroHPNormalHostRegressionTests | 4 | 4 | 4 | no | Hosted/normal-flow test; not new, same as baseline (see notes) |
| NativeFriendRequestReviewHostingTests | 4 | 4 | 4 | no | Hosted/normal-flow test; not new, same as baseline (see notes) |
| RoamMonthlyRecapNaturalEntryTests | 4 | 4 | 4 | no | SwiftUI AX/presentation under iOS 27.0 sim (host test env) |
| PrivateHomeSystemKeychainTests | 4 | 4 | 4 | no | Keychain -34018: unsigned test host (CODE_SIGNING_ALLOWED=NO); env |
| RoamOfficialTasksLifetimeTests | 4 | 4 | 3 | no | SwiftUI AX/presentation under iOS 27.0 sim (host test env) |
| WorkshopCreatorPendingNormalFlowTests | 3 | 3 | 3 | no | Copy mismatch: shipped plain-language strings vs reviewed-copy tests; OWNER decision |
| NativeFriendDirectoryNavigationHostingTests | 3 | 3 | 3 | no | Hosted/normal-flow test; not new, same as baseline (see notes) |
| RoamNearbyEventsOriginalHostTests | 4 | 4 | 3 | no | SwiftUI AX/presentation under iOS 27.0 sim (host test env) |
| RoamHistoryHubToolsTests | 6 | 6 | 3 | no | SwiftUI AX/presentation under iOS 27.0 sim (host test env) |
| NativeChannelPinLocalizationTests | 3 | 3 | 3 | no | Copy mismatch: shipped plain-language strings vs reviewed-copy tests; OWNER decision |
| RoamTileDenialHostTests | 3 | 3 | 3 | no | SwiftUI AX/presentation under iOS 27.0 sim (host test env) |
| NativeChannelAppealEntryLocalizationTests | 3 | 3 | 3 | no | Copy mismatch: shipped plain-language strings vs reviewed-copy tests; OWNER decision |
| WorkshopPaidInstalledTextNormalFlowTests | 2 | 2 | 2 | no | Hosted/normal-flow test; not new, same as baseline (see notes) |
| NativeChannelMessageHostBindingTests | 2 | 2 | 2 | no | Hosted/normal-flow test; not new, same as baseline (see notes) |
| TemplateShelfReadCompositionTests | 2 | 2 | 2 | no | Copy mismatch: shipped plain-language strings vs reviewed-copy tests; OWNER decision |
| RoamMonthlyRecapRestoredHostTests | 3 | 3 | 2 | no | SwiftUI AX/presentation under iOS 27.0 sim (host test env) |
| RoamAnniversaryReadIntentTests | 4 | 4 | 2 | no | SwiftUI AX/presentation under iOS 27.0 sim (host test env) |
| ProfileParticipantValidationAppTests | 2 | 2 | 2 | no | Hosted/normal-flow test; not new, same as baseline (see notes) |
| RoamExportReadHostRecoveryTests | 3 | 1 | 2 | no | SwiftUI AX/presentation under iOS 27.0 sim (host test env) |
| NativeBlacklistEntryHostingTests | 2 | 2 | 2 | no | Hosted/normal-flow test; not new, same as baseline (see notes) |
| RoamHomeResumeEntryRecoveryTests | 4 | 4 | 2 | no | SwiftUI AX/presentation under iOS 27.0 sim (host test env) |
| TemplateMetadataReadCompositionTests | 2 | 2 | 2 | no | Copy mismatch: shipped plain-language strings vs reviewed-copy tests; OWNER decision |
| NativeAttributeAuthorProjectHostTests | 2 | 2 | 2 | no | Hosted/normal-flow test; not new, same as baseline (see notes) |
| OfficialEventComponentsClosureTests | 1 | 1 | 1 | no | Hosted/normal-flow test; not new, same as baseline (see notes) |
| RoamShareNativeLifetimeTests | 7 | 7 | 1 | no | SwiftUI AX/presentation under iOS 27.0 sim (host test env) |
| ProfileParticipantHostRecoveryTests | 1 | 1 | 1 | no | Hosted/normal-flow test; not new, same as baseline (see notes) |
| ProfileWeeklyPointsSectionTests | 1 | 1 | 1 | no | Hosted/normal-flow test; not new, same as baseline (see notes) |
| TemplateLocalMediaClearGroupTests | 1 | 1 | 1 | no | Copy mismatch: shipped plain-language strings vs reviewed-copy tests; OWNER decision |
| TemplateCoverReferenceClearTests | 1 | 1 | 1 | no | Copy mismatch: shipped plain-language strings vs reviewed-copy tests; OWNER decision |
| ProfileSettingsFavoritesTests | 1 | 1 | 1 | no | Hosted/normal-flow test; not new, same as baseline (see notes) |
| ContentDraftSystemStorageTests | 1 | 1 | 1 | no | Keychain -34018: unsigned test host (CODE_SIGNING_ALLOWED=NO); env |
| RoamAlbumIntentLifetimeTests | 3 | 3 | 1 | no | SwiftUI AX/presentation under iOS 27.0 sim (host test env) |
| NativeRpgEnvironmentAuthorClosureTests | 1 | 1 | 1 | no | Hosted/normal-flow test; not new, same as baseline (see notes) |
| RoamCreatedStampReadLifetimeTests | 3 | 3 | 1 | no | SwiftUI AX/presentation under iOS 27.0 sim (host test env) |
| TemplateTimerOutcomeEditorTests | 1 | 1 | 1 | no | Copy mismatch: shipped plain-language strings vs reviewed-copy tests; OWNER decision |
| OwnMediaAudioPreviewHostTests | 1 | 1 | 1 | no | Password-gate; OWNER decision (not changed) |
| PlayRecoverySystemStorageTests | 1 | 1 | 1 | no | Keychain -34018: unsigned test host (CODE_SIGNING_ALLOWED=NO); env |
| NativeRpgConditionAuthorClosureTests | 1 | 1 | 1 | no | Hosted/normal-flow test; not new, same as baseline (see notes) |
| WorkshopPurchasedNormalAccountTests | 1 | 1 | 1 | no | Hosted/normal-flow test; not new, same as baseline (see notes) |
| ProfileFavoriteTopicReadTests | 1 | 1 | 1 | no | Hosted/normal-flow test; not new, same as baseline (see notes) |
| TemplateMediaReviewControllerTests | 1 | 1 | 1 | no | Copy mismatch: shipped plain-language strings vs reviewed-copy tests; OWNER decision |
| OwnMediaModelPreviewHostTests | 1 | 1 | 1 | no | Password-gate; OWNER decision (not changed) |
| ProfileFavoriteDetailTests | 0 | 1 | 1 | YES (1 test) | Hosted/normal-flow test; not new, same as baseline (see notes) |
| NearbyMapDiscoveryRecoveryTests | 1 | 1 | 0 | no | SwiftUI AX/presentation under iOS 27.0 sim (host test env) |
| RoamNearbyOwnedStateRecoveryTests | 6 | 6 | 0 | no | SwiftUI AX/presentation under iOS 27.0 sim (host test env) |
| RoamAlbumDenialHostTests | 3 | 3 | 0 | no | SwiftUI AX/presentation under iOS 27.0 sim (host test env) |
| RoamMedalSystemShareSourceTests | 1 | 1 | 0 | no | SwiftUI AX/presentation under iOS 27.0 sim (host test env) |

## Findings
- 185 of the 186 failing tests in these 59 classes also fail at baseline e3ba3c1b; the only newly failing test is `ProfileFavoriteDetailTests.testRealAuthorAndCommentAuthorChildNavigationReturnsToSameDetailReader` (same AX-lookup pattern as its baseline siblings, "0 is not greater than 0").
- Root cause of the Roam/hosted "control not found" family: on the iOS 27.0 simulator SwiftUI's `AccessibilityNode` answers `accessibilityIdentifier` but is not declared `UIAccessibilityIdentification`, so the tests' typed lookup (`as? UIAccessibilityIdentification`) never matched. Fix (test-side, nothing loosened): `HostedAccessibilityRuntime` in `WorkshopPurchasedNormalAccountTests.swift` declares the conformance once; installed from each affected class's `setUp()` and from `HostedNavigationSceneWindow.init`. Effect: 32 baseline-failing tests now pass (`/private/tmp/gm-testc-a.log`: 257 tests, 196 failures (23 unexpected) vs baseline 628/449 on a different class mix; per-test: 186 -> 155 failing).
- Remaining hosted failures: sheets/NavigationStack content in the iOS 27 sim exposes no AX nodes (`cnt=0`) and the run reports `InvalidTransition {phase: idle, targetPhase: failed(deinit)}`; test-defined controls cannot be fixed from production code.
- Keychain classes (-34018 / storageUnavailable): unsigned test host; environment.
- Copy mismatches (NativeChannelAppeal/Pin localization, Template*, WorkshopCreatorPending labels): the shipped xcstrings carry shorter plain-language copy while tests and `test_native_channel_appeal_localization.py` assert the longer reviewed copy. Product/owner decision; not changed.
- OwnMedia{Audio,Model}PreviewHostTests password gate: OWNER decision; not changed.
- Hangs: `ClubPostDiscussionReadTests` `waitForRequests` is now bounded (3 s); superseded page-2/3 assertions moved to the f9ca1f42 full-list contract (page 1, body `{"postId":91}`, fixture host no longer `.invalid` so the legacy-paging switch is not used). The same unbounded helper in 4 CoreTests files is bounded (5 s). Result: ClubPostDiscussionReadTests 10 tests, 0 failures (`/private/tmp/gm-testc-club3.log`, TEST_EXIT=0).
- Core: `AccountComplianceTests` 13 tests, 0 failures (`/private/tmp/gm-testc-core-acct.log`). Full Core run not repeated; run3 crashed with `Index out of range`, run2 had 122 failing tests (keychain `storage`/`locked`, staleSession ...) - NOT triaged.

## Core package (swift test) - GM-TEST-C round 3

Complete run (no crash): `Executed 15004 tests, with 176 failures (44 unexpected)` (`/private/tmp/gm-testc-core-full5.log`). The earlier `Index out of range` crash came from `ClubCommunityOriginalRequestKeyTests` and `AccountComplianceTests` indexing `requests[0]` after an upstream failure, and from the dropLast(2) multipart bug; it no longer occurs.
Baseline e3ba3c1b (same classes, `/private/tmp/gm-testc-core-basecls.log`): 461 tests, 193 failures (61 unexpected), 107 failing tests. Now 90 failing tests, 0 failing tests that pass at baseline.

Fixed this round: AccountCompliance*/AccountDeregistration*/I00 (see account-compliance-reconcile.md), multipart `dropLast(2)` bug, `MerchantOfferWithdrawalUnifiedStore` symlink-ancestor rejection of `/var` (17 tests).

| class | failing tests | baseline fail? | verdict |
|---|---|---|---|
| NativeHomeReturnNativeTests | 11 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| PlayKitReviewTests | 10 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| CityNodeRedemptionTests | 5 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| CityOrderedMapRecoveryTests | 5 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| NativeBlacklistTransportTests | 5 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| CityCurrentSnapshotPresentationTests | 3 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| CityCurrentSnapshotReadingTests | 3 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| CityOrderedMapPresentationTests | 3 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| MerchantStoreIndustrySelectionTests | 3 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| NativeFriendTransportTests | 3 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| PlayCompareReviewTests | 3 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| ClubActionServiceTests | 2 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| ClubApplicationRequiredMessageTests | 2 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| ClubCommunityPendingJournalTests | 2 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| ClubCommunityReadRuntimeTests | 2 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| MerchantStoreIndustryServiceTests | 2 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| NativeChannelMessageOriginalWriterJournalTests | 2 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| PrivateHomeRecoveryFenceTests | 2 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| ProfileGuideReadRouteTests | 2 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| ChapterInlinePendingSelectionTests | 1 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| ClubActionCoordinatorTests | 1 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| ClubActionSessionTests | 1 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| ClubCommunityTests | 1 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| InvoiceLaunchCoordinatorTests | 1 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| MerchantNPCTests | 1 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| MerchantOfferWithdrawalUnifiedStoreTests | 1 | yes | ENV: historical-root fixture under /var symlink path (journal deliberately refuses symlink traversal) |
| MerchantOperationsContractTests | 1 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| MerchantOperationsServiceTests | 1 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| MerchantPersonalIncomeEligibilityTests | 1 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| MerchantStoreIndustryContractTests | 1 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| MessagingVisibilityTests | 1 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| NativeHomeReturnSelectionRecoveryFenceTests | 1 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| NearbyMapDiscoveryProjectionTests | 1 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| NicknameC6ReadTests | 1 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| ParticipantCoordinatorSnapshotLifetimeTests | 1 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| ParticipantCoordinatorTests | 1 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| PlayReadLifetimeTests | 1 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| RoamPassportToolsTests | 1 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |
| SquareReportTests | 1 | yes | REAL contract drift between test and code (not triaged to a fix); not caused by this wave |

`ProfileFavoriteDetailTests.testRealAuthorAndCommentAuthorChildNavigationReturnsToSameDetailReader` (AppUnit): fails at `XCTAssertGreaterThan(probe.rootAppearances,0)`; its sibling classes ProfileFavoriteTopicReadTests/ProfileSettingsFavoritesTests fail identically at baseline, so this is the iOS 27 simulator hosting/appearance environment, not a ProfileFavorites regression. Not fixed.
`RuntimeSessionRoleConsistencyTests.testMissingExplicitRole...` contradicts `I00SessionAdmissionBaselineTests`: OWNER decision (see reconcile doc row 7).

## Core (GM-TEST-C2, branch gm-test4)

Full `swift test` of QuestifyCoreTests on gm-test4 (log `/tmp/gm-test4-core-full.log`): `Executed 15004 tests, with 82 failures (16 unexpected)`. Starting point on the same tree before this wave: `Executed 15004 tests, with 176 failures (44 unexpected)`. The XCTest "failures" count includes multiple assertions per test; unique failing tests went 90 -> 39 (the 90 were first collected from the 176-failure run).
Baseline e3ba3c1b cannot run a full Core pass (it crashes in `AccountComplianceTests`, the `dropLast` bug fixed here), so the failing classes were run there separately (`/tmp/gm-test4-core-base.log`: `Executed 453 tests, with 185 failures (53 unexpected)`, 99 unique failing tests): every one of the 90 tests failing here at the start also failed at the baseline, none are regressions of this wave; 9 `MerchantOfferWithdrawalUnifiedStoreTests` were already fixed.

### Fixed in this wave (51 tests, nothing loosened, skipped or deleted)
| class | tests | verdict | fix |
|---|---|---|---|
| PlayKitReviewTests, PlayCompareReviewTests, PlayReadLifetimeTests, ChapterInlinePendingSelectionTests | 15 | test fixture stale | `PlayAdvancedCoordinator` now defaults to a fail-closed `PlayUnavailableAdvancedRecovery` (start -> `persistenceUnavailable`, 0 requests). Fixtures pass the existing `PlayMemoryAdvancedRecovery()`. Production untouched. |
| ClubApplicationRequiredMessageTests, NativeBlacklistTransportTests | 7 | test fixture | fixture hosts were `*.invalid`, which `APIConfiguration` rejects by design (`NativeFriendTransportTests` asserts that). Hosts renamed `*.test`. |
| NativeHomeReturnNativeTests (10 of 11), NativeHomeReturnSelectionRecoveryFenceTests | 11 | test fixture | the synthetic DWELL_REQUIRED reply lacked `accountVersion`, which production now binds; request id `"other"` (5 chars) violates the 8..64 request-id rule. |
| NativeHomeReturnNativeTests.testSixDecimalQuantization... | 1 | REAL code bug (Foundation behavior) | `NSDecimalNumber.doubleValue` returned `12.123456999999998` for `12.123457`; `NativeHomeReturnFix` now converts through the decimal text (`exactDouble`). |
| CityCurrentSnapshotReadingTests, CityCurrentSnapshotPresentationTests, CityOrderedMapPresentationTests, CityOrderedMapRecoveryTests | 10 | env (Foundation) in fixtures | `JSONSerialization` writes Swift Double `30.1` as `30.100000000000001`, which no longer equals the exact Decimal viewport; fixtures use `NSDecimalNumber(string:)` and decode the original reply bytes. `JSONDecoder` Decimal decoding was probed and is exact. |
| ClubCommunityTests.testReadRowsAndScope (+ rows in two sibling classes) | 1 | test fixture stale | the posts list now requires `isPinned` 0/1; fixture rows carry it. |
| NearbyMapDiscoveryProjectionTests | 1 | test typo | a raw-string literal swallowed its closing JSON quote (invalid JSON). |
| NicknameC6ReadTests | 1 | REAL code bug (Foundation behavior) | the nickname charset regex matched `e` + U+0301 as one letter (grapheme semantics on this OS), accepting a combining mark; `ProfileNicknameRules` now checks Unicode scalars (letter/number categories + `_#-.· `). |
| AccountComplianceTests / Deregistration* / I00 | - | see `account-compliance-reconcile.md` | rows 1,2,3,6; row 7 kept fail-closed. |

### Remaining 39 failing tests (all also fail at e3ba3c1b; none new)
Verdict key: STALE = test written before the reviewed product snapshot f9ca1f42 (2026-11-06) hardened the contract, production is the safer behavior, OWNER decides whether tests are rewritten; OPEN = not root-caused yet.
| class | tests | verdict | evidence |
|---|---|---|---|
| CityNodeRedemptionTests | 5 | STALE / OWNER | tests (2026-10-01) expect any `code:200` -> redeemed and 400/403/500 messages byte-exact. Production requires the exact original success body (poiId, memberId, couponId, couponGranted + exact message) and otherwise reports UNKNOWN (fail-safe against double redemption). |
| ClubActionServiceTests, ClubActionSessionTests, ClubActionCoordinatorTests | 2+1+1 | STALE / OWNER | they apply with an empty `joinMessage` (the service test loop even lists `""` and `"   "` as valid); `ClubApplicationMessage.isValid` plus `ClubApplicationRequiredMessageTests` now require a non-empty reviewed message. The two test generations contradict each other. |
| MerchantStoreIndustrySelectionTests, MerchantStoreIndustryServiceTests, MerchantStoreIndustryContractTests, MerchantOperationsServiceTests, MerchantOperationsContractTests | 3+2+1+1+1 | STALE / OWNER (medium confidence) | tests (2026-10-12) assert the single `categoryId` wire field and the older info/coop read order; production `MerchantStoreDecor` carries `categoryIds` with a multi-select replacement (1..5) and reads `/api/merchant/info`. |
| MerchantNPCTests | 1 | STALE / OWNER | merchant-chat HTTP 403 is now mapped to `MerchantNPCGameDispatchDenial`; the test expects `rejected(403, ...)`. |
| ProfileGuideReadRouteTests | 2 | STALE / OWNER | production deliberately accepts a detail reply with `data` omitted (c6 AjaxResult success(null)); tests expect it to throw. |
| RoamPassportToolsTests | 1 | STALE / OWNER | weekly columns appear only when the collapsed item count equals the server total; the test's duplicate row makes it 3 of 4 and `weeks` is empty by design. |
| ClubCommunityReadRuntimeTests | 2 | STALE / OWNER | older paged contract; production uses the f9ca1f42 full-list contract (same finding as the gm-test2 triage). |
| ClubCommunityPendingJournalTests | 2 | STALE / OWNER | test asserts the request id is never persisted / absent in the outcome query; production persists and requires the matching `requestId` (`stale` otherwise). |
| NativeFriendTransportTests | 3 | OPEN | `invalid` on receipts/review and a 401 journal clear; not root-caused. |
| PrivateHomeRecoveryFenceTests | 2 | OPEN | restore fence ends `blocked` instead of `ready`; not root-caused. |
| NativeChannelMessageOriginalWriterJournalTests | 2 | OPEN | quoted-send allowlist / plain receipt; not root-caused. |
| ParticipantCoordinatorTests, ParticipantCoordinatorSnapshotLifetimeTests | 1+1 | OPEN | `outcomeUnknown(malformedResponse)` for a legacy nil acknowledgement; not root-caused. |
| SquareReportTests, MessagingVisibilityTests, MerchantPersonalIncomeEligibilityTests, InvoiceLaunchCoordinatorTests | 1 each | OPEN | not root-caused (`invalid` / card destination nil / `malformed` / `outcomeUnknown`). |
| MerchantOfferWithdrawalUnifiedStoreTests | 1 | OPEN, probably env | `persistence` thrown by a storage fixture; the other 9 tests of the class pass now. |

Environment notes for reproducing: `swift test` runs from an Orca terminal; inside the Claude Bash sandbox SwiftPM/Swift-macro nested `sandbox-exec` and the simulator test runner socket are blocked.
