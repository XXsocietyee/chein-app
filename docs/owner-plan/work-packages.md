# Work packages — finishing PARTIAL/MISSING iOS items that need NO new backend endpoint

Source: `docs/owner-plan/gap-pl-1.md` .. `gap-pl-6.md` (gap tables against `questify-plan-v12.txt`), `docs/parity/page-map.csv`, `hook-wiring.md`, `final-integration-regression.md`, `full-suite-triage.md`. All treated as DATA. Base: `origin/wip/gm-next`. Docs-only; nothing here was compiled or run (Linux, no Xcode). File paths below were confirmed by `ls` on this checkout; line numbers come from the gap docs and must be re-grepped by the builder.

## Ground rules every WP inherits
- Shipped composition stays `makeComposition(reviewed: nil, …)` (`App/RegionalLaunchConfiguration.swift:10`). No WP flips a gate, issues a production approval/lease, or adds a route. A new route/lease needs a reviewed deployment gate and is out of scope.
- Safety gates ship **disabled**. Password login, bank withdrawal payout and virtual goods stay **OFF**. No mock/fixture data in the production path (fixtures only in `Tests/`).
- Buildable in the 3-way builder setup: `Core/*.swift`, `App/*.swift`, `Tests/**` only. Never edit `Resources/`, `Config/`, `tools/`, `.xcodeproj`, `docs/`. New `.swift` files are picked up by `python3 tools/generate_project.py` (the orchestrator runs it, builders do not hand-edit the project). If a WP would need a new localization key, the builder stops and reports it (orchestrator owns `Resources/*.xcstrings`); reuse existing keys.
- Two builders never edit the same file. Every WP creates its tests in **new, WP-prefixed test files** so test files never collide.
- **Hot files nobody may touch unless a WP lists them:** `App/AppSession.swift`, `App/AppCompositionRoot.swift`, `App/QuestifyApp.swift`, `Core/ChannelDiscordMessaging.swift`, `App/RegionalLaunchConfiguration.swift`.
- Never loosen/delete/skip an existing test. Failing-baseline classes in `full-suite-triage.md` are not these WPs' to "fix" by editing tests.
- Gap row IDs: PL-1 uses `DEC-xx`/`CH-READ-01`/`FRIEND-P41-01`/`F-MODULE-PREFLIGHT-01`; PL-2 rows are labelled only by card (`EXEC-nn`) so I name the row by topic in brackets; PL-3 `CTnn.x`/`Nxxx.x`; PL-4 `Cnn`/`Wnn.n`; PL-5 `Wnn.n`; PL-6 `T-nn`/`P-nn`.

## Summary (ordered by launch impact)

| WP | Title | Size | Conflicts with |
|---|---|---|---|
| WP-01 | IM unread / mention / read-ACK loop correctness | M | none |
| WP-02 | Location-share privacy tiers, no-leak bands, stop semantics | L | none |
| WP-03 | Walking navigation: clock-tamper, power/offline policy, 409 evidence | M | none |
| WP-04 | Owner-decision guard tests (absence + negative) | S | none (tests only) |
| WP-05 | Progress privacy: strictest-wins + default-closed photos | S | none |
| WP-06 | Friend / DM / block client rules | M | none |
| WP-07 | AI-identity + offline-node safety disclosure in real screens | M | WP-14 (soft: both `App/`, disjoint files) |
| WP-08 | Deep-link safety audit wired to the real entry | M | touches `AppSession.swift` (serial vs any later AppSession WP) |
| WP-09 | Coordinate / time / arrival guards | M | none |
| WP-10 | Shared client-operation-id + offline-pack hash rejection | M | none |
| WP-11 | Scoped cache key + push registration member binding | M | none |
| WP-12 | Module-preflight proof + Qmod import mount | S | none |
| WP-13 | Channel revoke isolation + rules-agreement gate proof | S | none |
| WP-14 | NPC chat-data revoke / expiry UX | S | WP-07 (soft) |

**First 3 in parallel: WP-01, WP-02, WP-03.** File sets are fully disjoint (IM/unread; personal-location-share; walking navigation) and each is highest-impact user-facing/safety work reachable without a backend change. Next wave: WP-04 + WP-05 + WP-06 (all small/medium, disjoint). Then WP-07/09/10/11 in any 3-way mix; WP-08 runs alone (touches the hot `AppSession.swift`).

Disjointness check (all pairs share zero files): WP-01 {IMUnreadTotal, NativeChannelMentionTargets, NativeChannelHistoryModel, NativeChannelMessageProjection, NativeChannelForegroundUnreadEntry}; WP-02 {PersonalLocationShare*}; WP-03 {WalkingNavigation*, CityWalkingAuthorityReader, StoryWalkingNavigationHostBridge, NativeWalkingNavigationFactory}.

---

## WP-01 — IM unread / mention / read-ACK loop correctness
- **Closes:** PL-2 `EXEC-03` [unread total monotonic guard / sender "in review" state row], `EXEC-03` [reply → mention of replied-to sender row], `EXEC-03` [late-approval insertion has no test row]; PL-1 `CH-READ-01` (unread-directory refresh after seen-ACK, "Top-10 #5"); PL-3 `CT03` reply-mention part.
- **Scope (no endpoint):** (a) monotonic-total guard so a stale/older `IMUnreadTotal` read never rolls the badge back; (b) pure helper mapping a replied-to message's sender to a mention target (the 3115-line messaging file is NOT edited — helper lives in the mention-targets file, wiring is a follow-up); (c) lock that a message approved late is placed by server order, not appended; (d) after `markSeen` receipt, the foreground unread entry requests a directory refresh.
- **Create/edit:** edit `Core/IMUnreadTotal.swift`, `Core/NativeChannelMentionTargets.swift`, `Core/NativeChannelHistoryModel.swift`, `Core/NativeChannelMessageProjection.swift`, `App/NativeChannelForegroundUnreadEntry.swift`. Create `Tests/CoreTests/WP01IMUnreadMonotonicTests.swift`, `Tests/CoreTests/WP01ReplyMentionTargetTests.swift`, `Tests/CoreTests/WP01LateApprovalOrderTests.swift`, `Tests/AppUnitTests/WP01SeenAckRefreshTests.swift`.
- **Must NOT touch:** `Core/ChannelDiscordMessaging.swift`, `Core/IMConversationReplyPolicy.swift`, `Core/IMExpandedCoordinator.swift`, `App/AppSession.swift`, `App/AppCompositionRoot.swift`, `App/MessagingHistoryView.swift`, any existing test file (esp. the failing `NativeChannelMessageHostBindingTests`, `NativeChannelHistoryTextHTTPRecoveryTests`).
- **Acceptance tests:** `WP01IMUnreadMonotonicTests.testOlderTotalNeverReplacesNewerTotal`, `…testNegativeAndNullStillRejectedAfterGuard`, `…testStaleSessionCompletionStillFenced`; `WP01ReplyMentionTargetTests.testReplyTargetsRepliedToSenderMemberID`, `…testReplyToSelfProducesNoMention`, `…testReplyToUnknownSenderProducesNoMention`; `WP01LateApprovalOrderTests.testLateApprovedMessageKeepsServerPosition`, `…testWithheldStatusStillVetoed`; `WP01SeenAckRefreshTests.testSeenReceiptTriggersDirectoryRefreshOnce`, `…testNoRefreshWhenAckUnknownOutcome`.
- **Conflicts:** none. **Size:** M. **Launch-impact rank:** 1 (IM is a P0 baseline loop).

## WP-02 — Location-share privacy tiers, no-leak bands, stop semantics
- **Closes:** PL-1 `DEC-06` (game location collection is a distinct switch from voluntary share; stopping share ≠ leaving game); PL-5 `W13.5` (distance-only tier), `W13.6` (hide-sensitive-place control; stranger layer coarse-only), `W13.7` (coarse distance bands + no-leak rules), `W13.8` (background/offline/team-exit/ban stop paths); PL-2 `EXEC-10` [stop/revoke row, Core part only].
- **Scope (no endpoint):** add a client-derived banded-distance presentation type and a hide-sensitive-place policy in the Core policy layer; prove stop semantics for each trigger with fake clocks/transports. The existing "distance not decodable" assertions are NOT changed — banding applies only to data the client is already entitled to show. Background location stays OFF (`allowsBackgroundLocationUpdates = false` untouched).
- **Create/edit:** edit `Core/PersonalLocationSharePolicy.swift`, `Core/PersonalLocationShareContracts.swift`, `Core/PersonalLocationShareCoordinator.swift`, `Core/PersonalLocationShareReceiverProjection.swift`; create `Core/PersonalLocationShareDistanceBand.swift`; tests `Tests/CoreTests/WP02DistanceBandTests.swift`, `Tests/CoreTests/WP02SensitivePlaceHideTests.swift`, `Tests/CoreTests/WP02StopSemanticsTests.swift`, `Tests/CoreTests/WP02GameVsShareSwitchTests.swift`.
- **Must NOT touch:** `App/PersonalLocationShareHost.swift`, `App/AppSession.swift` (share endpoints lines ~1005-1007 stay nil), `App/AppCompositionRoot.swift`, `Core/LocationShareContracts.swift`, existing `PersonalLocationShare*Tests.swift`.
- **Acceptance tests:** `WP02DistanceBandTests.testDistanceRoundsToBandNeverExact`, `…testBandOutputNeverContainsCoordinatesOrRawMeters`, `…testNearbySortTrailCountErrorFieldsDoNotLeakExactDistance`; `WP02SensitivePlaceHideTests.testHiddenPlaceCollapsesToCoarseForStrangers`, `…testStrangerLayerNeverRendersExactFix`; `WP02StopSemanticsTests.testBackgroundTransitionStopsShare`, `…testOfflineStopsShare`, `…testTeamExitStopsShare`, `…testBanStopsShare`, `…testStopAllClearsEveryRequestKey`; `WP02GameVsShareSwitchTests.testStoppingShareDoesNotEndGameSession`, `…testGameLocationCollectionDoesNotImplyShareConsent`.
- **Conflicts:** none. **Size:** L. **Rank:** 2 (privacy/safety, minors-adjacent).

## WP-03 — Walking navigation: clock-tamper, power/offline policy, 409 evidence
- **Closes:** PL-2 `EXEC-06` [system-clock tamper row], `EXEC-06` [409 on task submit keeps stored evidence row]; PL-5 `W15.5` (low-battery, offline-cache, foreground/background restore; lock-screen/voice recorded as policy); PL-3 `CT05.e` navigation-tolerance part.
- **Scope (no endpoint):** monotonic/uptime guard on authority expiry (replace wall-`Date()` comparison with an injected monotonic clock); a pure `WalkingNavigationPowerPolicy` that degrades update frequency on low-power/offline and keeps the checkpoint; test that a 409 keeps stored evidence. `SourceWalkingTargetAuthorizer` is NOT edited (real-source authorization needs backend fields — see WP-B05).
- **Create/edit:** edit `Core/WalkingNavigationCoordinator.swift`, `Core/WalkingNavigationContracts.swift`, `Core/CityWalkingAuthorityReader.swift`, `Core/StoryWalkingNavigationHostBridge.swift`, `App/NativeWalkingNavigationFactory.swift`; create `Core/WalkingNavigationPowerPolicy.swift`; tests `Tests/CoreTests/WP03AuthorityMonotonicClockTests.swift`, `Tests/CoreTests/WP03PowerOfflinePolicyTests.swift`, `Tests/CoreTests/WP03StoryEvidenceConflictTests.swift`.
- **Must NOT touch:** `Core/SourceWalkingTargetAuthorizer.swift`, `App/NativeCityWalkingConfiguration.swift`, `Core/ChallengePOI.swift` (WP-09), `App/AppSession.swift`, existing `WalkingNavigationTests.swift`, `SourceWalkingTargetTests.swift`.
- **Acceptance tests:** `WP03AuthorityMonotonicClockTests.testWallClockRewindDoesNotExtendExpiredAuthority`, `…testWallClockForwardJumpDoesNotExpireValidAuthority`, `…testExpiryUsesInjectedMonotonicClock`; `WP03PowerOfflinePolicyTests.testLowPowerReducesFixCadenceButKeepsCheckpoint`, `…testOfflineKeepsCachedRouteAndShowsWeakState`, `…testRestartRestoresCheckpointUnderLowPower`; `WP03StoryEvidenceConflictTests.testConflict409KeepsStoredEvidence`, `…testNoStraightLineRouteIntroduced`.
- **Conflicts:** none. **Size:** M. **Rank:** 3.

## WP-04 — Owner-decision guard tests (absence + negative)
- **Closes:** PL-1 `DEC-01` (no channel move; "add guard test"), `DEC-04` (no new minor-exposed feature; negative test), `DEC-05` (no random team-up), `DEC-07` (cancel quote stays unavailable until server contract; no refund arithmetic client-side); PL-1 `§1 Release boundary`.
- **Scope:** tests only — fail the build if someone adds a move route, a random-matchmaking symbol, client-side refund math, or a production lease in the shipped composition.
- **Create/edit:** create only `Tests/CoreTests/WP04OwnerDecisionGuardTests.swift` (reads `Core/NativeChannelManagementModels.swift`, `Core/FreeExploreLaunchCoordinator.swift`, `Core/FreeExploreCancelFlow.swift`, `App/RegionalLaunchConfiguration.swift` via source-text scan or public API only; read-only).
- **Must NOT touch:** every non-test file; every existing test.
- **Acceptance tests:** `WP04OwnerDecisionGuardTests.testManagementTransportHasNoChannelMoveRoute`, `…testNoRandomTeamMatchmakingSymbolsInAppOrCore`, `…testFreeExploreCancelQuoteStillUnavailableWithoutServerContract`, `…testNoClientSideRefundArithmeticInFreeExploreCore`, `…testShippedCompositionIsUnconfigured`, `…testNoMinorAgeDerivedFeatureEnablement`.
- **Conflicts:** none. **Size:** S. **Rank:** 4 (cheap insurance for "gates ship disabled").

## WP-05 — Progress privacy: strictest-wins + default-closed photos
- **Closes:** PL-1 `DEC-08` (strictest of user preference and channel permission; teammates' photos closed by default; audit-projection scope kept separate).
- **Scope:** pure resolver `NativeChannelProgressPrivacyResolver` over existing `NativeChannelProgressScope`/`PhotoScope`; used by the privacy view model only through the existing public `effective` values (no wire change).
- **Create/edit:** create `Core/NativeChannelProgressPrivacyResolver.swift`; edit `Core/NativeChannelProgressContracts.swift`, `Core/NativeChannelProgressPrivacyJournal.swift` (only to expose the resolver); tests `Tests/CoreTests/WP05ProgressPrivacyResolverTests.swift`.
- **Must NOT touch:** `App/NativeChannelProgressPrivacyView.swift`, `Core/NativeFriendProgressCard*.swift`, `Core/NativeChannelProgressCoordinator*.swift`, existing `NativeChannelProgress*Tests.swift`.
- **Acceptance tests:** `WP05ProgressPrivacyResolverTests.testStrictestScopeWinsAggregate`, `…testStrictestScopeWinsDetail`, `…testTeammatePhotoDefaultsClosed`, `…testPhotoOriginalNeverWiderThanDetail`, `…testAuditProjectionNotMergedIntoUserScopes`, `…testLeaderboardOutOverridesChannelIn`.
- **Conflicts:** none. **Size:** S. **Rank:** 5.

## WP-06 — Friend / DM / block client rules
- **Closes:** PL-1 `DEC-03` (existing non-friend DM stays sendable unless blocked/banned/self-rejected), `FRIEND-P41-01` (user-facing message for Apple-only/phone-only fail-closed review — message mapping only); PL-2 `EXEC-04` [unblock keeps relation removed row], `EXEC-04` [block-priority on request row]; PL-5 `W16.4` (client-side contact-frequency limiter, block ends contact).
- **Scope (no endpoint):** pure send-gate and frequency-limiter types; error-code→message mapping for already-defined server reject codes; assertions on existing flows. Uses `api/im/block` / `unblock` already in `sessionDependencies`; adds no friend-domain block route.
- **Create/edit:** edit `Core/NativeFriendFlow.swift`, `Core/NativeBlacklistService.swift`; create `Core/ContactFrequencyLimiter.swift`, `Core/DirectMessageSendGate.swift`; tests `Tests/CoreTests/WP06DMSendGateTests.swift`, `Tests/CoreTests/WP06ContactFrequencyLimiterTests.swift`, `Tests/CoreTests/WP06FriendBlockPriorityTests.swift`.
- **Must NOT touch:** `Core/NativeFriendService.swift`, `Core/NativeFriendContracts.swift` (wire contract), `App/AppCompositionRoot.swift` (friend approvals stay nil), `Tests/CoreTests/NativeFriendTransportTests.swift` (known-failing, owner-blocked), `FriendPermissionDistinctFromChannelTests.swift`.
- **Acceptance tests:** `WP06DMSendGateTests.testExistingNonFriendSessionStillSendable`, `…testBlockedSenderRefused`, `…testBannedRefused`, `…testSelfRejectRefused`; `WP06ContactFrequencyLimiterTests.testSecondContactInsideWindowRefused`, `…testWindowResetsWithInjectedClock`, `…testBlockEndsContactImmediately`; `WP06FriendBlockPriorityTests.testRequestToBlockedPeerNeverSent`, `…testUnblockDoesNotRestoreFriendship`, `…testReviewFailClosedMapsToUserMessage`.
- **Conflicts:** none. **Size:** M. **Rank:** 6.

## WP-07 — AI-identity + offline-node safety disclosure in real screens
- **Closes:** PL-4 `W09.3`, `W09.4`, `W09.5`, `W09.8`, "Top-15 #4/#5"; PL-4 `C05` (permission/disclosure copy audit, disclosure part).
- **Scope:** render existing `AIIdentityDisclosure` / `OfflineNodeSafetyState` inside the real NPC/assistant screen and walking-navigation info section (currently only in fixture-only `App/OpsSafetyViews.swift`). Reuse existing localization keys; if a key is missing the builder stops and reports.
- **Create/edit:** edit `App/ShopNPCView.swift`, `Core/SafetyDisclosure.swift`; create `App/SafetyDisclosureBanner.swift`; tests `Tests/CoreTests/WP07DisclosurePolicyTests.swift`, `Tests/AppUnitTests/WP07ShopNPCDisclosureTests.swift`.
- **Must NOT touch:** `App/OpsSafetyViews.swift` (stays fixture-only, mounted at `App/QuestifyApp.swift:24`), `App/QuestifyApp.swift`, `Resources/**`, `App/NPCChatDataView.swift` (WP-14), existing `SafetyDisclosureTests.swift`.
- **Acceptance tests:** `WP07DisclosurePolicyTests.testNPCReplyAlwaysCarriesAIIdentity`, `…testOfflineNodeShowsUnknownSafetyWhenNoSignal`, `…testNoAutoFundsClauseShownBeforePayAction`; `WP07ShopNPCDisclosureTests.testBannerPresentInProductionShopNPCView`, `…testBannerAbsentDoesNotCrashWhenPolicyNil`.
- **Conflicts:** WP-14 (soft; disjoint files, same `App/` area). **Size:** M. **Rank:** 7.

## WP-08 — Deep-link safety audit wired to the real entry
- **Closes:** PL-4 `C05` (deep-link safety "actually wired"), "Top-15 #6"; PL-2 `EXEC-02` [invite landing safety — classification only, no new channel route].
- **Scope:** route `session.receiveNativeURL` through `DeepLinkAndUniversalLinkSafetyAudit` first; unsafe/unknown → inert, no navigation, no network. Allowed destinations remain the audit's existing `SafeDestination` set. Adds no endpoint.
- **Create/edit:** edit `Core/DeepLinkAndUniversalLinkSafetyAudit.swift` (only if a missing case is needed), `App/DeepLinkSafetyDiagnosticsSectionView.swift`, and a **single minimal hunk** in `App/AppSession.swift` (`receiveNativeURL`); tests `Tests/AppUnitTests/WP08ReceiveNativeURLAuditTests.swift`, `Tests/CoreTests/WP08DeepLinkAuditCoverageTests.swift`.
- **Must NOT touch:** `App/QuestifyApp.swift` (the `.onOpenURL` at ~366 already calls `receiveNativeURL`), `App/AppCompositionRoot.swift`, any other part of `App/AppSession.swift`, existing `DeepLink*Tests.swift`.
- **Acceptance tests:** `WP08ReceiveNativeURLAuditTests.testUnsafeSchemeIsInertNoNavigation`, `…testUnauthenticatedProtectedLinkDoesNotNavigate`, `…testWrongRealmRejected`, `…testSafePublicTopicLinkRoutes`; `WP08DeepLinkAuditCoverageTests.testEveryAppEntryURLShapeHasAClassification`.
- **Conflicts:** `App/AppSession.swift` is hot — run WP-08 alone (no other WP in flight that edits AppSession). **Size:** M. **Rank:** 8.

## WP-09 — Coordinate / time / arrival guards
- **Closes:** PL-3 `CT05.b` (receive time vs sampling time; backfill ≠ "online now"; no fake teleports), `CT05.e` (tolerance/interpolation never counts as arrival or mileage).
- **Create/edit:** edit `Core/MapCoordinateObservation.swift`, `Core/ChallengePOI.swift`, `Core/RoamExperienceCoordinators.swift`; tests `Tests/CoreTests/WP09ObservationReceiveTimeTests.swift`, `Tests/CoreTests/WP09TeleportBackfillTests.swift`, `Tests/CoreTests/WP09ArrivalToleranceSeparationTests.swift`.
- **Must NOT touch:** `Core/RoamLiveSessionController.swift`, `Core/NearbyMerchantCoordinator.swift` (live GCJ-02 callers, separate decision), `Core/RuntimeLocationProjection.swift`, `Core/WalkingNavigation*` (WP-03), existing `MapCoordinateObservationTests.swift`, `ChallengePOI*Tests.swift`.
- **Acceptance tests:** `WP09ObservationReceiveTimeTests.testReceiveTimeRecordedSeparatelyFromSampleTime`, `…testBackfilledPointNotOnlineNow`; `WP09TeleportBackfillTests.testImpossibleJumpFlaggedNotAccepted`; `WP09ArrivalToleranceSeparationTests.testNavigationToleranceDoesNotCountAsAuthoritativeArrival`, `…testInterpolatedPointsAddNoMileage`.
- **Conflicts:** none. **Size:** M. **Rank:** 9.

## WP-10 — Shared client-operation-id + offline-pack hash rejection
- **Closes:** PL-3 `CT08.a` (account+object+body-bound operation id), `CT08.e` (offline pack rejects `codeHash`/`code_hash`), `CT08.f` (permanent id per offline write; resume uses original id).
- **Scope:** new pure `ClientOperationID` value type + store protocol (in-memory + file-journal implementations); no feature migrated onto it in this WP (per-feature pending stores keep working).
- **Create/edit:** create `Core/ClientOperationID.swift`; edit `Core/OfflinePackOperation.swift`; tests `Tests/CoreTests/WP10ClientOperationIDTests.swift`, `Tests/CoreTests/WP10OfflinePackHashRejectionTests.swift`.
- **Must NOT touch:** `Core/OfflineDurableRecoveryAudit.swift`, `Core/H5AnswerProtection.swift`, `Core/FreeExploreLaunchContracts.swift`, `Core/ChannelGovernanceProjection.swift`, existing `OfflinePackOperationTests.swift`.
- **Acceptance tests:** `WP10ClientOperationIDTests.testIDBoundToSubjectObjectAndBodyHash`, `…testResumeReusesOriginalID`, `…testDifferentBodyYieldsDifferentID`, `…testAccountSwitchNeverReusesID`; `WP10OfflinePackHashRejectionTests.testCodeHashFieldRejected`, `…testSnakeCaseCodeHashRejected`, `…testAnswersStillRejected`.
- **Conflicts:** none. **Size:** M. **Rank:** 10.

## WP-11 — Scoped cache key + push registration member binding
- **Closes:** PL-3 `CT12.d` (cache key = account + object + privacy + content version; purge on revoke/logout), `CT12.f` (push token bound to member + installation + environment; account switch/revoke drops old audience).
- **Scope:** Core types and tests only. APNs handler wiring and push dedup are NOT in scope (BLOCKED-ON-OWNER).
- **Create/edit:** create `Core/ScopedCacheKey.swift`; edit `Core/DevicePushRegistrationLifecycle.swift`, `Core/ImageAndVideoDiskCacheBudgetAudit.swift`; tests `Tests/CoreTests/WP11ScopedCacheKeyTests.swift`, `Tests/CoreTests/WP11PushMemberBindingTests.swift`.
- **Must NOT touch:** `App/AppSession.swift`, `Core/ChannelRevokeIsolation.swift` (WP-13), existing `DevicePushRegistrationLifecycleTests.swift`.
- **Acceptance tests:** `WP11ScopedCacheKeyTests.testKeyDiffersByAccountObjectPrivacyAndVersion`, `…testRevokedShareImageNotReusable`, `…testLogoutPurgesAccountKeys`; `WP11PushMemberBindingTests.testAccountSwitchDropsOldAudience`, `…testEnvironmentChangeRebindsMember`, `…testRevokeDeregistersToken`.
- **Conflicts:** none. **Size:** M. **Rank:** 11.

## WP-12 — Module-preflight proof + Qmod import mount
- **Closes:** PL-1 `F-MODULE-PREFLIGHT-01` (diagnostics test, version-bound revalidation, READY ≠ publish); PL-2 `EXEC-05` [Qmod import view unmounted row]; PL-5 `W18.1`, `A09` (author import reachable).
- **Scope:** tests over `GET api/topic/module-preflight` already defined in the service; mount `QmodAuthorImportView` in the author views behind the existing author gate (no new route — import is local inspection only).
- **Create/edit:** edit `App/NativeAttributeAuthorViews.swift` (mount), `Core/NativeAttributeAuthorCoordinator.swift` (revalidate-bound-to-version only if test shows a gap); tests `Tests/CoreTests/WP12ModulePreflightDiagnosticsTests.swift`, `Tests/AppUnitTests/WP12QmodImportMountTests.swift`.
- **Must NOT touch:** `Core/NativeAttributeAuthorService.swift` (wire), `App/QmodAuthorImportView.swift`, `Core/QmodArchiveInspection.swift`, `Core/TemplateAuthoring*` (publish conflict needs a backend precondition), existing `NativeAttributeAuthor*Tests.swift`.
- **Acceptance tests:** `WP12ModulePreflightDiagnosticsTests.testFieldAndNodeDiagnosticsDecoded`, `…testRevalidateBoundToSavedVersion`, `…testReadyDoesNotImplyPublish`, `…testStaleVersionPreflightDiscarded`; `WP12QmodImportMountTests.testImportEntryReachableFromAuthorViews`, `…testImportDoesNotIssueNetworkRequest`.
- **Conflicts:** none. **Size:** S. **Rank:** 12.

## WP-13 — Channel revoke isolation + rules-agreement gate proof
- **Closes:** PL-1 `DEC-02` (rule agreement is the single gate before first post; later rules upgrade is separate); PL-2 `EXEC-02` [revoke isolation not used in App row — Core hook only], `EXEC-02` [hash-vs-integer rules version note recorded as test].
- **Create/edit:** edit `Core/ChannelRevokeIsolation.swift` (expose a purge callback protocol), `Core/ChannelRulesAdmission.swift`, `Core/NativeChannelOnboarding.swift`; tests `Tests/CoreTests/WP13RulesAgreementGateTests.swift`, `Tests/CoreTests/WP13RevokePurgeHookTests.swift`.
- **Must NOT touch:** `Core/ChannelGovernanceProjection.swift`, `App/AppSession.swift`, `App/NativeChannelOnboardingView.swift`, existing `ChannelRevokeIsolationTests.swift`, `ChannelGovernanceProjectionTests.swift`.
- **Acceptance tests:** `WP13RulesAgreementGateTests.testFirstPostRefusedUntilRulesAgreed`, `…testAgreeOnceThenPostAllowed`, `…testRulesUpgradeRequiresSeparateReconsent`, `…testStaleCASConflictKeepsPending`; `WP13RevokePurgeHookTests.testRevokeInvokesPurgeCallbackForChannelCaches`, `…testPurgeRunsExactlyOncePerRevoke`.
- **Conflicts:** none (WP-11 owns cache keys; this only exposes the hook). **Size:** S. **Rank:** 13.

## WP-14 — NPC chat-data revoke / expiry UX
- **Closes:** PL-4 `W04.6` / "Top-15 #14" (consent revoke/expiry; copies cleared).
- **Scope:** UI state + local-copy clearing on revoke/expiry using the existing read-settings entry; no deletion endpoint (server deletion is BLOCKED-ON-BACKEND — the UI states only what the client did).
- **Create/edit:** edit `App/NPCChatDataView.swift`, `App/NPCChatDataReadSettingsEntry.swift`; tests `Tests/AppUnitTests/WP14NPCChatDataRevokeTests.swift`.
- **Must NOT touch:** `App/ShopNPCView.swift` (WP-07), `App/AppSession.swift`, `Resources/**`.
- **Acceptance tests:** `WP14NPCChatDataRevokeTests.testRevokeClearsLocalCopiesAndShowsRevokedState`, `…testExpiredConsentShowsExpiredState`, `…testRevokeDoesNotClaimServerDeletion`.
- **Conflicts:** WP-07 (soft). **Size:** S. **Rank:** 14.

---

## BLOCKED-ON-BACKEND (do not start; listed with exactly what each waits for)
Real backend source has no commercial-bundle (组合包) controllers — only `/api/free-explore/bundle`.

| ID | Items | Waits for |
|---|---|---|
| WP-B01 | Bundle domain `T-01`..`T-17` (shelf, detail, merchant-slot, order confirm, pay result, voucher, redeem result, appeal, refund quote/apply/progress), `T-18..T-20`, `N003`/`BUNDLE-BOOKING-01` entitlement & balance, `CT09.b/c`, `DEC-07` cancel quote | Bundle controllers (`EP-BND-*`, `EP-CMP-01`, `EP-RFD-*`), server cancel-quote contract. Today `FreeExploreLaunchCoordinator.swift:113-115` rightly throws `cancellationQuoteUnavailable`. |
| WP-B02 | Money loop: `pay/app` admission, ticket dyncode/redeem/receipt/groupcode routes (`EXEC-08`, PL-4 Top-15 #1) | Backend route confirmation + reviewed lease. |
| WP-B03 | Orient / city-game: `api/orient/*` player write routes, `EP-ORT-*`, `T-25..T-42`, `T-37` SOS, `W20.5/14/16` `CityGameServing`, CT07 result facts | Orient controllers / city-game service; owner choice whether to repoint from `api/play/city-orientation/*`. |
| WP-B04 | Merchant: operators (`api/merchant/operators/*`), `city-node/save`, store-day, verify decision/form (`T-49/50`, `EP-VRF-*`), slots/arrivals (`T-46/47`, `EP-PRD-*`), holds (`T-52`) | Routes absent per `hook-wiring.md`. |
| WP-B05 | Walking navigation for real sources (`W15.1/4`, `EXEC-06` authorizer): datum/authorityRevision/expiry fields; `api/city/walking/target` undocumented | Backend fields + endpoint documentation. |
| WP-B06 | Map aggregated layers `W13.1` (`QueryMapLayers`); leaderboards `L01` (world/season/team, appeal) | Backend endpoints. |
| WP-B07 | Side quest player flow (`W14.2/3`, `EXEC-12`), friend-domain block route, template publish expected-version/conflict (`EXEC-05`), square block, invoice writes `N005`, home-return `W19.4/6`, takedown rights/appeal `W18.4/8`, POI review `W14.5` | Backend routes / contracts. |

## BLOCKED-ON-OWNER (do not start)
| ID | Item | Waits for |
|---|---|---|
| WP-B08 | Shipped build is `reviewed: nil` → no loop reaches a server (`EXEC-01`, PL-1 Top-10 #1, PL-3 sign-off) | Owner-reviewed deployment (base URL, realm, bundle, `productionGatesEnabled`) and per-gate approvals/leases. |
| WP-B09 | Core/AppUnit baseline failures ("STALE / OWNER" in `full-suite-triage.md`: `CityNodeRedemptionTests`, `ClubAction*`, `MerchantStoreIndustry*`, `NativeFriendTransportTests`, `PrivateHomeRecoveryFenceTests`, copy-mismatch classes, password-gate class) | Owner decision which side is truth (test vs shipped code/copy). Builders must not edit these tests. |
| WP-B10 | Payment split: virtual goods IAP vs offline consumption WeChat (`T-04/T-05`) | Owner decision. |
| WP-B11 | 176/182-ID ledger import (PL-1 Top-10 #4); N004–N006, in-flight themes list; 17 unaudited IDs (`C01,S01,…`) | Owner supplies ledger / original text (底稿A/M7). |
| WP-B12 | GCJ-02→WGS provider for mainland routing; background location; push dedup/APNs handler; token renewal / capability negotiation (`EXEC-01`) | Owner provider/privacy/APNs review. |
| WP-B13 | Real-device run, Dynamic Type/dark/small-screen evidence (`C04`), full localization sweep and missing `MerchantOrderGoods.xcstrings` (`C03`), AppStore readiness enforcement (`W09.9`), password login / bank payout / virtual goods | Device access, `Resources/` ownership, legal/platform approval; these stay OFF. |
