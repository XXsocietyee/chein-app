# CB92 AppUnit triage

Base `origin/rc/20261108` `576e869a995c280f325799ad8ea9a2729ac30781`. Branch `cursor/cb92`.

This VM has no Xcode and no Swift. AppUnit was not run. Nothing in this note is a new test result.

No test was deleted, renamed, weakened, or skipped. `Tests/AppUnitTests/LaunchShellHiddenEntryTests.swift` was not restored. `.github/workflows/ios-ci.yml` was not edited. `tools/current_ci_manifest.json` was not refreshed.

## Recorded result

The last known AppUnit result given to this lane is **7566 tests, 545 failures, 125 unexpected**.

The only runner line that matches 7566 tests and 125 unexpected is the full `QuestifyAppUnitTests` run recorded on `origin/cursor/A2` `15067547d` (`docs/release/launch-rc-report.md` on that commit, cited by `docs/release/cb3-appunit-groups.md` and `docs/release/cb40-test-speed.md`):

```text
Executed 7566 tests, with 548 failures (125 unexpected) in 770.824 (772.469) seconds
```

`cb3` calls 548 Xcode's assertion-record total and 545 the task failure figure. `cb40` keeps both as published records. This note does the same. The 3-record gap is not tied to three method names in `docs/release` or the parity tables, so those three records are not named here.

That same A2 report says the `Failing tests:` list is 464 lines, **222 unique methods, 65 unique classes**. `WalletEarningsSegmentHitAreaTests` is not in that list. The 545 and 548 figures are failure records (a method can record more than one). The named failing set is the 222 methods.

On this runner, an unexpected failure is an error that leaves the test method. `docs/release/cb2-core-unexpected.md` states that rule, and `docs/parity/gap-wave-compare.md` applies it to the classes below. 125 unexpected is the runner total. This note names 12 of those methods. The other 113 unexpected names are not in the published per-method tables.

`15067547d` is not an ancestor of this base. `Tests/AppUnitTests`, `App/AppCompositionRoot.swift`, and `.github/workflows/ios-ci.yml` are unchanged between the previous rc tip `2f6d5041a` and `576e869a9`. The class index below is the tree at `576e869a9`.

## How a failure is named

A method selector is named only when one of these is true:

- The A2 class count equals the number of `func test…` declarations on that type in `Tests/AppUnitTests`, so every declaration failed.
- A published per-method row names that selector and the row's fail count matches the A2 count for the class (`docs/parity/gap-wave-compare.md`, `docs/parity/full-suite-triage.md`, `docs/parity/account-compliance-reconcile.md`).

A class with a recorded count and no selector list is placed on a shard, and its methods stay unnamed. Selectors are not guessed from the extra declarations.

## Shard rule

851 `XCTestCase` types are declared in `Tests/AppUnitTests` (the declaration line contains `XCTestCase`). Sorted by type name, shard is `index % 4`, the same four-way split `.github/workflows/ios-ci.yml` describes for `QuestifyAppUnitTests`.

The workflow text does not build that list, and this note does not change the workflow:

- A line must start with `class `, `final class `, `public class `, or `internal class `. `@MainActor final class` is skipped. 64 of the 65 failing types are declared that way.
- `name = text.split()[1]` on a `final class Foo` line is the token `class`, not `Foo`. The one failing type the parser does read, `ClubCommunityReadCompositionTests`, is stored as `class`.

A literal run of that parser therefore emits two tokens, `ReviewedHookWiring2Base` (shard 0) and `class` (shard 1). `-only-testing:QuestifyAppUnitTests/class` does not select `ClubCommunityReadCompositionTests`. Literal shard membership of the 65 real failing type names is 0 / 0 / 0 / 0.

The counts below use the type identifier, then `index % 4`. Shard sizes on this tree are 213, 213, 213, 212.

### Recorded failing methods, by class index

Every one of the 222 methods sits on the shard of its class. Selectors that are not individually published are included in these counts and excluded from the selector table.

| shard | classes | recorded failing methods |
|---:|---:|---:|
| 0 | 13 | 32 |
| 1 | 23 | 76 |
| 2 | 14 | 48 |
| 3 | 15 | 66 |
| total | 65 | 222 |

### Selectors this note can name

| shard | named selectors |
|---:|---:|
| 0 | 4 |
| 1 | 27 |
| 2 | 24 |
| 3 | 33 |
| total | 88 |

The other 134 methods are known only as a count inside a named class.

## Hosted accessibility, listed separately

iOS 27 simulator hosts expose no SwiftUI accessibility nodes. That is the baseline. These 39 classes, 142 methods, are that baseline. They are already inside the 222. They are not a product defect, and no test file in the set was edited.

The source of each class contains `UIHostingController`, `UIWindow`, `HostedNavigationSceneWindow`, or an accessibility lookup (`accessibilityIdentifier` / `UIAccessibility`). `docs/parity/full-suite-triage.md` records the same host failure: `AccessibilityNode` answers `accessibilityIdentifier` but is not `UIAccessibilityIdentification`, sheets and `NavigationStack` content report `cnt=0`, and the run reports `InvalidTransition`. `ProfileFavoriteDetailTests.testRealAuthorAndCommentAuthorChildNavigationReturnsToSameDetailReader` fails at `XCTAssertGreaterThan(probe.rootAppearances, 0)`, the same hosting environment as its siblings.

`WalletEarningsSegmentHitAreaTests` is the same host failure on older logs (`docs/release/cb2-core-unexpected.md`, `docs/release/cursor-L1-report.md` on `origin/cursor/L1`). It is not in the A2 failing list, so it is not one of the 142.

| shard | classes | recorded methods |
|---:|---:|---:|
| 0 | 7 | 24 |
| 1 | 13 | 47 |
| 2 | 11 | 43 |
| 3 | 8 | 28 |
| total | 39 | 142 |

| methods | shard | class |
|---:|---:|---|
| 5 | 0 | WorkshopCreatorConsentNormalFlowTests |
| 4 | 0 | WorkshopPaidInstallNormalFlowTests |
| 3 | 0 | RoamCreatedStampReadLifetimeTests |
| 3 | 0 | RoamTileDenialHostTests |
| 1 | 0 | NativeRpgEnvironmentAuthorClosureTests |
| 7 | 0 | RoamShareNativeLifetimeTests |
| 1 | 0 | WorkshopPurchasedNormalAccountTests |
| 7 | 1 | NativeChannelHistoryTextHTTPRecoveryTests |
| 7 | 1 | NativeChannelTextReadOnlyPresentationTests |
| 6 | 1 | RoamAnniversaryHistoryRecoveryTests |
| 5 | 1 | RoamEnrolledTopicsLifetimeTests |
| 4 | 1 | OfficialPublicEventCompositionTests |
| 4 | 1 | RoamMonthlyRecapNaturalEntryTests |
| 4 | 1 | RoamTileIntentLifetimeTests |
| 3 | 1 | NativeFriendDirectoryNavigationHostingTests |
| 3 | 1 | RoamAlbumDenialHostTests |
| 1 | 1 | NearbyMapDiscoveryRecoveryTests |
| 1 | 1 | ProfileSettingsFavoritesTests |
| 1 | 1 | ProfileWeeklyPointsSectionTests |
| 1 | 1 | RoamMedalSystemShareSourceTests |
| 9 | 2 | RoamPlaceDetailReadLifetimeTests |
| 6 | 2 | RoamHistoryHubToolsTests |
| 6 | 2 | RoamNearbyOwnedStateRecoveryTests |
| 4 | 2 | RoamAnniversaryHostRestorationTests |
| 4 | 2 | RoamHomeResumeEntryRecoveryTests |
| 4 | 2 | RoamOfficialTasksLifetimeTests |
| 3 | 2 | RoamAlbumIntentLifetimeTests |
| 3 | 2 | RoamMonthlyRecapRestoredHostTests |
| 2 | 2 | WorkshopPaidInstalledTextNormalFlowTests |
| 1 | 2 | NativeRpgConditionAuthorClosureTests |
| 1 | 2 | ProfileFavoriteTopicReadTests |
| 11 | 3 | WorkshopPaidProfessionalNormalFlowTests |
| 4 | 3 | NativeFriendRequestReviewHostingTests |
| 4 | 3 | RoamAnniversaryReadIntentTests |
| 4 | 3 | RoamNearbyEventsOriginalHostTests |
| 2 | 3 | NativeBlacklistEntryHostingTests |
| 1 | 3 | OfficialEventComponentsClosureTests |
| 1 | 3 | ProfileFavoriteDetailTests |
| 1 | 3 | RoamExportReadHostRecoveryTests |

Named selectors inside this baseline (50 of 142; the rest of the class is only a count):

- Shard 0 (3): `RoamTileDenialHostTests` — `testHTTPAndBusiness403RemovePrivateCountAndContinuationWithoutEmptySuccess`, `test503With403BodyRetainsCountAndOriginalRetryUsesSameCursor`, `testClosingAndReopeningDeniedDestinationRequiresExplicitReadFromZero`.
- Shard 1 (20): all 7 `NativeChannelHistoryTextHTTPRecoveryTests`, all 3 `RoamAlbumDenialHostTests`, all 6 `RoamAnniversaryHistoryRecoveryTests`, all 4 `RoamMonthlyRecapNaturalEntryTests`.
- Shard 2 (22): all 4 `RoamAnniversaryHostRestorationTests`, all 6 `RoamHistoryHubToolsTests`, all 3 `RoamMonthlyRecapRestoredHostTests`, all 9 `RoamPlaceDetailReadLifetimeTests`.
- Shard 3 (5): all 4 `RoamNearbyEventsOriginalHostTests`, plus `ProfileFavoriteDetailTests.testRealAuthorAndCommentAuthorChildNavigationReturnsToSameDetailReader`.

## Proven product defect, already on this base

`CompositionHTTPTransport` on A2 built `PlayExperienceSession` without the captured role in `sendConfirmed` and on the coupon read routes (`api/coupon/command-receipt`, `api/merchant/coop-profile`, `CouponManagementReadRoute`). The session initializer defaults the role to `player`. `RuntimeDependencyContext` equality includes `session.role`, so a merchant or club viewer did not match the context the coordinator had captured. Coupon `preparePublish` then returned with `review == nil`. `approvedReleaseConfiguration` returned nil unless the argument equaled `currentRuntimeDependencyContext`, and `ApprovedTopicReviewClient.send` threw `notConfigured` before the wire.

That is the 15 `CouponRuntimeCompositionTests` methods (22 assertion records, 0 unexpected in `gap-wave-compare.md`) and `ApprovedTopicReviewCompositionTests.testNormalSourceChoiceFactoryCarriesExactRefsThenReadsOnlySixFields` (1 unexpected, `caught error: "notConfigured"`).

`f273c806c` (`fix(ios): pass the signed-in role through composition transport sessions`) is already in `576e869a9`. On this tree those constructors pass `role: role`. A player account still gets the old default. The tests were not edited. No Swift run since A2 has measured the fix. This branch does not patch that path again.

Named selectors, shard 3, coupon (15):

- `testActualCouponFixtureNormalSessionReachesMarketingHomeInEveryMode`
- `testActualFixtureCouponRevocationPreservesRecruitingButStillDeniesCouponWrite`
- `testFreshExplicitPermissionAndMerchantScopeAtReviewAndConfirm`
- `testLateWriteSuccessAndFailureRemainUnknownAfterRoleABAOrLeaseRevocation`
- `testMalformedSuccessUnknownAndAcknowledgedReadbackFailureNeverRetry`
- `testMissingReadOrWriteLeaseAndArbitraryDormantTransportCannotWrite`
- `testNormalSessionCreateAndStopReadbackWithoutAISubscription`
- `testPerActionLeasesDenyOtherActionWithoutCreatingPendingRecord`
- `testPostcommitCode500RetainsOriginalPublicationLockAcrossRestart`
- `testRevocationAfterJournalAcquirePreventsDispatchAndRetainsRecord`
- `testRevokedWriteLeaseLeavesIndependentReadCapabilityUsable`
- `testStopRequiresFreshPermissionAndUnchangedOwnedStatus`
- `testUnknownPersistsAcrossDiskReopenLogoutAndDuplicateCoordinators`
- `testV1NormalCompositionPersistsThenReadOnlyRecoveryAfterRestart`
- `testV1OwnerReadIsNotGrantedByLegacyLeaseOrCouponPermissionAlone`

Shard 0 (1): `ApprovedTopicReviewCompositionTests.testNormalSourceChoiceFactoryCarriesExactRefsThenReadsOnlySixFields`.

## Not a product defect

Left unchanged. Counts are the A2 failing-method counts. Selectors are listed only where the rule above names them.

| methods | shard | class | why it was not changed |
|---:|---:|---|---|
| 11 | 3 | MerchantReviewOriginalRecoveryEntryTests | All 11 methods. Harness is `https://example.invalid` (`Tests/AppUnitTests/MerchantReviewOriginalRecoveryEntryTests.swift`). `APIConfiguration` rejects a host ending in `.invalid` (`Core/APIConfiguration.swift`) and throws `invalidConfiguration`. `gap-wave-compare.md`: 11 failures, 11 unexpected, `caught error: "invalidConfiguration"`. Production is the rule other fixtures already follow. |
| 7 | 1 | ProjectEditCompositionTests | 7 of 14 declarations. Wire role in the harness defaults to `player`, so the session-role fix does not explain the class. No published assertion names the 7 methods. Not changed. |
| 7 | 3 | TemplateShelfReadCompositionTests | 7 of 12 declarations. Owner copy: shipped catalog strings are the shorter plain-language copy; tests expect the longer reviewed copy (`docs/parity/full-suite-triage.md`). Not changed. |
| 4 | 1 | PrivateHomeSystemKeychainTests | All 4 methods. The tests require `errSecSuccess` from Security. Published diagnosis is OSStatus `-34018` on an unsigned host (`full-suite-triage.md`). Environment. |
| 4 | 1 | ZeroHPNormalHostRegressionTests | 4 of 6 declarations. The file has no `UIWindow` or `UIHostingController`. No published assertion isolates a product defect. |
| 3 | 1 | NativeChannelAppealEntryLocalizationTests | 3 of 7 declarations. Same owner copy decision. Current `Resources/NativeChannelAppealDetails.xcstrings` still has the shorter English, for example `entry.title` = `Appeal` against the test's `Channel moderation appeal`, and `recovery.readOriginal` = `Check result` against `Check original result`. |
| 3 | 1 | NativeChannelPinLocalizationTests | 3 of 6 declarations. Same owner copy decision. Current `Resources/NativeChannelMessage.xcstrings` has `p23.current.reading` = `Checking pinned messages…` against the test's `Current pinned list: an independent read is in progress.` `p23.operation.pin` / `unpin` / `sort` match the test and are not the mismatch. |
| 3 | 1 | WorkshopCreatorPendingNormalFlowTests | 3 of 12 declarations. Same owner copy decision (`full-suite-triage.md`). The long reviewed strings remain in the test. |
| 2 | 1 | ApprovedReleaseOriginalRecoveryTests | `testBackgroundAndLeavePreserveJournalAndInvalidateOldReader`, `testRestartReopensOriginalDurableIntentWithoutReplayOrMigration`. `ProjectEditModel.leave()` calls `saveLocal()` when the exit is not confirmed (`App/ProjectEditView.swift`). The tests compare the whole store. The release-journal value stays 1592 bytes on both sides (`gap-wave-compare.md`). 0 unexpected. The editor envelope is the product value. |
| 2 | 2 | ClubCommunityLifecycleTests | `testSuspendingDiscardsUnreviewedDraftAndAllowsFreshRead`, `testSuspendingNavigationKeepsThePostThatOwnsTheDestination`. `ClubCommunityFeedItem` requires `isPinned` as an `NSNumber` 0 or 1 (`Core/ClubCommunityReadCursor.swift`). The list fixture omits it. 0 unexpected. |
| 2 | 3 | ClubCommunityReadCompositionTests | `testApprovedReadCompositionReadsWithoutEnablingWritesAndRevokesImmediately`, `testHostAppCompositionRootAndRuntimeDetailToListReturnFlow`. Same `isPinned` contract. 0 unexpected. |
| 2 | 0 | NativeAttributeAuthorProjectHostTests | 2 of 23 declarations. No accessibility-tree symbol. No published assertion isolates a product defect. |
| 2 | 0 | NativeChannelMessageHostBindingTests | 2 of 8 declarations. Domain host authority, not the iOS accessibility tree. No published assertion isolates a product defect. |
| 2 | 2 | TemplateMetadataReadCompositionTests | 2 of 16 declarations. Owner copy mismatch. |
| 1 | 0 | ContentDraftSystemStorageTests | 1 of 4 declarations. Keychain `-34018` (`full-suite-triage.md`). Environment. |
| 1 | 1 | OwnMediaAudioPreviewHostTests | 1 of 20 declarations. Password login stays off (`full-suite-triage.md`). The failing selector is not published. |
| 1 | 0 | OwnMediaModelPreviewHostTests | 1 of 25 declarations. Same password-login decision. The failing selector is not published. |
| 1 | 3 | PlayRecoverySystemStorageTests | 1 of 2 declarations. Keychain `-34018`. Environment. |
| 1 | 2 | ProfileParticipantHostRecoveryTests | 1 of 7 declarations. No accessibility-tree symbol. No published assertion isolates a product defect. |
| 1 | 1 | RuntimeSessionRoleConsistencyTests | `testMissingExplicitRoleUsesActualAccountEffectiveRoleInBothSnapshots`. Conflicts with I00 admission. Fail-closed stays (`docs/parity/account-compliance-reconcile.md` row 7). |
| 1 | 0 | TemplateCoverReferenceClearTests | 1 of 16 declarations. Owner copy mismatch. |
| 1 | 3 | TemplateLocalMediaClearGroupTests | 1 of 18 declarations. Owner copy mismatch. |
| 1 | 1 | TemplateMediaReviewControllerTests | 1 of 13 declarations. Owner copy mismatch. |
| 1 | 3 | TemplateTimerOutcomeEditorTests | 1 of 21 declarations. Owner copy mismatch. |

39 hosted classes + these 24 + the 2 role-fix classes = 65. 142 + 64 + 16 = 222.

## Unexpected names

12 methods, from published `caught error` lines. They are inside the 222, not an extra set.

- Shard 3, all 11 `MerchantReviewOriginalRecoveryEntryTests` methods: `invalidConfiguration`. Not hosted accessibility.
- Shard 0, `ApprovedTopicReviewCompositionTests.testNormalSourceChoiceFactoryCarriesExactRefsThenReadsOnlySixFields`: `notConfigured`. The role pass-through above is already on this base and was not re-measured.

`CouponRuntimeCompositionTests` is 22 assertion records and 0 unexpected. `ClubCommunityLifecycleTests`, `ClubCommunityReadCompositionTests`, and `ApprovedReleaseOriginalRecoveryTests` are 0 unexpected in `gap-wave-compare.md`.

The other 113 unexpected names are not published. Hosted `InvalidTransition` is described in `full-suite-triage.md` and is part of the accessibility baseline above. This note does not turn that description into 113 method names.

## Not done

- No `xcodebuild`, no `swift test`, no new failure count.
- No product change on this branch. The only source defect proved from the failing paths is the omitted session role, and `f273c806c` already passes it.
- No test edit, no workflow edit, no CI manifest refresh.
