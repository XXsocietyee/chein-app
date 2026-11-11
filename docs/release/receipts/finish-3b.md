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
