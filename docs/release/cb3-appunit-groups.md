# CB3 AppUnit class groups

Base `origin/rc/20261108` `a6871477c`. Branch `cursor/cb3`. This VM has no Xcode and no simulator. AppUnit was not re-run, and this note does not replace the Mac failure count.

## Baseline totals

Task baseline: **7566 tests, 545 failures, 125 unexpected, 222 methods, 65 classes**.

The same class list is the unique `Failing tests:` set recorded on `origin/cursor/A2` `15067547d` (`docs/release/launch-rc-report.md`). That runner line is:

```
Executed 7566 tests, with 548 failures (125 unexpected) in 770.824 (772.469) seconds
```

Xcode's 548 is the assertion total, not unique tests. The failing-test list is 222 methods in 65 classes. `WalletEarningsSegmentHitAreaTests` is not in that list. `RegionalLaunchConfiguration` still calls `makeComposition(reviewed: nil, build: .current)`.

## Group 1 — iOS 27 host accessibility baseline (39 classes, 142 methods)

These classes need the iOS 27 host accessibility tree: `XCUIApplication`, `UIWindow`, `UIHostingController`, `HostedNavigationSceneWindow`, or a hosted Settings view. They are baseline, not product bugs. No test was deleted, skipped, or weakened, and none of these files were edited.

| methods | class | host signal |
|---:|---|---|
| 11 | WorkshopPaidProfessionalNormalFlowTests | UIWindow, UIHostingController |
| 9 | RoamPlaceDetailReadLifetimeTests | UIWindow, UIHostingController |
| 7 | NativeChannelHistoryTextHTTPRecoveryTests | UIWindow, UIHostingController |
| 7 | NativeChannelTextReadOnlyPresentationTests | UIWindow, UIHostingController |
| 7 | RoamShareNativeLifetimeTests | UIWindow, UIHostingController |
| 6 | RoamAnniversaryHistoryRecoveryTests | UIWindow, UIHostingController |
| 6 | RoamHistoryHubToolsTests | UIWindow, UIHostingController |
| 6 | RoamNearbyOwnedStateRecoveryTests | UIWindow, UIHostingController |
| 5 | RoamEnrolledTopicsLifetimeTests | UIWindow, UIHostingController |
| 5 | WorkshopCreatorConsentNormalFlowTests | UIWindow, UIHostingController |
| 4 | NativeFriendRequestReviewHostingTests | UIHostingController |
| 4 | OfficialPublicEventCompositionTests | UIHostingController |
| 4 | RoamAnniversaryHostRestorationTests | UIWindow, UIHostingController |
| 4 | RoamAnniversaryReadIntentTests | UIWindow, UIHostingController |
| 4 | RoamHomeResumeEntryRecoveryTests | UIWindow, UIHostingController |
| 4 | RoamMonthlyRecapNaturalEntryTests | UIWindow, UIHostingController |
| 4 | RoamNearbyEventsOriginalHostTests | UIWindow, UIHostingController |
| 4 | RoamOfficialTasksLifetimeTests | UIWindow, UIHostingController |
| 4 | RoamTileIntentLifetimeTests | UIWindow, UIHostingController |
| 4 | WorkshopPaidInstallNormalFlowTests | UIHostingController |
| 3 | NativeFriendDirectoryNavigationHostingTests | UIHostingController |
| 3 | RoamAlbumDenialHostTests | UIWindow, UIHostingController |
| 3 | RoamAlbumIntentLifetimeTests | UIWindow, UIHostingController |
| 3 | RoamCreatedStampReadLifetimeTests | UIWindow, UIHostingController |
| 3 | RoamMonthlyRecapRestoredHostTests | UIWindow, UIHostingController |
| 3 | RoamTileDenialHostTests | UIWindow, UIHostingController |
| 2 | NativeBlacklistEntryHostingTests | UIHostingController |
| 2 | WorkshopPaidInstalledTextNormalFlowTests | UIWindow, UIHostingController |
| 1 | NativeRpgConditionAuthorClosureTests | UIHostingController |
| 1 | NativeRpgEnvironmentAuthorClosureTests | UIHostingController |
| 1 | NearbyMapDiscoveryRecoveryTests | UIWindow, UIHostingController |
| 1 | OfficialEventComponentsClosureTests | UIHostingController |
| 1 | ProfileFavoriteDetailTests | UIWindow, UIHostingController |
| 1 | ProfileFavoriteTopicReadTests | UIWindow, UIHostingController |
| 1 | ProfileSettingsFavoritesTests | UIHostingController, hosted Settings |
| 1 | ProfileWeeklyPointsSectionTests | UIWindow, UIHostingController |
| 1 | RoamExportReadHostRecoveryTests | UIWindow, UIHostingController |
| 1 | RoamMedalSystemShareSourceTests | UIWindow, UIHostingController |
| 1 | WorkshopPurchasedNormalAccountTests | UIWindow, UIHostingController |

## Group 2 — product defect fixed (2 classes, 16 methods)

`CompositionHTTPTransport` built `PlayExperienceSession` without the captured account role. The initializer defaults that argument to `"player"`. The following `RuntimeDependencyContext` kept the real role (`merchant` or `club`) but a play session whose role was still `player`.

`RuntimeDependencyContext` equality includes `session.role`. A merchant viewer therefore did not match the live context:

- Coupon read and `sendConfirmed` call `couponReadApproval` / `couponWriteApproval` with that mismatched context. The AppUnit grants replace a lease when the context is not equal, so the coordinator's captured session stops being current. `preparePublish` then returns with `review == nil`. That is the 15 failing methods in `CouponRuntimeCompositionTests`.
- `approvedReleaseConfiguration` returns nil unless the argument equals `currentRuntimeDependencyContext`. Merchant source reads then throw `notConfigured` from `ApprovedTopicReviewClient.send` before the wire. That is `ApprovedTopicReviewCompositionTests.testNormalSourceChoiceFactoryCarriesExactRefsThenReadsOnlySixFields`. Player review methods in the same class already matched the default and are not in the failing list.

The constructors that feed a `RuntimeDependencyContext` now pass `role: role`. For a player account the value is the same as the old default. Tests were not edited.

## Group 3 — not a product defect proven from this tree (24 classes, 64 methods)

Left unchanged. No test was deleted, skipped, or weakened.

| methods | class | why it was not changed |
|---:|---|---|
| 11 | MerchantReviewOriginalRecoveryEntryTests | `APIConfiguration` rejects a host ending in `.invalid`. The harness uses that host. Production is the rule other tests already require. |
| 7 | ProjectEditCompositionTests | No host-tree symbol, and the wire role is `player`, so the session-role fix does not apply. No assertion text on this tree isolates a product defect. |
| 7 | TemplateShelfReadCompositionTests | Shipped copy is the shorter plain-language string. The test expects the longer reviewed copy. Owner decision, same as `docs/parity/full-suite-triage.md`. |
| 4 | PrivateHomeSystemKeychainTests | Keychain `-34018` on an unsigned test host. Environment. |
| 4 | ZeroHPNormalHostRegressionTests | The name is a zero-HP host, not `UIWindow` / `UIHostingController`. No source contradiction was isolated. |
| 3 | NativeChannelAppealEntryLocalizationTests | Same owner copy mismatch. |
| 3 | NativeChannelPinLocalizationTests | Same owner copy mismatch. |
| 3 | WorkshopCreatorPendingNormalFlowTests | Same owner copy mismatch. |
| 2 | ApprovedReleaseOriginalRecoveryTests | `ProjectEditModel.leave()` writes one `project-editor.v1.` envelope when the exit is not confirmed. The release journal bytes are the product value. The tests compare the whole store. |
| 2 | ClubCommunityLifecycleTests | `ClubCommunityFeedItem` requires `isPinned` 0 or 1. The list fixture omits it. Production is the stricter contract. |
| 2 | ClubCommunityReadCompositionTests | Same `isPinned` fixture gap. |
| 2 | NativeAttributeAuthorProjectHostTests | Domain host object, not the iOS accessibility tree. No isolated product defect. |
| 2 | NativeChannelMessageHostBindingTests | Domain host authority, not the iOS accessibility tree. No isolated product defect. |
| 2 | TemplateMetadataReadCompositionTests | Owner copy mismatch. |
| 1 | ContentDraftSystemStorageTests | Keychain `-34018`. Environment. |
| 1 | OwnMediaAudioPreviewHostTests | Password gate. Password login stays off. |
| 1 | OwnMediaModelPreviewHostTests | Password gate. Password login stays off. |
| 1 | PlayRecoverySystemStorageTests | Keychain `-34018`. Environment. |
| 1 | ProfileParticipantHostRecoveryTests | Domain host, not the iOS accessibility tree. No isolated product defect. |
| 1 | RuntimeSessionRoleConsistencyTests | `testMissingExplicitRoleUsesActualAccountEffectiveRoleInBothSnapshots` conflicts with I00 admission. Fail-closed stays. See `docs/parity/account-compliance-reconcile.md` row 7. |
| 1 | TemplateCoverReferenceClearTests | Owner copy mismatch. |
| 1 | TemplateLocalMediaClearGroupTests | Owner copy mismatch. |
| 1 | TemplateMediaReviewControllerTests | Owner copy mismatch. |
| 1 | TemplateTimerOutcomeEditorTests | Owner copy mismatch. |

39 + 2 + 24 = 65 classes. 142 + 16 + 64 = 222 methods.

## Not done

- No `xcodebuild`, no simulator, no new failure count.
- No visual restyle, no CI ledger refresh, no deploy, no secrets.
- `makeComposition(reviewed: nil)` is unchanged.
