# finish-3b: hosted family, second pass with real evidence (ui/e3q)

Evidence: `/private/tmp/design-build/hosted.xcresult` (test-details failure messages) and the exported `StandardOutputAndStandardError.txt`. Code-only: nothing below was re-run on a simulator.

## What the failures actually say
- `RoamPlaceDetailReadLifetimeTests` (9/9): the single message is `Missing original control: place.read.open` (then `caught error: "notConfigured"`, which is the helper's own throw after XCTFail). Duration 2.3 s = the helper's 100 x 20 ms search loop exhausted. Production code (`RoamItemDetailView`, reader, wire) is never reached; the root `Button` of the hosted view is never discoverable. This is a rig failure, not a read-lifetime bug.
- Same shape in `RoamShareNativeLifetime` (`Missing original share action: share.lifetime.open`), `RoamEnrolledTopicsLifetime` / `RoamTileIntentLifetime` / `RoamOfficialTasksLifetime` (`... did not settle`, `Missing original action: roam.tasks.event.71`).
- Native* hosting classes: `XCTAssertTrue failed - <stage>` from their `wait` helpers (state purge / child appeared never observed), plus a SwiftUI runtime log `[Invalid Configuration] The navigationDestination modifier only works inside a NavigationStack ... misplaced navigationDestination(isPresented:)` emitted at mount.
- `caught error: "InvalidTransition { phase: idle targetPhase: failed(deinit) }"` appears after the first failure in 7 classes. It is the follow-on error from the helper's `throw` after an XCTFail, not an independent defect; it disappears when the first failure does.

## Common factor
Every failing class hands the *real* SwiftUI root to a `UIHostingController` that becomes key/visible in the same turn (`window.rootViewController = UIHostingController(rootView: real)`; `makeKeyAndVisible()`). The passing hosted suite with the same real view and the same control (`RoamTileDenialHostTests`, `roam.experience.tiles.load`) instead attaches a placeholder root, lets the window go live, then assigns `host.rootView = real`. Tests that never mount a view (presentation-object tests in the same classes) pass.

## Change
One shared helper `hostedMount(_:root:)` (Tests/AppUnitTests/WorkshopPurchasedNormalAccountTests.swift) implements the placeholder-then-swap mount plus a bounded run-loop pump. Used by: RoamPlaceDetailReadLifetime, RoamShareNativeLifetime, RoamEnrolledTopicsLifetime, RoamTileIntentLifetime, RoamOfficialTasksLifetime, NativeBlacklistEntryHosting, NativeFriendDirectoryNavigationHosting, NativeFriendRequestReviewHosting, WorkshopPaidProfessional/InstalledText NormalFlow. No assertion, timeout or production file changed.

## Classification and confidence (unverified, needs a Test-lane run)
| Class | Real cause | Expectation |
|---|---|---|
| RoamPlaceDetailReadLifetime (9) | control undiscoverable on first-turn mount (rig) | should clear if mount is the cause |
| RoamShareNative (7), RoamTileIntent (4), RoamEnrolledTopics (5), RoamOfficialTasks (4) | same mount; `did not settle` is the downstream wait | likely clear |
| NativeFriendRequestReview (4), NativeFriendDirectoryNavigation (3), NativeBlacklistEntry (2) | same mount; `navigationDestination` "misplaced" warning at mount points at the same first-turn problem | plausible; the Blacklist `Retirement...CannotRevive` assertion (isCurrent/items) was not explained by a production defect: `NativeBlacklistFlow` latches `authorityRetired` in `validateAuthority`, so it stays red if the purge there is reached by another path |
| Workshop*NormalFlow (5) | same mount (`host.presentedViewController` / sheet never appeared) | plausible, least certain |

If any class stays red after this, the next step is a single-test run with the `navigationDestination` warning and `hostedMount` timing logged, not another harness guess.

## Second pass (hosted2.xcresult, after e3q merged: 88 pass / 43 fail, identical)
The mount-timing hypothesis is refuted. The `notConfigured` hypothesis is also refuted by the code: `caught error: "notConfigured"` is the helper's own `throw APIError.notConfigured` after its `XCTFail` (Place:130, Share:148, ...), and `PlaceReadLifetimeHost`'s `place.read.open` is an unconditional root `Button`, rendered before any reader/deployment is consulted. `TileIntentRig` also builds the same configured context/access as the passing `TileDenialHostRig`.

Messages grouped across the 13 classes (43 failures):
- Control/action never discoverable via accessibility lookup, then helper throw: Place 9 (`Missing original control: place.read.open`), Share 6 (`Missing original share action: share.lifetime.open`), Official 1 (`Missing original action: roam.tasks.event.71`) = 16. Same lookup, reported as `... did not settle`: Enrolled 4, Tile 4, Official 3, Share 1 = 12; Enrolled 1 `XCTUnwrap NSObject`. Measured fact: every test in these five classes that calls `tap`/`find` fails (28/28) and none of their presentation-object-only tests do. The unwrapped `InvalidTransition ... failed(deinit)` (Enrolled 4, Tile 4, Official 4, Share 1, + Native 8) is only the follow-on after the first failure.
- Presentation never happens (sheet / push / nav): Native FriendRequestReview 4 (`sheet appeared`, `real review sheet appeared`), FriendDirectory 3, Blacklist 2, plus 4 SwiftUI `[Invalid Configuration] navigationDestination ... misplaced` log lines.
- Controller refuses the appearance: Workshop CreatorPending 2, CreatorConsent 1 (`idle` vs `reviewing`), PaidInstalledText 1 (`idle` vs `loaded`), PaidProfessional 1 (`idle` vs `history`; `XCTUnwrap ... () async -> ()`).

Single shared factor is not yet proven. SwiftUI's `AccessibilityNode` class exists in the iOS 27 runtime, so the `HostedAccessibilityRuntime` conformance hook has a target. To stop guessing, every lookup failure in the five Roam classes now appends `hostedDiagnostics()` (app/scene activation state, scene windows, accessibility node count and class names, discovered identifiers, whether the node class conforms to `UIAccessibilityIdentification`, VoiceOver flag). Next run's failure text will name the cause.
