# cursor/1128-k50-r06 — retain cycles in sessions, coordinators, and timers

Base: `origin/ui/combined-r7` at `b954de71cd6669256c49785864504f8e05ba05d9` (`Merge remote-tracking branch 'origin/mp/r3-states-b' into ui/combined-r7`, 2026-11-28 10:02:15 -0800). The branch was created from that tip. The tip is merged again before push. Nothing was force-pushed. `main` was not pushed.

No `xcodebuild`. This machine has no Swift toolchain, so the new tests were not executed here. `App/AppSession.swift` is 7976 lines (ceiling 7977, unchanged). `RuntimeDependencyConfiguration` init order stays `devices`, `sensors`, `artworkHosts`. Release `PlayerLaunch.merchantCenterEnabled` stays false (`#else` branch). No `String(localized:)` literals. Payment, wallet, coupon, Alipay, and WeChat pay files were not edited.

## Cycles fixed

1. **Session location tracker ↔ hold ledger.** `SessionBackgroundLocationTracker` lazy-stores `ledger`, and that ledger was created with `driver: self` stored as `private let driver`. The tracker could not deallocate once the ledger was touched. `SessionLocationHoldLedger.driver` is now `weak`. `apply()` still starts and stops a live driver; a missing driver clears the running flags and does not call through. Hold keys and purposes are unchanged. Test: `WP11SessionLocationTests.testSessionLocationDriverThatOwnsItsLedgerDeallocates` (an owner with the tracker's shape acquires a hold, then a weak reference is nil).

2. **Personal location share publisher loop.** `PersonalLocationShareCoordinator.publisher` is a stored `Task` that did `guard let self` and then looped, including `pause` for `refreshAfterMs`. The task and the coordinator kept each other alive for the whole share. The loop now calls `publishIfCurrent`, which retains the coordinator only for that call. The pause does not. A thrown publish or a thrown pause still goes through `publisherFailed` (report, stop, the same pending-stop message). `deinit` cancels `publisher`, `receiverPoll`, `leaseTimer`, and `ownerLeaseTimer`.

3. **Personal location share lease timer.** `leaseTimer` used the same `guard let self` before its `while`, so the sleep until the next stale or expiry boundary held the coordinator. `leaseSleepNanoseconds` and `expireLease` retain it only for the call. No next boundary still expires immediately and stops the loop. A cancelled sleep still returns without reporting. Test: `PersonalLocationShareTests.testSharingCoordinatorDeallocatesWhilePublishAndLeaseTimersRun` confirms a live publish and a non-empty received list, drops the coordinator, and expects the weak reference to be nil without waiting out the 20s pause.

4. **Stamp framing camera pinch target.** `RoamStampFramingCameraController` added `UIPinchGestureRecognizer(target: self)` to `preview`, a subview of its view. The recognizer retains its target, so the controller, the view, and the recognizer kept each other alive, and the capture session with them. The recognizer now targets `PinchRelay`, which holds the controller weakly and forwards `pinched`. Slider and button targets stay `self` (`UIControl` does not retain its target). Test: `RoamStampFramingPixelTests.testFramingCameraControllerDeallocatesAfterThePreviewLoads`.

## Left as they are

- URLSession delegates that point at the reader (`ResponseLimitedHTTPExchange`, profile and media transports) nil the task and call `invalidateAndCancel` when the request finishes. That in-flight cycle ends with the request.
- `receiverPoll` and `ownerLeaseTimer` sleep before they take `self`. They are one shot, not a loop that holds the coordinator.
- Alipay's pay timeout task is one sleep. Money code was not edited.
- SwiftUI `.task` loops are cancelled with the view. Stored `onChange` closures that a screen nils on disappear were not rewritten.

## Gates

`python3 tools/check_scaffold.py` PASS (21801 bilingual keys, structural checks, AppSession ratchet PASS at 7976). `python3 -B tools/check_a11y_lint.py` PASS, 0 new. `python3 -B tools/check_design_consistency.py` PASS, 0 counts below baseline. `python3 -B tools/check_design_lint.py` PASS, allowlist 0. `python3 -B tools/check_missing_string_keys.py` missing 0. `python3 -B tools/contract_ratchet.py --check` 46 failing, baseline 46, **new 0**. `python3 tools/generate_project.py` regenerated the project with no git diff.
