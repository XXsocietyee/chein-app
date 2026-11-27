# debt/appunit-b receipt

Lane: test-debt appunit-b, branched from `origin/ui/combined-r7` (c24b7d96c).
Scope: second third (classes 15–28 of 42, sorted) of `origin/ci/acceptance:docs/release/baselines/appunit.txt`. None of these class names contain Merchant or Coop.
No compiler or simulator was available. Every change was checked by reading the code and grepping APIs, and none of it was run. Gates: check_scaffold PASS, check_a11y_lint PASS (0 new), contract_ratchet --check new 0.

- OwnMediaAudioPreviewHostTests/testOriginalLoginGateTransitionStopsOldAudioEvenWhenLoginFails — fixed-test — password login is disabled (Core/RegionalConfiguration.swift implemented capabilities; App/AppSession.swift `passwordLoginCompiledIn` / `guard let service`, 02c68098f/7623036a3), so `login(username:password:)` refuses before any gate transition. The test now pins that refusal, then covers the surviving route (logout, then a failed SMS `loginWithPhone`) and checks the old audio stops.
- OwnMediaModelPreviewHostTests/testOriginalLoginGateTransitionStopsOldModelEvenWhenLoginFails — fixed-test — same cause and rewrite as the audio test.
- PremergeScreensViewModelTests/testAppSessionMemberPopupClosuresSignedOutAndSignedIn — fixed-test — `/api/club/my` now decodes `data.owned` (Core/ClubService.swift, 02c68098f; MP pages/shezhi/shezhi.js:123). The bare-array stub was stale.
- ProfileFavoriteDetailTests/testRealAuthorAndCommentAuthorChildNavigationReturnsToSameDetailReader — left — hosted HostedNavigationSceneWindow test; the root never appears under the iOS 27 sim (docs/parity/full-suite-triage.md:126, cb92-appunit-triage.md:77). No code defect found.
- ProfileFavoriteTopicReadTests/testNormalFullDetailAndChapterCoverReturnUseSameReaderUntilRootLeaves — left — same hosted-environment class (full-suite-triage.md:58,126). No code defect found.
- ProfileGuideReadTests/testOrdinaryConfiguredGuideLoadsOriginalListAndRefreshesWithoutWrites — left — the known code causes are already fixed in 03732e2df. What remains is hosted lazy-List rendering, which can't be diagnosed without the CI message.
- ProfileParticipantHostRecoveryTests/testBackgroundAndLeaveDoNotReplayAndSameOwnerReloginRetainsOnlyMemoryLock — fixed-test — the host defaults to `ParticipantFileJournal.applicationSupport` (7623036a3), so the PII-free durable lock is restored on same-owner relogin as `.outcomeUnknown(.transport)`, as ProfileParticipantDurableHostTests pins. The test still asserts no replay and no payload.
- ProfileSettingsFavoritesTests/testSettingsCollectionUsesOriginalDetailAndKeepsOwnerWhenCovered — left — the code bug (inactive scene dismissing the page) is already fixed in 8d33f1bde/113554aed. What remains is the hosted environment (full-suite-triage.md:48).
- ProfileWeeklyPointsSectionTests/testNormalOwnerHostReadsWeeklyWhilePublicParentIsUnavailable — left — the behaviour is present (App/SocialPublicProfileView.swift:71-76, 113554aed) and the fixture traces clean. Listed as a hosted baseline (full-suite-triage.md:45).
- RegistrationUncertainEvidenceCacheTests/testFailureAllowsNewReadAndCancellationIsNotFailure — fixed-test — the shared fixture quote had payAmount 12.5. `confirm` refuses non-zero quotes (Core/RegistrationCoordinator.swift:251, 02c68098f; pinned by CoreTests testPaidQuoteDoesNotCreate), so create never ran and no unknown-outcome scope existed. The fixture is now payAmount 0.
- RegistrationUncertainEvidenceCacheTests/testLateCompletionCannotCrossBackgroundAndNewRead — fixed-test — same fixture fix.
- RegistrationUncertainEvidenceCacheTests/testLeaveAndReopenCannotReusePriorVisit — fixed-test — same fixture fix.
- RegistrationUncertainEvidenceCacheTests/testReaderReplacementRevisionAndAccountChangeCannotReuseEvidence — fixed-test — same fixture fix.
- RegistrationUncertainEvidenceCacheTests/testRealUnknownReadCachesWithoutUnlockingOrReplaying — fixed-test — same fixture fix.
- RegistrationUncertainEvidenceCacheTests/testRevokedReaderImmediatelyHidesCachedIDs — fixed-test — same fixture fix.
- RoamAlbumDenialHostTests/test503KeepsConfirmedMetadataAndOriginalRetryReadsSamePage — left — the full model and view path traces clean, and the sibling model test passes. Filed as iOS 27 hosted AX/presentation (full-suite-triage.md:64).
- RoamAlbumIntentLifetimeTests/testActualBackgroundDoesNotReopenOriginalExpiredMetadataScope — left — traces clean. The class is recorded as hosted-AX flaky, with a different method failing each run (receipts/integ-r6/README.md:27).
- RoamAnniversaryHistoryRecoveryTests/testBothHistoryEntriesForwardOriginalTopicForEmptyAndNonEmptyLocalHistory — fixed-code (speculative, not run) — every failing test in this class goes through the empty-history branch. Since 66a5a4794 (List conversion), that branch declared `navigationDestination(isPresented:)` inside a lazy List row, against the repo rule at App/RoamPassportHistoryView.swift:44. The destination is moved to List level in App/RoamHistoryViews.swift.
- RoamAnniversaryHistoryRecoveryTests/testHistoryWithoutInjectedDestinationKeepsExistingUnavailableState — fixed-code (speculative) — same cause.
- RoamAnniversaryHistoryRecoveryTests/testMissingToolsReaderStillHidesHistoryToolsWithoutInventingGrant — fixed-code (speculative) — same cause, plus a missing hosted anchor for `roam.experience.history.empty` (the record branch has one). An anchor was added in App/RoamHistoryViews.swift.
- RoamAnniversaryHistoryRecoveryTests/testRevocationWhileTopicIsOpenRetiresOriginalRouteAndPrivateRowsWithoutNewRead — fixed-code (speculative) — same cause.
- RoamAnniversaryHistoryRecoveryTests/testTwoPageReturnFailureKeepsOldRowsThenRetriesSameDayAndLoadedDepthAtomically — fixed-code (speculative) — same cause.
- RoamAnniversaryHostRestorationTests/testBrowserMenuHubForwardsTheSameOriginalTopicDestination — left — identifiers, fixture and decoder all match, and nothing has changed since 02c68098f. Filed as iOS 27 hosted-AX (full-suite-triage.md:16).
- RoamAnniversaryHostRestorationTests/testBrowserPassportReadFailureRetryExactTopicAndBack — left — the 503 → retry → row/openRoute path traces clean. No defect found.
- RoamAnniversaryHostRestorationTests/testUninjectedBrowserKeepsSuccessfulHistoryCardButRouteUnavailable — left — `.noDestination` already shows routeUnavailable (App/RoamPassportToolsViews.swift:267-283,369-388). The failure is hosted-only.

Totals: 11 fixed-test, 5 fixed-code (speculative, needs a Mac run), 9 left.

Re-check 2026-11-27: merged `origin/ui/combined-r7` at a0de1bd16 (21 new commits; this lane's earlier work was already in it). The baseline on `origin/ci/acceptance` is unchanged (266cddbb7), so this lane still covers the same 14 classes. The new App/Core changes (ObjectBadge, Journey, Roam recap/share/city guide, ProjectEditHTTPService) don't touch any test or code path listed above, and no line in this receipt changes. Gates were re-run on the merged tree.
