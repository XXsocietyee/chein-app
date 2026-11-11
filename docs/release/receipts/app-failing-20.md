# App unit failing 20: root causes (code-only; nothing was built or run)

Base: local ui/main 52dcf72dd. Failure messages read from `/private/tmp/design-build/unit2.xcresult` (read-only).
No assertion was weakened or removed. Nothing here has been executed; the next cloud Test lane is the verification.

| test | cause | fix |
|---|---|---|
| NativeChannelAppealEntryLocalizationTests x3 | `NativeChannelAppealDetails.xcstrings` carried shorter plain-language copy that dropped safety wording (no new appeal / no automatic resend, original-request framing, `operation.original`, `status.unknown`). The tests are the reviewed copy and the python contract also references it. | Catalog now carries the reviewed copy for all 29 keys under test (en + zh-Hans). Longer text is the safer copy for recovery/retry. |
| NativeChannelPinLocalizationTests x3 | `p23.current.reading/matches/differs` and `p23.reload` were shortened ("Pinned messages are up to date") which blurred current-list vs original-receipt. `p23.pending` took one argument while the contract is UUID, operation, message. | Reviewed en copy restored, zh-Hans rewritten with the same meaning, `p23.pending` is `%@ · %@ · message %@` and `NativeChannelMessageEntry` passes requestID, operation, messageID. |
| OfficialPublicEventCompositionTests.testCanonicalCity... | Early allow-list guard in `CompositionHTTPTransport.send` requires `url.query == nil` unless a route is listed; `OfficialPublicEventReadRoute` was missing, so `?city=` was rejected before the (stricter) route branch. Product defect: the city filter never reached the wire. | Added `OfficialPublicEventReadRoute.accepts(...)` to that guard. The route still validates one `city` query item and the later branch still needs grant + selected source. |
| OfficialPublicEventCompositionTests.testNormalSessionRoleRoundTrip... | Harness deployment had no `.domesticChinaPhone`, so `CNAccountSessionService` was never built and `bootstrap()` left `account` nil. | Harness grants `.domesticChinaPhone` for the China market only. |
| OfficialPublicEventCompositionTests.testIndependentGrant..., testUSRevoked... | NOT root-caused. Error surfaced is not `APIError` (likely `CancellationError` from the reader's context re-check). The domesticChinaPhone change above may or may not cover it. | none beyond the harness capability; needs a run. |
| WorkshopPaidInstallNormalFlowTests.testNormalSignedIn... | Harness `context()` built the session with default role `player` while production (f273c806c) passes the signed-in role. | Harness session carries `role: wire.role`. |
| WorkshopPaidProfessionalNormalFlowTests.testActualNormal... | Install approval was minted with a deliberate `canonical:false` player-role session; production now always builds the session with the real role, so 26 context mismatches. | Removed the non-canonical variant; every approval uses the production context. |
| WorkshopPaidInstalledTextNormalFlowTests.testActualHostedSheet... | Same non-canonical install approval, plus hosted view mounted in a bare `UIWindow(frame:)` (no scene, scenePhase never active) and `Task.yield()` loops that do not return to the run loop. | Canonical context, `HostedNavigationSceneWindow`, run-loop aware `hostedWait`. |
| WorkshopPaidProfessionalNormalFlowTests.testHostedActualSheet... | Bare `UIWindow` and yield-only wait, as above. | Scene window + `hostedWait`. |
| WorkshopPaidInstallNormalFlowTests.testRealHostedInstallModal... | Dismiss assertion polled with `Task.yield()`, which can drain the main queue without a run-loop turn, so `onDisappear` had not run. | `hostedWait` (10 ms sleeps, 5 s bound). |
| WorkshopCreatorConsentNormalFlowTests.testHostedNavigation..., WorkshopCreatorPendingNormalFlowTests x2 | NOT root-caused. Controller stays `idle`. Hypothesis: `scenePhase` is not `.active` at first `onAppear`, so the view calls `suspend`, and the later `resume` is recovery-only (no preview load). Not changed because that is product lifecycle behaviour I could not confirm. | none; needs a run with the `WORKSHOP_CREATOR_HOST` probe output. |
| NativeChannelMessageHostBindingTests x2 | NOT root-caused. History stays empty after a plain send (no history refresh after acknowledge in the harness path) and the timeout remount shows a second send for the same key. | none; needs a run. |

Summary: 13 of 20 have a code-level fix (3 Appeal, 3 Pin, 2 Official, 5 Workshop). 7 are not root-caused: 2 Official, 3 Creator hosted, 2 MessageHost.

## Follow-up on ui/main cd17d0d99

- Early allow-list narrowed: the city-query admit is now `OfficialPublicEventReadSelection.admitsEarly(...)` and needs the reviewed grant, China market and a matching selected source. Capability-absent, US, revoked, removed and foreign origin/namespace stay default-closed; the route branch re-checks all of it. Test expectations unchanged.
- Real cause of testIndependentGrantAndSourceRemainSeparatelyDefaultClosed and testUSRevokedRemovedAndForeignSourceNeverReachWire (the previous receipt called it unexplained): these tests used `root.makeSession().officialEventReader.events(...)` on a temporary session. The reader's context closure holds the session weakly and falls back to `guestEpoch: 0`, so when the session is released mid-await the reader sees a context change and throws `CancellationError` (hence `as? APIError == nil`). The refusal itself was always `notConfigured`. Fix: tests now retain the session for the call (`withExtendedLifetime`); assertions untouched. Not verified by a run.
- The admit change was not the cause of those two; the early guard already passed query-less requests.

## The other 7 (not changed, per test)

Not root-caused by reading code; I cannot confirm they are the iOS 27 hosted-AX family, only that the evidence is consistent with a hosted/lifecycle environment cause rather than a product-logic defect:

| test | observation | family call |
|---|---|---|
| WorkshopCreatorConsentNormalFlowTests.testHostedNavigationBackAndFreshRowSelection... | stays `idle`, never `reviewing` after UIKit push into a scene window | hosted lifecycle (scenePhase/onAppear); likely hosted family |
| WorkshopCreatorPendingNormalFlowTests.testHostedBackAndFreshSelection... | `offerAuthor` closure nil, never `editing` | hosted lifecycle; likely hosted family |
| WorkshopCreatorPendingNormalFlowTests.testHostedAuthorToReviewTransition... | `offerAuthor` closure nil | hosted lifecycle; likely hosted family |
| WorkshopPaidInstallNormalFlowTests.testRealHostedInstallModal... | `ready` != `idle` after dismiss (fix attempted: run-loop wait) | hosted lifecycle; likely hosted family |
| WorkshopPaidInstalledTextNormalFlowTests.testActualHostedSheet... | `idle` != `loaded` (fix attempted: scene window, wait) | hosted lifecycle |
| WorkshopPaidProfessionalNormalFlowTests.testHostedActualSheet... | `idle` != `history` (fix attempted: scene window, wait) | hosted lifecycle |
| NativeChannelMessageHostBindingTests x2 | history nil after send; same key sent twice after timeout remount | NOT hosted UI (no window); domain behaviour, unexplained, needs a run |

So the hosted-AX label fits the five Workshop hosted tests (three of which also got a fix attempt above); it does not fit the two MessageHostBinding tests.
